#include "crash_handler.h"

#include <execinfo.h>
#include <fcntl.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include <cstdlib>

namespace {

constexpr int kMaxFrames = 96;
constexpr size_t kPathCapacity = 512;

// Resolved once at install time so the handler only reads static memory.
char g_crash_directory[kPathCapacity] = {0};

// --- async-signal-safe helpers --------------------------------------------

// Appends `text` to `out` at `offset`, always keeping `out` NUL-terminated.
size_t AppendText(char* out, size_t offset, size_t capacity, const char* text) {
  if (text == nullptr) return offset;
  for (size_t i = 0; text[i] != '\0' && offset + 1 < capacity; ++i) {
    out[offset++] = text[i];
  }
  out[offset] = '\0';
  return offset;
}

size_t AppendUnsigned(char* out, size_t offset, size_t capacity,
                      unsigned long long value, int min_width) {
  char digits[32];
  int count = 0;
  do {
    digits[count++] = static_cast<char>('0' + (value % 10));
    value /= 10;
  } while (value != 0);
  while (min_width > count && offset + 1 < capacity) {
    out[offset++] = '0';
    --min_width;
  }
  while (count > 0 && offset + 1 < capacity) {
    out[offset++] = digits[--count];
  }
  out[offset] = '\0';
  return offset;
}

size_t AppendHex(char* out, size_t offset, size_t capacity, uintptr_t value) {
  const char* kHex = "0123456789abcdef";
  char digits[2 * sizeof(uintptr_t)];
  int count = 0;
  do {
    digits[count++] = kHex[value & 0xF];
    value >>= 4;
  } while (value != 0);
  if (offset + 3 < capacity) {
    out[offset++] = '0';
    out[offset++] = 'x';
  }
  while (count > 0 && offset + 1 < capacity) {
    out[offset++] = digits[--count];
  }
  out[offset] = '\0';
  return offset;
}

// Civil date from a Unix timestamp (UTC). Avoids localtime/strftime, which are
// not async-signal-safe.
void UtcParts(time_t now, int* year, int* month, int* day, int* hour,
              int* minute, int* second) {
  long long seconds = static_cast<long long>(now);
  long long days = seconds / 86400;
  long long remainder = seconds % 86400;
  if (remainder < 0) {
    remainder += 86400;
    --days;
  }
  *hour = static_cast<int>(remainder / 3600);
  *minute = static_cast<int>((remainder % 3600) / 60);
  *second = static_cast<int>(remainder % 60);

  // Howard Hinnant's civil_from_days.
  long long z = days + 719468;
  const long long era = (z >= 0 ? z : z - 146096) / 146097;
  const unsigned long long doe =
      static_cast<unsigned long long>(z - era * 146097);
  const unsigned long long yoe =
      (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
  const long long y = static_cast<long long>(yoe) + era * 400;
  const unsigned long long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
  const unsigned long long mp = (5 * doy + 2) / 153;
  const unsigned long long d = doy - (153 * mp + 2) / 5 + 1;
  const unsigned long long m = mp < 10 ? mp + 3 : mp - 9;
  *year = static_cast<int>(y + (m <= 2));
  *month = static_cast<int>(m);
  *day = static_cast<int>(d);
}

const char* SignalName(int signal_number) {
  switch (signal_number) {
    case SIGSEGV:
      return "SIGSEGV";
    case SIGBUS:
      return "SIGBUS";
    case SIGILL:
      return "SIGILL";
    case SIGFPE:
      return "SIGFPE";
    case SIGABRT:
      return "SIGABRT";
    default:
      return "SIGUNKNOWN";
  }
}

void WriteAll(int fd, const char* data, size_t length) {
  size_t written = 0;
  while (written < length) {
    const ssize_t chunk =
        write(fd, data + written, static_cast<size_t>(length - written));
    if (chunk <= 0) return;
    written += static_cast<size_t>(chunk);
  }
}

template <size_t N>
void WriteLiteral(int fd, const char (&text)[N]) {
  WriteAll(fd, text, N - 1);
}

void CopyFileToFd(const char* path, int out_fd) {
  const int in_fd = open(path, O_RDONLY);
  if (in_fd < 0) return;
  char buffer[4096];
  ssize_t count;
  while ((count = read(in_fd, buffer, sizeof(buffer))) > 0) {
    WriteAll(out_fd, buffer, static_cast<size_t>(count));
  }
  close(in_fd);
}

// Builds "<dir>/crash-YYYYMMDD-HHMMSS-<pid>.txt" into `path`.
void BuildReportPath(char* path, size_t capacity) {
  int year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
  UtcParts(time(nullptr), &year, &month, &day, &hour, &minute, &second);
  size_t n = AppendText(path, 0, capacity, g_crash_directory);
  n = AppendText(path, n, capacity, "/crash-");
  n = AppendUnsigned(path, n, capacity, static_cast<unsigned long long>(year), 4);
  n = AppendUnsigned(path, n, capacity, static_cast<unsigned long long>(month), 2);
  n = AppendUnsigned(path, n, capacity, static_cast<unsigned long long>(day), 2);
  n = AppendText(path, n, capacity, "-");
  n = AppendUnsigned(path, n, capacity, static_cast<unsigned long long>(hour), 2);
  n = AppendUnsigned(path, n, capacity, static_cast<unsigned long long>(minute), 2);
  n = AppendUnsigned(path, n, capacity, static_cast<unsigned long long>(second), 2);
  n = AppendText(path, n, capacity, "-");
  n = AppendUnsigned(path, n, capacity,
                     static_cast<unsigned long long>(getpid()), 0);
  AppendText(path, n, capacity, ".txt");
}

void WriteCrashReport(int signal_number, siginfo_t* info) {
  char path[kPathCapacity];
  BuildReportPath(path, sizeof(path));

  const int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) return;

  char line[kPathCapacity];
  size_t n = AppendText(line, 0, sizeof(line), "OpenLogTool crash report\n");
  n = AppendText(line, n, sizeof(line), "Signal: ");
  n = AppendText(line, n, sizeof(line), SignalName(signal_number));
  n = AppendText(line, n, sizeof(line), " (");
  n = AppendUnsigned(line, n, sizeof(line),
                     static_cast<unsigned long long>(signal_number), 0);
  n = AppendText(line, n, sizeof(line), ")\nUTC time: ");
  int year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
  UtcParts(time(nullptr), &year, &month, &day, &hour, &minute, &second);
  n = AppendUnsigned(line, n, sizeof(line), static_cast<unsigned long long>(year), 4);
  n = AppendText(line, n, sizeof(line), "-");
  n = AppendUnsigned(line, n, sizeof(line), static_cast<unsigned long long>(month), 2);
  n = AppendText(line, n, sizeof(line), "-");
  n = AppendUnsigned(line, n, sizeof(line), static_cast<unsigned long long>(day), 2);
  n = AppendText(line, n, sizeof(line), " ");
  n = AppendUnsigned(line, n, sizeof(line), static_cast<unsigned long long>(hour), 2);
  n = AppendText(line, n, sizeof(line), ":");
  n = AppendUnsigned(line, n, sizeof(line), static_cast<unsigned long long>(minute), 2);
  n = AppendText(line, n, sizeof(line), ":");
  n = AppendUnsigned(line, n, sizeof(line), static_cast<unsigned long long>(second), 2);
  n = AppendText(line, n, sizeof(line), "\nProcess: ");
  n = AppendUnsigned(line, n, sizeof(line),
                     static_cast<unsigned long long>(getpid()), 0);
  WriteAll(fd, line, n);

  char executable[kPathCapacity];
  const ssize_t link_length =
      readlink("/proc/self/exe", executable, sizeof(executable) - 1);
  if (link_length > 0) {
    executable[link_length] = '\0';
    n = AppendText(line, 0, sizeof(line), "\nExecutable: ");
    n = AppendText(line, n, sizeof(line), executable);
    WriteAll(fd, line, n);
  }

  if (info != nullptr && info->si_addr != nullptr) {
    n = AppendText(line, 0, sizeof(line), "\nFault address: ");
    n = AppendHex(line, n, sizeof(line),
                  reinterpret_cast<uintptr_t>(info->si_addr));
    WriteAll(fd, line, n);
  }

  WriteLiteral(fd, "\n\nBacktrace (module(+offset)):\n");

  void* frames[kMaxFrames];
  const int frame_count = backtrace(frames, kMaxFrames);
  backtrace_symbols_fd(frames, frame_count, fd);

  WriteLiteral(fd, "\n/proc/self/maps:\n");
  CopyFileToFd("/proc/self/maps", fd);

  close(fd);
}

void CrashSignalHandler(int signal_number, siginfo_t* info, void* /*context*/) {
  WriteCrashReport(signal_number, info);
  // SA_RESETHAND already restored the default action, so re-raising preserves
  // normal termination, core-dump and WER-equivalent behaviour.
  raise(signal_number);
}

void EnsureDirectory(const char* directory) {
  char buffer[kPathCapacity];
  const size_t length = AppendText(buffer, 0, sizeof(buffer), directory);
  for (size_t i = 1; i < length; ++i) {
    if (buffer[i] == '/') {
      buffer[i] = '\0';
      mkdir(buffer, 0755);
      buffer[i] = '/';
    }
  }
  mkdir(buffer, 0755);
}

}  // namespace

void InstallCrashHandler() {
  const char* base = getenv("XDG_DATA_HOME");
  size_t n = 0;
  if (base == nullptr || base[0] == '\0') {
    const char* home = getenv("HOME");
    if (home == nullptr || home[0] == '\0') return;
    n = AppendText(g_crash_directory, 0, sizeof(g_crash_directory), home);
    if (n > 0 && g_crash_directory[n - 1] == '/') {
      g_crash_directory[--n] = '\0';
    }
    base = "/.local/share";
  }
  n = AppendText(g_crash_directory, n, sizeof(g_crash_directory), base);
  AppendText(g_crash_directory, n, sizeof(g_crash_directory),
             "/openlogtool/crashes");

  EnsureDirectory(g_crash_directory);

  // Pre-warm the unwinder so backtrace() does not allocate on first use inside
  // the signal handler.
  void* warmup[4];
  backtrace(warmup, 4);

  struct sigaction action;
  memset(&action, 0, sizeof(action));
  action.sa_sigaction = CrashSignalHandler;
  action.sa_flags = SA_SIGINFO | SA_RESETHAND;
  sigemptyset(&action.sa_mask);

  const int signals[] = {SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT};
  for (int signal_number : signals) {
    sigaction(signal_number, &action, nullptr);
  }
}

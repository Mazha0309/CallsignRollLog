#ifndef RUNNER_CRASH_HANDLER_H_
#define RUNNER_CRASH_HANDLER_H_

// Installs POSIX signal handlers that write a plain-text crash report (signal,
// fault address, backtrace, memory map) under the application data directory
// before re-raising the default action. Mirrors the native minidump written by
// the Windows runner so crashes are diagnosable without a debugger.
void InstallCrashHandler();

#endif  // RUNNER_CRASH_HANDLER_H_

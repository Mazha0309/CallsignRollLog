import 'package:openlogtool/services/key_value_store.dart';

class DictionaryUsageStore {
  DictionaryUsageStore._(this._counts);

  final Map<String, int> _counts;
  KeyValueStore? _store;
  Future<void>? _loadFuture;

  static const _storageKey = 'dictionaryUsageCounts';
  static DictionaryUsageStore? _shared;

  factory DictionaryUsageStore.memory([Map<String, int>? counts]) {
    return DictionaryUsageStore._({
      if (counts != null) ...counts,
    });
  }

  static DictionaryUsageStore shared() {
    return _shared ??= DictionaryUsageStore._({});
  }

  Future<void> ensureLoaded() {
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _load();
    _loadFuture = future;
    return future;
  }

  int countFor(String type, String value) {
    return _counts[_key(type, value)] ?? 0;
  }

  Future<void> recordSelection(String type, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    final key = _key(type, normalized);
    _counts[key] = (_counts[key] ?? 0) + 1;
    await _persist();
  }

  Future<void> _load() async {
    _store ??= await openKeyValueStore();
    final raw = await _store!.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    for (final entry in raw.split('\u001e')) {
      final separator = entry.lastIndexOf('=');
      if (separator <= 0) continue;
      final key = entry.substring(0, separator);
      final count = int.tryParse(entry.substring(separator + 1));
      if (count == null) continue;
      _counts[key] = count;
    }
  }

  Future<void> _persist() async {
    _store ??= await openKeyValueStore();
    final payload = _counts.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('\u001e');
    await _store!.setString(_storageKey, payload);
  }

  static String _key(String type, String value) => '$type\u001f$value';
}

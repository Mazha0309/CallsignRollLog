/// Ordered by match strength so fuzzy initials never displace a literal hit.
enum DictionaryMatchKind { subsequence, substring, prefix, exact }

class DictionaryMatch {
  const DictionaryMatch(this.kind, this.score);

  final DictionaryMatchKind kind;
  final int score;
}

final _searchSeparators = RegExp(r"[\s_\-‐‑‒–—'’]+");
final _initialsQuery = RegExp(r'^[a-z0-9]+$');

String _compact(String value) =>
    value.trim().toLowerCase().replaceAll(_searchSeparators, '');

/// Literal text/full-pinyin matches plus ordered, bounded initials matching.
///
/// Only initials use subsequences: matching arbitrary letters across full
/// pinyin would make unrelated long entries match nearly every short query.
DictionaryMatch? matchDictionaryText({
  required String query,
  required String raw,
  required String pinyin,
  required String abbreviation,
}) {
  final needle = _compact(query);
  if (needle.isEmpty) return null;
  DictionaryMatch? best;
  void consider(String value, int weight) {
    final text = _compact(value);
    final index = text.indexOf(needle);
    if (index < 0) return;
    final kind = text == needle
        ? DictionaryMatchKind.exact
        : index == 0
            ? DictionaryMatchKind.prefix
            : DictionaryMatchKind.substring;
    final candidate = DictionaryMatch(kind, weight * 100 - index.clamp(0, 99));
    if (best == null ||
        candidate.kind.index > best!.kind.index ||
        (candidate.kind == best!.kind && candidate.score > best!.score)) {
      best = candidate;
    }
  }

  consider(raw, 2);
  consider(pinyin, 1);
  consider(abbreviation, 3);
  if (best != null) return best;
  if (needle.length < 2 || !_initialsQuery.hasMatch(needle)) return null;
  final initials = _compact(abbreviation);
  if (needle.length > initials.length) return null;

  // Keep the latest start for each matched prefix: O(entry * query), without
  // recursive/backtracking work even for long entries with repeated initials.
  final starts = List<int>.filled(needle.length, -1);
  int? closestSpan;
  for (var position = 0; position < initials.length; position++) {
    for (var index = needle.length - 1; index >= 0; index--) {
      if (initials.codeUnitAt(position) != needle.codeUnitAt(index)) continue;
      if (index == 0) {
        starts[0] = position;
      } else if (starts[index - 1] >= 0) {
        starts[index] = starts[index - 1];
      }
      if (index == needle.length - 1 && starts[index] >= 0) {
        final span = position - starts[index] + 1;
        if (closestSpan == null || span < closestSpan) closestSpan = span;
      }
    }
  }
  // A short query should not match scattered initials across an entire essay.
  if (closestSpan == null || closestSpan > needle.length * 4) return null;
  return DictionaryMatch(
    DictionaryMatchKind.subsequence,
    100 - (closestSpan - needle.length),
  );
}

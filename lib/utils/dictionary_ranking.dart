import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/utils/dictionary_match.dart';

class _ScoredDictionaryOption {
  const _ScoredDictionaryOption(this.option, this.match, this.usage);

  final DictionaryItem option;
  final DictionaryMatch match;
  final int usage;
}

List<DictionaryItem> rankDictionaryMatches({
  required String query,
  required Iterable<DictionaryItem> options,
  int Function(DictionaryItem option)? usageCount,
  int limit = 20,
}) {
  if (query.trim().isEmpty || limit <= 0) return const [];
  final scored = <_ScoredDictionaryOption>[];
  for (final option in options) {
    if (option.deletedAt != null) continue;
    final match = matchDictionaryText(
      query: query,
      raw: option.raw,
      pinyin: option.pinyin,
      abbreviation: option.abbreviation,
    );
    if (match == null) continue;
    scored.add(
      _ScoredDictionaryOption(
        option,
        match,
        usageCount?.call(option) ?? 0,
      ),
    );
  }
  scored.sort((a, b) {
    if (b.match.kind != a.match.kind) {
      return b.match.kind.index.compareTo(a.match.kind.index);
    }
    if (b.usage != a.usage) return b.usage.compareTo(a.usage);
    if (b.match.score != a.match.score) {
      return b.match.score.compareTo(a.match.score);
    }
    return a.option.raw.compareTo(b.option.raw);
  });
  return [
    for (final item in scored.take(limit)) item.option,
  ];
}

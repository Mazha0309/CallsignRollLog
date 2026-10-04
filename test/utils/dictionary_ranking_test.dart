import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/utils/dictionary_ranking.dart';
import 'package:openlogtool/utils/dictionary_pinyin_helper.dart';

void main() {
  DictionaryItem item(String raw) => DictionaryItem(
        raw: raw,
        pinyin: raw.toLowerCase(),
        abbreviation: raw.toLowerCase(),
        type: 'device',
      );

  test('matching dictionary options prefer higher click counts', () {
    final ranked = rankDictionaryMatches(
      query: 'ic',
      options: [item('IC-705'), item('IC-7300'), item('IC-7610')],
      usageCount: (option) => option.raw == 'IC-7300' ? 8 : 1,
    );

    expect(ranked.map((option) => option.raw).toList(), [
      'IC-7300',
      'IC-705',
      'IC-7610',
    ]);
  });

  DictionaryItem address(String raw) {
    final generated = DictionaryPinyinHelper.generate(raw);
    return DictionaryItem(
      raw: raw,
      pinyin: generated.pinyin,
      abbreviation: generated.abbreviation,
      type: 'qth',
    );
  }

  test('exact, prefix, middle and fuzzy initial hits are ranked in that order',
      () {
    final exact = address('新月里');
    final prefix = address('新月里广场');
    final middle = address('杭州杭港新月里');
    final fuzzy = address('杭州新花园里');
    final ranked = rankDictionaryMatches(
      query: 'xyl',
      options: [fuzzy, middle, prefix, exact],
      usageCount: (option) => option == fuzzy ? 1000 : 0,
    );
    expect(ranked, [exact, prefix, middle, fuzzy]);
  });

  test('frequently selected middle matches still win within the same strength',
      () {
    final first = address('杭州新月里');
    final second = address('宁波新月里');
    final ranked = rankDictionaryMatches(
      query: 'xyl',
      options: [first, second],
      usageCount: (option) => option == second ? 5 : 0,
    );
    expect(ranked, [second, first]);
  });

  test('long entry fuzzy matches reach the autocomplete ranking path', () {
    final target = address('杭州杭港新月里');
    expect(
      rankDictionaryMatches(query: 'zgxl', options: [address('别的地方'), target]),
      [target],
    );
  });

  test('ranking is deterministic and applies the limit after relevance sorting',
      () {
    final exact = address('新月里');
    final middle = address('杭州新月里');
    final options = [middle, item('XYL-1'), item('XYL-2'), exact];
    final ranked =
        rankDictionaryMatches(query: 'xyl', options: options, limit: 2);
    expect(ranked, [exact, options[1]]);
    expect(
        rankDictionaryMatches(
            query: 'xyl', options: options.reversed, limit: 2),
        ranked);
  });

  test(
      'empty queries, non-positive limits and deleted entries yield no suggestions',
      () {
    final option = address('新月里');
    expect(rankDictionaryMatches(query: ' ', options: [option]), isEmpty);
    expect(rankDictionaryMatches(query: '-', options: [option]), isEmpty);
    expect(rankDictionaryMatches(query: 'xyl', options: [option], limit: 0),
        isEmpty);
    expect(rankDictionaryMatches(query: 'xyl', options: [option], limit: -1),
        isEmpty);
    expect(
        rankDictionaryMatches(
            query: 'xyl',
            options: [option.copyWith(deletedAt: '2026-01-01T00:00:00Z')]),
        isEmpty);
  });
}

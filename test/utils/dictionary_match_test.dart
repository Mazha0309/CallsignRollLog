import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/utils/dictionary_match.dart';
import 'package:openlogtool/utils/dictionary_pinyin_helper.dart';

DictionaryItem _entry(String raw) {
  final generated = DictionaryPinyinHelper.generate(raw);
  return DictionaryItem(
    raw: raw,
    pinyin: generated.pinyin,
    abbreviation: generated.abbreviation,
  );
}

void main() {
  final longAddress = _entry('杭州杭港新月里');

  test('long Chinese entries match middle initials as well as full pinyin', () {
    expect(longAddress.abbreviation, 'hzhgxyl');
    for (final query in ['xyl', '  XYL  ', 'xinyue', '新月里', 'yueli']) {
      expect(longAddress.matches(query), isTrue, reason: query);
    }
  });

  test(
      'ordered initials may skip words or syllables without requiring a prefix',
      () {
    for (final query in ['hxyl', 'zgxl', 'gxl']) {
      expect(longAddress.matches(query), isTrue, reason: query);
    }
    for (final query in ['lyx', 'lzgh', 'xxyl', 'xyz']) {
      expect(longAddress.matches(query), isFalse, reason: query);
    }
    expect(
      matchDictionaryText(
        query: 'gxl',
        raw: longAddress.raw,
        pinyin: longAddress.pinyin,
        abbreviation: longAddress.abbreviation,
      )?.kind,
      DictionaryMatchKind.subsequence,
    );
  });

  test(
      'spaces and common separators do not break pinyin, initials or model lookup',
      () {
    for (final query in ['xin yue li', "xin'yue'li", 'x-y-l', 'x_y_l']) {
      expect(longAddress.matches(query), isTrue, reason: query);
    }
    final radio = _entry('ICOM IC-705');
    for (final query in ['ic705', 'IC–705', 'icom ic 705']) {
      expect(radio.matches(query), isTrue, reason: query);
    }
    final antenna = _entry('华鸿 1.2米玻璃钢');
    expect(antenna.matches('1.2米'), isTrue);
  });

  test('empty or separator-only input does not match every dictionary entry',
      () {
    for (final query in ['', '   ', '-', "_' "]) {
      expect(longAddress.matches(query), isFalse, reason: query);
    }
  });

  test('full pinyin is not used for loose subsequences', () {
    final entry = DictionaryItem(
      raw: '无关词条',
      pinyin: 'xiaoyouli',
      abbreviation: 'wgct',
    );
    expect(entry.matches('xyl'), isFalse);
  });

  test('very scattered initials are excluded while later compact matches work',
      () {
    final sparse = DictionaryItem(
      raw: 'Long entry',
      pinyin: '',
      abbreviation: 'x${'a' * 20}y${'b' * 20}l',
    );
    expect(sparse.matches('xyl'), isFalse);
    expect(
        sparse
            .copyWith(abbreviation: '${sparse.abbreviation}xaybl')
            .matches('xyl'),
        isTrue);
  });

  test('repeated initials cannot reuse the same letter position', () {
    final entry =
        DictionaryItem(raw: 'Example', pinyin: '', abbreviation: 'xaz');
    expect(entry.matches('xx'), isFalse);
    expect(entry.copyWith(abbreviation: 'xabx').matches('xx'), isTrue);
  });
}

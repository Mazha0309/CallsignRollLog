import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_field_proofread.dart';

void main() {
  const dictionary = AiDictionaryTerms(
    callsigns: ['BG5CRL'],
    devices: ['泉盛UVK6'],
  );

  test('keeps a dictionary device when a later chunk rewrites it', () {
    final kept = proofreadAiFields(
      const {'device': '全盛U V K 六'},
      locked: const {'device': '泉盛UVK6'},
      dictionary: dictionary,
    );

    expect(kept['device'], '泉盛UVK6');
  });

  test('moves a callsign out of QTH and drops 73 from RST', () {
    final fields = proofreadAiFields(
      const {
        'qth': 'BG5CRL',
        'rstSent': '73',
        'rstRcvd': '59',
      },
      dictionary: dictionary,
    );

    expect(fields['callsign'], 'BG5CRL');
    expect(fields.containsKey('qth'), isFalse);
    expect(fields.containsKey('rstSent'), isFalse);
    expect(fields['rstRcvd'], '59');
  });

  test('corrects a one-character callsign to the only dictionary hit', () {
    final fields = proofreadAiFields(
      const {'callsign': 'BG5CPL'},
      dictionary: dictionary,
    );

    expect(fields['callsign'], 'BG5CRL');
  });

  test('does not guess when two dictionary callsigns are one character away',
      () {
    final fields = proofreadAiFields(
      const {'callsign': 'BG5CPL'},
      dictionary: const AiDictionaryTerms(
        callsigns: ['BG5CRL', 'BG5CPU'],
      ),
    );

    expect(fields['callsign'], 'BG5CPL');
  });

  test('still fills a field that was empty', () {
    final kept = proofreadAiFields(
      const {'qth': '宁波'},
      locked: const {'device': '泉盛UVK6'},
      dictionary: dictionary,
    );

    expect(kept['device'], '泉盛UVK6');
    expect(kept['qth'], '宁波');
  });

  test('snaps a heard device to the only dictionary model', () {
    const catalog = AiDictionaryTerms(
      devices: ['泉盛 UV-K5', '泉盛 UV-K6', '宝锋 UV-K67PRO'],
    );

    expect(
      proofreadAiFields(const {'device': '全盛德UVK6'}, dictionary: catalog),
      {'device': '泉盛 UV-K6'},
    );
    expect(
      proofreadAiFields(const {'device': '全盛UVK六'}, dictionary: catalog),
      {'device': '泉盛 UV-K6'},
    );
    expect(
      proofreadAiFields(const {'device': '全盛U V K 六'}, dictionary: catalog),
      {'device': '泉盛 UV-K6'},
    );
  });

  test('does not guess when two devices share the model token', () {
    final fields = proofreadAiFields(
      const {'device': '全盛UVK6'},
      dictionary: const AiDictionaryTerms(
        devices: ['泉盛 UV-K6', '其他 UV-K6'],
      ),
    );

    expect(fields['device'], '全盛UVK6');
  });

  test('snaps a spoken antenna length and keeps that dictionary entry', () {
    const catalog = AiDictionaryTerms(
      antennas: ['华鸿 1.2米玻璃钢', '华鸿 2.2米玻璃钢', '华鸿 2.6米玻璃钢', '华鸿玻璃钢'],
    );

    final snapped = proofreadAiFields(
      const {'antenna': '华鸿一点二米玻璃钢天线'},
      dictionary: catalog,
    );
    expect(snapped['antenna'], '华鸿 1.2米玻璃钢');

    final kept = proofreadAiFields(
      const {'antenna': '华鸿一点二米玻璃钢天线，然后把后面整段话都倒出来了'},
      locked: snapped,
      dictionary: catalog,
    );
    expect(kept['antenna'], '华鸿 1.2米玻璃钢');
  });

  test('a snapped device stays locked against a later dump', () {
    const catalog = AiDictionaryTerms(
      devices: ['泉盛 UV-K5', '泉盛 UV-K6', '宝锋 UV-K67PRO'],
    );
    final snapped = proofreadAiFields(
      const {'device': '全盛德UVK6'},
      dictionary: catalog,
    );

    final kept = proofreadAiFields(
      const {'device': '他说了很多和这台机器无关的话'},
      locked: snapped,
      dictionary: catalog,
    );

    expect(kept['device'], '泉盛 UV-K6');
  });
}

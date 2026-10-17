import 'package:openlogtool/services/ai_candidate_guard.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/utils/dictionary_match.dart';

/// Raw dictionary spellings used to keep a strong match from being rewritten.
final class AiDictionaryTerms {
  const AiDictionaryTerms({
    this.callsigns = const [],
    this.devices = const [],
    this.antennas = const [],
    this.qths = const [],
  });

  final List<String> callsigns;
  final List<String> devices;
  final List<String> antennas;
  final List<String> qths;

  List<String> termsFor(String field) => switch (field) {
        'callsign' => callsigns,
        'device' => devices,
        'antenna' => antennas,
        'qth' => qths,
        _ => const [],
      };
}

/// Normalizes one model result without letting it erase an earlier dictionary hit.
///
/// [locked] is the fields already accepted from earlier audio. A value that
/// exactly matches its dictionary stays. A callsign placed in QTH is moved,
/// and an RST that is not an RS/RST report (such as 73) is dropped.
Map<String, String> proofreadAiFields(
  Map<String, Object?> incoming, {
  Map<String, String> locked = const {},
  AiDictionaryTerms dictionary = const AiDictionaryTerms(),
}) {
  final next = <String, String>{};
  for (final entry in incoming.entries) {
    if (!AiCandidateGuard.supportedFields.contains(entry.key)) continue;
    final raw = entry.value;
    if (raw is! String) continue;
    final value = raw.trim();
    if (value.isEmpty) continue;
    next[entry.key] = value;
  }

  final qth = next.remove('qth');
  if (qth != null) {
    final qthCanonical = _canonical(qth, dictionary.qths);
    final callsignCanonical = _canonical(qth, dictionary.callsigns);
    if (qthCanonical == null &&
        (callsignCanonical != null || _looksLikeCallsign(qth))) {
      next.putIfAbsent(
          'callsign', () => callsignCanonical ?? _compactCallsign(qth));
    } else {
      next['qth'] = qthCanonical ?? qth;
    }
  }

  for (final field in const ['rstSent', 'rstRcvd']) {
    final value = next[field];
    if (value != null && !_isRstReport(value)) next.remove(field);
  }

  for (final field in const ['callsign', 'device', 'antenna', 'qth']) {
    final value = next[field];
    if (value == null) continue;
    next[field] = switch (field) {
      'callsign' => _preferredCallsign(value, dictionary.callsigns),
      'device' => _snapDevice(value, dictionary.devices),
      'antenna' => _snapAntenna(value, dictionary.antennas),
      _ => _canonical(value, dictionary.termsFor(field)) ?? value,
    };
  }

  final merged = Map<String, String>.of(locked);
  for (final entry in next.entries) {
    final previous = merged[entry.key];
    if (previous != null &&
        _canonical(previous, dictionary.termsFor(entry.key)) != null) {
      continue;
    }
    merged[entry.key] = entry.value;
  }
  return merged;
}

AiRecognitionResult proofreadAiResult(
  AiRecognitionResult result, {
  Map<String, String> locked = const {},
  AiDictionaryTerms dictionary = const AiDictionaryTerms(),
}) {
  final incoming = result.candidates.isEmpty
      ? const <String, Object?>{}
      : result.candidates.first.fields;
  final proofread = proofreadAiFields(
    incoming,
    locked: locked,
    dictionary: dictionary,
  );
  final fields = <String, Object?>{
    for (final entry in incoming.entries)
      if (!AiCandidateGuard.supportedFields.contains(entry.key))
        entry.key: entry.value,
    ...proofread,
  };
  if (fields.isEmpty) {
    return AiRecognitionResult(
      transcription: result.transcription,
      candidates: const [],
    );
  }
  final previous = result.candidates.isEmpty ? null : result.candidates.first;
  return AiRecognitionResult(
    transcription: result.transcription,
    candidates: [
      RecognitionCandidate(
        fields: fields,
        confidence: previous?.confidence,
        sourceText: previous?.sourceText,
        warnings: previous?.warnings ?? const [],
        metadata: previous?.metadata ?? const {},
      ),
    ],
  );
}

String _preferredCallsign(String value, List<String> terms) {
  final exact = _canonical(value, terms);
  if (exact != null || !_looksLikeCallsign(value)) return exact ?? value;
  final compact = _compactCallsign(value);
  String? unique;
  for (final term in terms) {
    if (term.trim().isEmpty || !_looksLikeCallsign(term)) continue;
    if (_editDistance(compact, _compactCallsign(term)) != 1) continue;
    if (unique != null) return value;
    unique = term;
  }
  return unique ?? value;
}

int _editDistance(String left, String right) {
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var leftIndex = 0; leftIndex < left.length; leftIndex += 1) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = leftIndex + 1;
    for (var rightIndex = 0; rightIndex < right.length; rightIndex += 1) {
      final substitution = previous[rightIndex] +
          (left.codeUnitAt(leftIndex) == right.codeUnitAt(rightIndex) ? 0 : 1);
      current[rightIndex + 1] = [
        substitution,
        current[rightIndex] + 1,
        previous[rightIndex + 1] + 1,
      ].reduce((a, b) => a < b ? a : b);
    }
    previous = current;
  }
  return previous.last;
}

const _hanDigits = {
  '零': '0',
  '〇': '0',
  '一': '1',
  '二': '2',
  '两': '2',
  '三': '3',
  '四': '4',
  '五': '5',
  '六': '6',
  '七': '7',
  '八': '8',
  '九': '9',
};

final _catalogSeparators = RegExp(r'''[\s_\-‐‑‒–—，。,、]+''');
final _modelToken = RegExp(r'[A-Z]{2,}\d[A-Z0-9]*');

String _snapDevice(String value, List<String> terms) {
  final exact = _canonical(value, terms);
  if (exact != null) return exact;
  final heard = _modelTokens(_compactCatalog(value));
  if (heard.length != 1) return value;
  final token = heard.single;
  String? unique;
  for (final term in terms) {
    if (term.trim().isEmpty) continue;
    if (!_modelTokens(_compactCatalog(term)).contains(token)) continue;
    if (unique != null) return value;
    unique = term;
  }
  return unique ?? value;
}

String _snapAntenna(String value, List<String> terms) {
  final exact = _canonical(value, terms);
  if (exact != null) return exact;
  final heard = _normalizeAntenna(value);
  if (heard.isEmpty) return value;
  String? unique;
  var uniqueLength = -1;
  var tied = false;
  for (final term in terms) {
    if (term.trim().isEmpty) continue;
    final normalized = _normalizeAntenna(term);
    if (normalized.isEmpty || !heard.contains(normalized)) continue;
    if (unique == null || normalized.length > uniqueLength) {
      unique = term;
      uniqueLength = normalized.length;
      tied = false;
    } else if (normalized.length == uniqueLength) {
      tied = true;
    }
  }
  if (unique == null || tied) return value;
  return unique;
}

Set<String> _modelTokens(String compact) =>
    _modelToken.allMatches(compact).map((match) => match.group(0)!).toSet();

String _normalizeAntenna(String value) {
  var text = _compactCatalog(value);
  while (text.endsWith('天线')) {
    text = text.substring(0, text.length - 2);
  }
  return text;
}

String _compactCatalog(String value) =>
    _spokenDigits(value).toUpperCase().replaceAll(_catalogSeparators, '');

String _spokenDigits(String value) {
  final chars = value.split('');
  final out = StringBuffer();
  for (var index = 0; index < chars.length; index += 1) {
    final mapped = _hanDigits[chars[index]];
    if (mapped != null) {
      out.write(mapped);
      continue;
    }
    final isDot = chars[index] == '点' || chars[index] == '.';
    if (isDot &&
        _isNumberChar(chars, index - 1) &&
        _isNumberChar(chars, index + 1)) {
      out.write('.');
      continue;
    }
    out.write(chars[index]);
  }
  return out.toString();
}

bool _isNumberChar(List<String> chars, int index) {
  if (index < 0 || index >= chars.length) return false;
  final char = chars[index];
  return _hanDigits.containsKey(char) || RegExp(r'^\d$').hasMatch(char);
}

String? _canonical(String value, List<String> terms) {
  for (final term in terms) {
    if (term.trim().isEmpty) continue;
    final match = matchDictionaryText(
      query: value,
      raw: term,
      pinyin: '',
      abbreviation: '',
    );
    if (match?.kind == DictionaryMatchKind.exact) return term;
  }
  return null;
}

bool _looksLikeCallsign(String value) {
  final compact = _compactCallsign(value);
  return compact.length >= 4 &&
      RegExp(r'^[A-Z]{1,2}\d[A-Z0-9]{1,4}(?:/[A-Z0-9]+)?$').hasMatch(compact);
}

String _compactCallsign(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[\s_\-]+'), '');

bool _isRstReport(String value) {
  final compact = value.replaceAll(RegExp(r'[\s.。]'), '');
  return RegExp(r'^[1-5][1-9](?:[1-9])?$').hasMatch(compact);
}

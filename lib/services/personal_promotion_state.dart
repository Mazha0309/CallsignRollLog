import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:openlogtool/services/key_value_store.dart';

String personalPromotionScope(String serverInstanceId, String accountId) =>
    'personal-promotion.v1.${sha256.convert(utf8.encode(jsonEncode([
          serverInstanceId,
          accountId
        ])))}.';

String personalPromotionKey(
        String serverInstanceId, String accountId, String sessionId) =>
    '${personalPromotionScope(serverInstanceId, accountId)}${sha256.convert(utf8.encode(sessionId))}';

Future<bool> hasPendingPersonalPromotion(
    KeyValueStore store, String serverInstanceId, String accountId) async {
  final prefix = personalPromotionScope(serverInstanceId, accountId);
  for (final key in await store.getKeys()) {
    if (key.startsWith(prefix) && await store.getBool(key)) return true;
  }
  return false;
}

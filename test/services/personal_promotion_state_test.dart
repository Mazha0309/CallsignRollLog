import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/services/personal_promotion_state.dart';

void main() {
  test('pending promotion survives reopen and cannot block another account or server', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await openKeyValueStore();
    final key = personalPromotionKey('server', 'owner', 'session');
    expect(await hasPendingPersonalPromotion(store, 'server', 'owner'), false);
    await store.setBool(key, true);
    final reopened = await openKeyValueStore();
    expect(await hasPendingPersonalPromotion(reopened, 'server', 'owner'), true);
    expect(await hasPendingPersonalPromotion(reopened, 'server', 'other'), false);
    expect(await hasPendingPersonalPromotion(reopened, 'other', 'owner'), false);
    await store.remove(key);
    expect(await hasPendingPersonalPromotion(reopened, 'server', 'owner'), false);
  });
}

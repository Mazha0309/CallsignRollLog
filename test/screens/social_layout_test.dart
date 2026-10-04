import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/services/app_fonts.dart';
import 'social_screen_test.dart' show FakeSocial, FakeCollaboration, pumpSocial;

void main() {
  for (final width in [375.0, 1200.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('social surfaces at $width in $brightness', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const directory = String.fromEnvironment('UI_REVIEW_DIR');
        if (directory.isNotEmpty) {
          await tester.runAsync(() async {
            await loadAppFonts();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        final social = FakeSocial()
          ..snapshot = SocialSnapshot(friends: [
            SocialPerson.fromJson({'userId': 'one', 'username': 'BG5CRL'}),
            SocialPerson.fromJson({'userId': 'two', 'username': 'BA1ABC'}),
          ])
          ..searchPage = const SocialUserSearchPage(items: [
            SocialUserSearchResult(
                userId: 'one', username: 'BG5CRL', relationship: 'friend'),
            SocialUserSearchResult(
                userId: 'three', username: 'BG5XYZ', relationship: 'none'),
            SocialUserSearchResult(
                userId: 'four', username: 'BG5ABC', relationship: 'outgoing'),
          ]);
        await pumpSocial(tester, social, FakeCollaboration(),
            brightness: brightness);
        expect(tester.takeException(), isNull);
        if (directory.isNotEmpty) {
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(Uri.file(
                  '$directory/friends-${width.toInt()}-${brightness.name}.png')));
        }
        await tester.tap(find.byKey(const Key('social-add-friend')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('friend-username')), 'BG5');
        await tester.pump();
        await tester.tap(find.byKey(const Key('friend-search-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('friend-search-result-three')),
            findsOneWidget);
        if (directory.isNotEmpty) {
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(Uri.file(
                  '$directory/search-${width.toInt()}-${brightness.name}.png')));
        }
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/session_history_dialog.dart';

void main() {
  testWidgets('shared history rows show a share badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final entry = SessionListEntry(
                session: const Session(
                  sessionId: 'shared-1',
                  title: 'Bob 的点名',
                  status: 'active',
                  createdAt: '2026-09-13T12:00:00.000Z',
                  updatedAt: '2026-09-13T12:00:00.000Z',
                ),
                hasCollaborationBinding: false,
                isShared: true,
                sharedGrantorUsername: 'bob',
              );
              return Text(
                '${entry.isShared ? context.l10n.sharedSessionBadge : ''} ${entry.sharedGrantorUsername}',
                key: const Key('session-share-badge-shared-1'),
              );
            },
          ),
        ),
      ),
    );
    expect(
        find.byKey(const Key('session-share-badge-shared-1')), findsOneWidget);
    expect(find.textContaining('共享'), findsOneWidget);
  });
}

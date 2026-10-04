import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/models/log_entry.dart' as model;
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/home_screen.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge_log;
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'a revoked collaboration workbench exposes no session lifecycle actions',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessions = _SwitchingSessionProvider();
      final logs = LogProvider(
        sessionListLoader: () async => [
          _SwitchingSessionProvider.revokedSession,
        ],
        sessionLogPageLoader: (_, __, ___) async => [],
      );
      final collaboration = CollaborationProvider();
      addTearDown(sessions.dispose);
      addTearDown(logs.dispose);
      addTearDown(collaboration.dispose);

      await logs.reloadForSession(
        _SwitchingSessionProvider.revokedSession.sessionId,
      );
      logs.setCollaborationReadOnly(
        _SwitchingSessionProvider.revokedSession.sessionId,
        true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionProvider>.value(value: sessions),
            ChangeNotifierProvider<LogProvider>.value(value: logs),
            ChangeNotifierProvider<CollaborationProvider>.value(
              value: collaboration,
            ),
            ChangeNotifierProvider(
              create: (_) => DictionaryProvider(autoload: false),
            ),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(
            locale: Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AddRecordPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(logs.currentSessionReadOnly, isTrue);
      expect(
        find.byKey(const Key('workbench-read-only-banner')),
        findsOneWidget,
      );
      final oldForm = tester.widget<LogForm>(find.byType(LogForm));
      expect(oldForm.readOnly, isTrue);
      expect(
        oldForm.key,
        const ValueKey('log-form-revoked-session'),
      );
      expect(
        find.byKey(const Key('start-new-record')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('open-workbench-session-history')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('create-session')),
        findsNothing,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        logs.currentSessionId,
        _SwitchingSessionProvider.revokedSession.sessionId,
      );
      expect(logs.currentSessionReadOnly, isTrue);
      expect(
        sessions.currentSessionId,
        _SwitchingSessionProvider.revokedSession.sessionId,
      );
    },
  );

  testWidgets('a successful add rebuilds the mounted workbench table',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const canonical = bridge_log.LogEntry(
      syncId: 'web-visible-row',
      sessionId: 'revoked-session',
      time: '2026-07-26T09:20:46.808Z',
      controller: 'BG5CRL',
      callsign: 'BG5TEST',
      rstSent: '59',
      rstRcvd: '59',
      createdAt: '2026-07-26T09:20:46.808Z',
      updatedAt: '2026-07-26T09:20:46.808Z',
    );
    var durableLogs = <bridge_log.LogEntry>[];
    final sessions = _SwitchingSessionProvider();
    final logs = LogProvider(
      sessionListLoader: () async => [
        _SwitchingSessionProvider.revokedSession,
      ],
      sessionLogPageLoader: (_, __, ___) async => durableLogs,
      logCreator: (_, __) async {
        durableLogs = [canonical];
        return canonical;
      },
    );
    final collaboration = CollaborationProvider();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(collaboration.dispose);
    await logs.reloadForSession(
      _SwitchingSessionProvider.revokedSession.sessionId,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
          ChangeNotifierProvider<LogProvider>.value(value: logs),
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider(
            create: (_) => DictionaryProvider(autoload: false),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddRecordPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BG5TEST'), findsNothing);

    await logs.addLog(
      model.LogEntry(
        sessionId: _SwitchingSessionProvider.revokedSession.sessionId,
        time: canonical.time,
        controller: canonical.controller,
        callsign: canonical.callsign,
        report: canonical.rstSent ?? '',
        rstRcvd: canonical.rstRcvd ?? '',
        qth: '',
        device: '',
        power: '',
        antenna: '',
        height: '',
      ),
      sessionId: _SwitchingSessionProvider.revokedSession.sessionId,
    );
    await tester.pump();

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('BG5TEST'), findsOneWidget);
    expect(find.text('当前第 2 位'), findsOneWidget);
  });

  testWidgets(
      'workbench ordinal prefers saved records over a stale live-draft snapshot',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessions = _SwitchingSessionProvider();
    final logs = LogProvider(
      sessionListLoader: () async => [
        _SwitchingSessionProvider.revokedSession,
      ],
      sessionLogPageLoader: (_, __, ___) async => [
        _bridgeLog('row-1', 'BG5AAA'),
        _bridgeLog('row-2', 'BG5BBB'),
        _bridgeLog('row-3', 'BG5CCC'),
      ],
    );
    final collaboration = _StaleOrdinalCollaborationProvider();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(collaboration.dispose);
    await logs.reloadForSession(
      _SwitchingSessionProvider.revokedSession.sessionId,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
          ChangeNotifierProvider<LogProvider>.value(value: logs),
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider(
            create: (_) => DictionaryProvider(autoload: false),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddRecordPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前第 4 位'), findsOneWidget);
    expect(find.text('当前第 1 位'), findsNothing);
  });
}

bridge_log.LogEntry _bridgeLog(String syncId, String callsign) =>
    bridge_log.LogEntry(
      syncId: syncId,
      sessionId: 'revoked-session',
      time: '2026-07-26T09:20:46.808Z',
      controller: 'BG5CRL',
      callsign: callsign,
      rstSent: '59',
      rstRcvd: '59',
      createdAt: '2026-07-26T09:20:46.808Z',
      updatedAt: '2026-07-26T09:20:46.808Z',
    );

class _StaleOrdinalCollaborationProvider extends CollaborationProvider {
  @override
  LiveDraftSnapshotDto get liveDraftSnapshot => LiveDraftSnapshotDto(
        draft: LiveDraftDto(
          draftId: 'draft-1',
          sessionId: 'revoked-session',
          version: 1,
          fields: LiveDraftFieldsDto(const {}),
          fieldRevisions: const {},
          lastUpdatedBy: null,
          createdAt: DateTime.utc(2026, 7, 13),
          lastUpdatedAt: DateTime.utc(2026, 7, 13),
        ),
        locks: const [],
        currentOrdinal: 1,
        totalRecords: 0,
        previousRecord: null,
      );
}

final class _SwitchingSessionProvider extends SessionProvider {
  _SwitchingSessionProvider()
      : _current = revokedSession,
        super(sessionListLoader: () async => [revokedSession]);

  static const revokedSession = Session(
    sessionId: 'revoked-session',
    title: 'Revoked collaboration session',
    status: 'active',
    createdAt: '2026-07-13T10:00:00Z',
    updatedAt: '2026-07-13T10:00:00Z',
  );

  final Session _current;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String get currentSessionId => _current.sessionId;

  @override
  Session get currentSession => _current;
}

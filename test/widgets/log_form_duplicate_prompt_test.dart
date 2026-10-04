import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/widgets/callsign_history_field.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'duplicateCallsignWarningEnabled': true},
    );
  });

  testWidgets('blurring the callsign with a duplicate asks to continue',
      (tester) async {
    final logProvider = _StaticLogProvider([_oldLog()]);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await _enterCallsign(tester, 'BA4AAA');
    await tester.tap(find.byKey(const Key('outside-log-form')));
    await tester.pumpAndSettle();

    expect(find.text('呼号已记录过'), findsOneWidget);
    expect(find.text('BA4AAA 已在第 1 位记录过，继续添加吗？'), findsOneWidget);
    expect(find.text('继续添加'), findsOneWidget);
    expect(find.byKey(const Key('duplicate-continue-cancel')), findsOneWidget);
    expect(find.byKey(const Key('duplicate-continue-add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('duplicate-continue-cancel')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.descendant(
              of: find.byType(CallsignHistoryField),
              matching: find.byType(TextFormField),
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets(
      'required errors clear when corrected and stay clear after saving',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final logs = _StaticLogProvider([]);
    addTearDown(logs.dispose);
    await tester.pumpWidget(_app(logs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pumpAndSettle();
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), false);
    await tester.enterText(
        find.widgetWithText(TextFormField, '主控呼号 *'), 'BG5CRL');
    await _enterCallsign(tester, 'BG5NEW');
    await tester.pumpAndSettle();
    final fields =
        tester.stateList<FormFieldState<String>>(find.byType(TextFormField));
    expect(fields.any((f) => f.hasError), false);
    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pumpAndSettle();
    expect(logs.addCalls, 1);
    expect(
        tester
            .stateList<FormFieldState<String>>(find.byType(TextFormField))
            .any((f) => f.hasError),
        false);
  });

  testWidgets('idle duplicate callsign is checked after 700 milliseconds',
      (tester) async {
    final logProvider = _StaticLogProvider([_oldLog()]);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await _enterCallsign(tester, 'BA4AAA');
    await tester.pump(const Duration(milliseconds: 699));
    expect(find.byKey(const Key('duplicate-continue-add')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('duplicate-continue-add')), findsOneWidget);
    expect(find.text('BA4AAA 已在第 1 位记录过，继续添加吗？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-continue-add')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('saving a duplicate asks update or add, update keeps time',
      (tester) async {
    final logProvider = _StaticLogProvider([_oldLog()]);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'QTH'),
      '上海',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '主控呼号 *'),
      'BG5CRL',
    );
    await _enterCallsign(tester, 'BA4AAA');
    await tester.tap(find.byKey(const Key('outside-log-form')));
    await tester.pumpAndSettle();

    expect(find.text('呼号已记录过'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-continue-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('duplicate-save-update-old')), findsOneWidget);
    expect(find.byKey(const Key('duplicate-save-add-new')), findsOneWidget);

    await tester.tap(find.byKey(const Key('duplicate-save-update-old')));
    await tester.pumpAndSettle();

    expect(logProvider.updateCalls, 1);
    final updated = logProvider.updatedLog!;
    expect(updated.callsign, 'BA4AAA');
    expect(updated.qth, '上海');
    expect(updated.time, '2026-07-13T12:00:00Z');
    expect(find.text('记录已更新'), findsOneWidget);
  });

  testWidgets('duplicate dialogs show the original list ordinal',
      (tester) async {
    final logProvider = _StaticLogProvider([
      _oldLog(),
      _oldLog().copyWith(
        id: 'old-2',
        callsign: 'BG7XYZ',
        qth: '广州',
      ),
      _oldLog().copyWith(
        id: 'old-3',
        callsign: 'BG5FBT',
        qth: '南京',
      ),
    ]);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await _enterCallsign(tester, 'BG5FBT');
    await tester.tap(find.byKey(const Key('outside-log-form')));
    await tester.pumpAndSettle();

    // 失焦弹窗显示第 3 位。
    expect(find.text('BG5FBT 已在第 3 位记录过，继续添加吗？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-continue-add')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '主控呼号 *'),
      'BG5CRL',
    );
    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 保存弹窗的旧记录摘要含第 3 位。
    expect(find.byKey(const Key('duplicate-save-update-old')), findsOneWidget);
    expect(find.textContaining('第 3 位'), findsWidgets);
    expect(find.textContaining('原记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('duplicate-save-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('saving appends W to a plain numeric power', (tester) async {
    final logProvider = _StaticLogProvider(const []);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '主控呼号 *'),
      'BG5CRL',
    );
    await _enterCallsign(tester, 'BG5FBT');
    await tester.enterText(find.widgetWithText(TextFormField, '功率'), '50');
    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(logProvider.addCalls, 1);
    expect(logProvider.addedLog!.power, '50W');

    // 已带单位的功率原样保存。
    await tester.enterText(find.widgetWithText(TextFormField, '功率'), '5kW');
    await tester.enterText(
      find.widgetWithText(TextFormField, '主控呼号 *'),
      'BG5CRL',
    );
    await _enterCallsign(tester, 'BG7XYZ');
    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(logProvider.addCalls, 2);
    expect(logProvider.addedLog!.power, '5kW');
  });

  testWidgets('plain numeric power and height expose local format candidates',
      (tester) async {
    final logProvider = _StaticLogProvider(const []);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    final power = find.widgetWithText(TextFormField, '功率');
    await tester.tap(power);
    await tester.enterText(power, '15');
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('format-suggestion-power-15W')), findsOneWidget);
    expect(find.byKey(const Key('format-suggestion-power-15')), findsOneWidget);

    final height = find.widgetWithText(TextFormField, '高度');
    await tester.tap(height);
    await tester.enterText(height, '5');
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('format-suggestion-height-5楼')), findsOneWidget);
    expect(
        find.byKey(const Key('format-suggestion-height-5米')), findsOneWidget);

    await tester.enterText(height, 'dm');
    await tester.pumpAndSettle();
    expect(find.text('地面'), findsOneWidget);
    expect(find.text('DM · dimian'), findsOneWidget);

    await tester.enterText(height, 'gaojia');
    await tester.pumpAndSettle();
    expect(find.text('高架'), findsOneWidget);
    expect(find.text('GJ · gaojia'), findsOneWidget);

    for (final value in const ['地面', '高架']) {
      await tester.enterText(height, value);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-autocomplete-options')), findsNothing);
    }

    await tester.tap(power);
    for (final value in const ['中功率', '高功率']) {
      await tester.enterText(power, value);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-autocomplete-options')), findsNothing);
    }
  });

  testWidgets('saving a duplicate as new record adds without touching old',
      (tester) async {
    final logProvider = _StaticLogProvider([_oldLog()]);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '主控呼号 *'),
      'BG5CRL',
    );
    await _enterCallsign(tester, 'BA4AAA');
    await tester.tap(find.byKey(const Key('outside-log-form')));
    await tester.pumpAndSettle();

    expect(find.text('呼号已记录过'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-continue-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('duplicate-save-update-old')), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-save-add-new')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(logProvider.updateCalls, 0);
    expect(find.byKey(const Key('duplicate-save-update-old')), findsNothing);
  });

  testWidgets('cancelling the duplicate save dialog does nothing',
      (tester) async {
    final logProvider = _StaticLogProvider([_oldLog()]);
    addTearDown(logProvider.dispose);
    await tester.pumpWidget(_app(logProvider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '主控呼号 *'),
      'BG5CRL',
    );
    await _enterCallsign(tester, 'BA4AAA');
    await tester.tap(find.byKey(const Key('outside-log-form')));
    await tester.pumpAndSettle();

    expect(find.text('呼号已记录过'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-continue-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-log-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('duplicate-save-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('duplicate-save-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(logProvider.updateCalls, 0);
    expect(find.byKey(const Key('duplicate-save-update-old')), findsNothing);
    expect(find.byKey(const Key('save-log-record')), findsOneWidget);
  });
}

LogEntry _oldLog() => LogEntry(
      id: 'old-1',
      sessionId: 's1',
      time: '2026-07-13T12:00:00Z',
      controller: 'BG5CRL',
      callsign: 'BA4AAA',
      report: '59',
      rstRcvd: '59',
      qth: '杭州',
      device: 'FT-991A',
      power: '50W',
      antenna: 'GP',
      height: '8m',
      createdAt: '2026-07-13T12:00:00Z',
      updatedAt: '2026-07-13T12:00:00Z',
    );

Future<void> _enterCallsign(WidgetTester tester, String text) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CallsignHistoryField),
      matching: find.byType(TextFormField),
    ),
  );
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: find.byType(CallsignHistoryField),
      matching: find.byType(TextFormField),
    ),
    text,
  );
  await tester.pump();
}

Widget _app(LogProvider logProvider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<CollaborationProvider>(
          create: (_) => CollaborationProvider(),
        ),
        ChangeNotifierProvider<LogProvider>.value(value: logProvider),
        ChangeNotifierProvider<DictionaryProvider>(
          create: (_) => _NoopDictionaryProvider(),
        ),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(
                child: SingleChildScrollView(
                  child: LogForm(),
                ),
              ),
              Container(
                key: const Key('outside-log-form'),
                width: double.infinity,
                height: 80,
                color: Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );

class _StaticLogProvider extends LogProvider {
  _StaticLogProvider(List<LogEntry> initialLogs) : _logs = initialLogs;

  final List<LogEntry> _logs;
  int updateCalls = 0;
  int addCalls = 0;
  LogEntry? updatedLog;
  LogEntry? addedLog;

  @override
  List<LogEntry> get logs => _logs;

  @override
  Future<void> updateLog(int index, LogEntry log) async {
    updateCalls += 1;
    updatedLog = log;
  }

  @override
  Future<void> addLog(LogEntry log, {String? sessionId}) async {
    addCalls += 1;
    addedLog = log;
  }
}

class _NoopDictionaryProvider extends DictionaryProvider {
  _NoopDictionaryProvider() : super(autoload: false);

  @override
  Future<void> addDevice(String device) async {}

  @override
  Future<void> addAntenna(String antenna) async {}

  @override
  Future<void> addCallsign(String callsign) async {}

  @override
  Future<void> addQth(String qth) async {}
}

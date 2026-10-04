import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge_log;
import 'package:openlogtool/src/bridge/models/session.dart' as bridge_session;
import 'package:openlogtool/widgets/log_table.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a successful provider add replaces the empty table immediately',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => [
        const bridge_session.Session(
          sessionId: 'table-session',
          title: 'Table session',
          status: 'active',
          createdAt: '2026-07-13T10:00:00Z',
          updatedAt: '2026-07-13T10:00:00Z',
        ),
      ],
      sessionLogPageLoader: (_, __, ___) async => [],
      logCreator: (_, __) async => const bridge_log.LogEntry(
        syncId: 'fresh-row',
        sessionId: 'table-session',
        time: '2026-07-13T12:00:00Z',
        controller: 'BG5CRL',
        callsign: 'BG5FRESH',
        rstSent: '59',
        rstRcvd: '59',
        createdAt: '2026-07-13T12:00:00Z',
        updatedAt: '2026-07-13T12:00:00Z',
      ),
    );
    addTearDown(logProvider.dispose);
    await logProvider.reloadForSession('table-session');
    await _pumpLogTable(tester, logProvider);
    expect(find.text('暂无已保存记录'), findsOneWidget);

    await logProvider.addLog(
      LogEntry(
        sessionId: 'table-session',
        time: '2026-07-13T12:00:00Z',
        controller: 'BG5CRL',
        callsign: 'BG5FRESH',
        report: '59',
        rstRcvd: '59',
        qth: '',
        device: '',
        power: '',
        antenna: '',
        height: '',
      ),
      sessionId: 'table-session',
    );
    await tester.pump();

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('BG5FRESH'), findsOneWidget);
    expect(find.text('暂无已保存记录'), findsNothing);
  });

  testWidgets(
      'replacing an existing projection reconstructs rows and shows the newest record',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final old = _log(
      id: 'old-row',
      time: 'OLD_TIME',
      report: 'OLD_SENT',
      rstRcvd: 'OLD_RCVD',
    );
    final fresh = _log(
      id: 'fresh-row',
      time: 'NEW_TIME',
      report: 'NEW_SENT',
      rstRcvd: 'NEW_RCVD',
    );
    final logProvider = _StaticLogProvider([old]);
    await _pumpLogTable(tester, logProvider);

    final oldTable = tester.widget<DataTable>(find.byType(DataTable));
    final oldProjectionKey = oldTable.key;
    expect(oldTable.rows.single.key, const ValueKey('old-row'));

    logProvider.replaceLogs([old, fresh]);
    await tester.pump();

    final rebuiltTable = tester.widget<DataTable>(find.byType(DataTable));
    expect(rebuiltTable.key, isNot(oldProjectionKey));
    expect(
      rebuiltTable.rows.map((row) => row.key),
      const [ValueKey('fresh-row'), ValueKey('old-row')],
    );
    expect(_textOf(tester, rebuiltTable.rows.first.cells[4].child), 'NEW_SENT');
    expect(find.text('NEW_SENT'), findsOneWidget);
  });

  testWidgets('keeps RST sent and received aligned with the newest row',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final logs = <LogEntry>[
      _log(
        id: 'old',
        time: 'OLD_TIME',
        report: 'OLD_SENT',
        rstRcvd: 'OLD_RCVD',
      ),
      _log(
        id: 'new',
        time: '20:31',
        report: 'SENT_CELL',
        rstRcvd: 'RCVD_CELL',
      ),
    ];
    final logProvider = _StaticLogProvider(logs);
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(height: 400, child: LogTable()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var table = tester.widget<DataTable>(find.byType(DataTable));
    expect(
      table.columns.map((column) => _textOf(tester, column.label)).toList(),
      <String>[
        '#',
        '时间',
        '主控',
        '来台呼号',
        'RST 发',
        'RST 收',
        'QTH',
        '设备',
        '功率',
        '天线',
        '高度',
        '备注',
      ],
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-log-actions-column')),
        matching: find.text('操作'),
      ),
      findsOneWidget,
    );
    expect(
      table.rows.first.cells
          .map((cell) => _textOf(tester, cell.child))
          .toList(),
      <String>[
        '2',
        '20:31',
        'CTRL_CELL',
        'CALL_CELL',
        'SENT_CELL',
        'RCVD_CELL',
        'QTH_CELL',
        'DEVICE_CELL',
        'POWER_CELL',
        'ANTENNA_CELL',
        'HEIGHT_CELL',
        'REMARKS_CELL',
      ],
    );
    expect(_textOf(tester, table.rows.last.cells[4].child), 'OLD_SENT');
    expect(_textOf(tester, table.rows.last.cells[5].child), 'OLD_RCVD');

    final editButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byKey(const Key('desktop-log-actions-new')),
            matching: find.byType(IconButton),
          )
          .first,
    );
    editButton.onPressed!();
    await tester.pump();

    table = tester.widget<DataTable>(find.byType(DataTable));
    final sentField = _field(tester, table.rows.first.cells[4].child);
    final receivedField = _field(tester, table.rows.first.cells[5].child);
    expect(sentField.controller!.text, 'SENT_CELL');
    expect(receivedField.controller!.text, 'RCVD_CELL');

    sentField.controller!.text = 'SENT_EDITED';
    receivedField.controller!.text = 'RCVD_EDITED';
    final saveButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byKey(const Key('desktop-log-actions-new')),
            matching: find.byType(IconButton),
          )
          .first,
    );
    saveButton.onPressed!();
    await tester.pumpAndSettle();

    expect(logProvider.updatedIndex, 1);
    expect(
      (logProvider.updatedLog?.report, logProvider.updatedLog?.rstRcvd),
      ('SENT_EDITED', 'RCVD_EDITED'),
    );
  });

  testWidgets('shows a canonical UTC log time in the device timezone',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final localTime = DateTime(2026, 7, 13, 20, 30);
    final logProvider = _StaticLogProvider([
      _log(
        id: 'timezone-log',
        time: localTime.toUtc().toIso8601String(),
        report: '59',
        rstRcvd: '59',
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LogTable(readOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(_textOf(tester, table.rows.single.cells[1].child), '20:30');
  });

  testWidgets('desktop actions stay pinned and Shift-wheel scrolls the data',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final logProvider = _StaticLogProvider([
      _log(id: 'pinned-log', time: '20:30', report: '59', rstRcvd: '59'),
    ]);
    await _pumpLogTable(tester, logProvider);

    expect(
      find.byKey(const Key('log-table-horizontal-scroll-hint')),
      findsOneWidget,
    );
    final action = find.byKey(const Key('desktop-log-actions-pinned-log'));
    final actionX = tester.getTopLeft(action).dx;
    final surface = find.byKey(const Key('log-table-surface'));
    final horizontalView = tester
        .widgetList<SingleChildScrollView>(
          find.descendant(
              of: surface, matching: find.byType(SingleChildScrollView)),
        )
        .singleWhere((view) => view.scrollDirection == Axis.horizontal);
    final horizontalScrollable = find.descendant(
      of: find.byWidget(horizontalView),
      matching: find.byType(Scrollable),
    );
    final position =
        tester.state<ScrollableState>(horizontalScrollable).position;
    expect(position.pixels, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final location = tester.getCenter(find.byType(DataTable));
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.sendEventToBinding(
      pointer.scroll(const Offset(0, 240)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(position.pixels, greaterThan(0));
    expect(tester.getTopLeft(action).dx, actionX);
  });

  testWidgets('default pagination keeps ten newest RST records on first page',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'recordEditorDialogEnabled': false});
    final logProvider = _StaticLogProvider(
      List<LogEntry>.generate(
        12,
        (index) => _log(
          id: 'log-${index + 1}',
          time: 'TIME_${index + 1}',
          report: 'SENT_${index + 1}',
          rstRcvd: 'RCVD_${index + 1}',
        ),
      ),
    );
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: LogTable(readOnly: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(find.byKey(const Key('log-table-surface')), findsOneWidget);
    expect(find.byKey(const Key('log-pagination')), findsOneWidget);
    final verticalTableScroll = tester
        .widgetList<SingleChildScrollView>(
          find.descendant(
            of: find.byKey(const Key('log-table-surface')),
            matching: find.byType(SingleChildScrollView),
          ),
        )
        .singleWhere(
          (scroll) => scroll.scrollDirection == Axis.vertical,
        );
    expect(verticalTableScroll.physics, isA<NeverScrollableScrollPhysics>());
    expect(table.rows, hasLength(10));
    expect(_textOf(tester, table.rows.first.cells[4].child), 'SENT_12');
    expect(_textOf(tester, table.rows.first.cells[5].child), 'RCVD_12');
    expect(_textOf(tester, table.rows.last.cells[4].child), 'SENT_3');
    expect(find.text('SENT_2'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('table honors configurable page size', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'recordEditorDialogEnabled': false,
        'tablePageSize': 5,
      },
    );
    final logProvider = _StaticLogProvider(
      List<LogEntry>.generate(
        12,
        (index) => _log(
          id: 'log-${index + 1}',
          time: 'TIME_${index + 1}',
          report: 'SENT_${index + 1}',
          rstRcvd: 'RCVD_${index + 1}',
        ),
      ),
    );
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: LogTable(readOnly: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(5));
    expect(_textOf(tester, table.rows.first.cells[4].child), 'SENT_12');
    expect(_textOf(tester, table.rows.last.cells[4].child), 'SENT_8');
    expect(find.text('SENT_1'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);

    await settingsProvider.setTablePageSize(10);
    await tester.pump();

    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(10));
    expect(_textOf(tester, table.rows.last.cells[4].child), 'SENT_3');
    expect(find.text('SENT_2'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // 页数变小导致当前页越界时，回到最后一页（而不是显示空白切片）
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    await settingsProvider.setTablePageSize(5);
    await tester.pump();

    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(5));
    expect(find.text('2 / 3'), findsOneWidget);

    await settingsProvider.setTablePageSize(25);
    await tester.pump();

    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(12));
    expect(find.byKey(const Key('log-pagination')), findsNothing);
    expect(find.text('SENT_1'), findsOneWidget);
  });

  testWidgets('enlarging page size snaps back from the last page',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'recordEditorDialogEnabled': false,
        'tablePageSize': 5,
      },
    );
    final logProvider = _StaticLogProvider(
      List<LogEntry>.generate(
        12,
        (index) => _log(
          id: 'log-${index + 1}',
          time: 'TIME_${index + 1}',
          report: 'SENT_${index + 1}',
          rstRcvd: 'RCVD_${index + 1}',
        ),
      ),
    );
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: LogTable(readOnly: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('3 / 3'), findsOneWidget);

    // 每页 5 条时在最后一页 (3/3)，改回 10 条/页后只剩 2 页，
    // 当前页越界，应自动收回到最后一页 (2/2)。
    await settingsProvider.setTablePageSize(10);
    await tester.pump();

    var table = tester.widget<DataTable>(find.byType(DataTable));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(table.rows, hasLength(2));
    expect(_textOf(tester, table.rows.first.cells[4].child), 'SENT_2');
    expect(_textOf(tester, table.rows.last.cells[4].child), 'SENT_1');
    expect(find.text('SENT_3'), findsNothing);
  });

  testWidgets('non-owned collaboration log exposes only a read-only hint',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final logProvider = _StaticLogProvider([
      _log(
        id: 'own-log',
        time: 'OWN_TIME',
        report: '59',
        rstRcvd: '59',
      ),
      _log(
        id: 'other-log',
        time: 'OTHER_TIME',
        report: '59',
        rstRcvd: '59',
      ),
    ]);
    logProvider.setLogMutationGuard(
      (log) => log.id == 'other-log' ? 'COLLABORATION_LOG_NOT_OWNED' : null,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(height: 400, child: LogTable()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final otherActions = find.byKey(
      const Key('desktop-log-actions-other-log'),
    );
    expect(
      find.descendant(
        of: otherActions,
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
    final tooltip = tester.widget<Tooltip>(
      find.descendant(
        of: otherActions,
        matching: find.byType(Tooltip),
      ),
    );
    expect(
      tooltip.message,
      'You can change or delete only records that you created.',
    );

    final ownActions = find.byKey(const Key('desktop-log-actions-own-log'));
    expect(
      find.descendant(
        of: ownActions,
        matching: find.byType(IconButton),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('phone uses expandable record cards with an inline editor',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final logProvider = _StaticLogProvider([
      _log(
        id: 'mobile-log',
        time: '20:31',
        report: '59',
        rstRcvd: '47',
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: LogTable(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(find.byKey(const Key('mobile-log-list')), findsOneWidget);
    expect(find.byKey(const Key('mobile-log-card-mobile-log')), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('CALL_CELL'), findsOneWidget);
    expect(find.text('59/47'), findsOneWidget);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('QTH_CELL'), findsOneWidget);
    expect(find.text('DEVICE_CELL'), findsOneWidget);
    expect(find.byKey(const Key('mobile-edit-log-mobile-log')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-edit-log-mobile-log')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-log-editor-mobile-log')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('mobile-edit-field-callsign')),
      'BG5NEW',
    );
    await tester.ensureVisible(
      find.byKey(const Key('mobile-save-log-mobile-log')),
    );
    await tester.tap(find.byKey(const Key('mobile-save-log-mobile-log')));
    await tester.pumpAndSettle();

    expect(logProvider.updateCalls, 1);
    expect(logProvider.updatedLog?.callsign, 'BG5NEW');
    expect(find.byKey(const Key('mobile-log-editor-mobile-log')), findsNothing);
  });

  testWidgets('dialog editor opens by default and saves through the patch',
      (tester) async {
    final logProvider = _StaticLogProvider([
      _log(
        id: 'dialog-edit-log',
        time: '20:31',
        report: '59',
        rstRcvd: '59',
      ),
    ]);
    await _pumpLogTable(tester, logProvider, dialogEditor: true);

    final editButton = tester
        .widgetList<IconButton>(
          find.descendant(
            of: find.byKey(
              const Key('desktop-log-actions-dialog-edit-log'),
            ),
            matching: find.byType(IconButton),
          ),
        )
        .first;
    editButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
        find.byKey(const Key('record-editor-field-callsign')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('CALL_CELL'),
      ),
      findsWidgets,
    );

    await tester.enterText(
      find.byKey(const Key('record-editor-field-callsign')),
      'BG5DIALOG',
    );
    await tester.tap(find.byKey(const Key('record-editor-save')));
    await tester.pumpAndSettle();

    expect(logProvider.updateCalls, 1);
    expect(logProvider.updatedLog?.callsign, 'BG5DIALOG');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('runtime locale switch updates table and deletion copy',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final locale = ValueNotifier<Locale>(const Locale('zh', 'CN'));
    addTearDown(locale.dispose);
    final logProvider = _StaticLogProvider([
      _log(
        id: 'localized-log',
        time: '20:31',
        report: '59',
        rstRcvd: '59',
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, currentLocale, child) => MaterialApp(
            locale: currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(height: 400, child: LogTable()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('主控'), findsOneWidget);
    expect(find.byTooltip('编辑记录'), findsOneWidget);

    locale.value = const Locale('en', 'US');
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(
      table.columns.map((column) => _textOf(tester, column.label)).toList(),
      <String>[
        '#',
        'Time',
        'Controller',
        'Callsign',
        'RST sent',
        'RST received',
        'QTH',
        'Radio',
        'Power',
        'Antenna',
        'Height',
        'Remarks',
      ],
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-log-actions-column')),
        matching: find.text('Actions'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit record'), findsOneWidget);
    expect(find.byTooltip('Delete record'), findsOneWidget);
    expect(find.text('主控'), findsNothing);

    _openDeleteDialog(tester);
    await tester.pumpAndSettle();
    expect(find.text('Delete record'), findsOneWidget);
    expect(find.text('Delete this record?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Delete'), findsOneWidget);

    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Delete'),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Record deleted'), findsOneWidget);
  });

  testWidgets('en_US localizes the empty table state', (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );

    await _pumpLogTable(
      tester,
      _StaticLogProvider([]),
      locale: const Locale('en', 'US'),
    );

    expect(find.text('No saved records'), findsOneWidget);
    expect(
      find.text('Add the first record using the form above.'),
      findsOneWidget,
    );
    expect(find.text('暂无已保存记录'), findsNothing);
  });

  testWidgets('failed save keeps editing controls and the entered value',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final logProvider = _StaticLogProvider([
      _log(
        id: 'save-failure',
        time: '20:31',
        report: '59',
        rstRcvd: '59',
      ),
    ])
      ..updateError = StateError('write failed');

    await _pumpLogTable(tester, logProvider);

    var table = tester.widget<DataTable>(find.byType(DataTable));
    final editButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byKey(
              const Key('desktop-log-actions-save-failure'),
            ),
            matching: find.byType(IconButton),
          )
          .first,
    );
    editButton.onPressed!();
    await tester.pump();

    table = tester.widget<DataTable>(find.byType(DataTable));
    _field(tester, table.rows.single.cells[3].child).controller!.text =
        'USER_EDIT';
    final saveButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byKey(
              const Key('desktop-log-actions-save-failure'),
            ),
            matching: find.byType(IconButton),
          )
          .first,
    );
    saveButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(logProvider.updateCalls, 1);
    expect(
      _field(tester, table.rows.single.cells[3].child).controller!.text,
      'USER_EDIT',
    );
    expect(find.byTooltip('保存'), findsOneWidget);
    expect(find.text('操作失败：Bad state: write failed'), findsOneWidget);
  });

  testWidgets('delete awaits completion and ignores repeated confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final deletion = Completer<void>();
    final logProvider = _StaticLogProvider([
      _log(
        id: 'delete-pending',
        time: '20:31',
        report: '59',
        rstRcvd: '59',
      ),
    ])
      ..deleteGate = deletion;

    await _pumpLogTable(tester, logProvider);
    _openDeleteDialog(tester);
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '删除'),
    );
    confirmButton.onPressed!();
    confirmButton.onPressed!();
    await tester.pump();

    expect(logProvider.deleteCalls, 1);
    expect(find.text('删除记录'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('记录已删除'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    deletion.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('删除记录'), findsNothing);
    expect(find.text('记录已删除'), findsOneWidget);
    expect(logProvider.logs, isEmpty);
  });

  testWidgets('failed delete keeps the record and dialog available to retry',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'paginationEnabled': false,
        'recordEditorDialogEnabled': false
      },
    );
    final logProvider = _StaticLogProvider([
      _log(
        id: 'delete-failure',
        time: '20:31',
        report: '59',
        rstRcvd: '59',
      ),
    ])
      ..deleteError = StateError('delete failed');

    await _pumpLogTable(tester, logProvider);
    _openDeleteDialog(tester);
    await tester.pumpAndSettle();

    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '删除'),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(logProvider.deleteCalls, 1);
    expect(logProvider.logs.single.id, 'delete-failure');
    expect(find.text('删除记录'), findsOneWidget);
    expect(find.text('记录已删除'), findsNothing);
    expect(find.text('操作失败：Bad state: delete failed'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '删除'),
          )
          .onPressed,
      isNotNull,
    );
  });

  _searchTests();
}

Future<void> _pumpLogTable(
  WidgetTester tester,
  LogProvider logProvider, {
  Locale locale = const Locale('zh', 'CN'),
  bool dialogEditor = false,
}) async {
  SharedPreferences.setMockInitialValues(
    <String, Object>{'recordEditorDialogEnabled': dialogEditor},
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LogProvider>.value(value: logProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
        ),
        ChangeNotifierProvider<DictionaryProvider>(
          create: (_) => DictionaryProvider(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(height: 400, child: LogTable()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _openDeleteDialog(WidgetTester tester) {
  final deleteButton = tester
      .widgetList<IconButton>(
        find.descendant(
          of: find.byKey(const Key('desktop-log-actions-column')),
          matching: find.byType(IconButton),
        ),
      )
      .last;
  deleteButton.onPressed!();
}

String _textOf(WidgetTester tester, Widget root) => tester
    .widgetList<Text>(
      find.descendant(of: find.byWidget(root), matching: find.byType(Text)),
    )
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join();

TextField _field(WidgetTester tester, Widget root) => tester.widget<TextField>(
      find.descendant(
        of: find.byWidget(root),
        matching: find.byType(TextField),
      ),
    );

LogEntry _log({
  required String id,
  required String time,
  required String report,
  required String rstRcvd,
}) =>
    LogEntry(
      id: id,
      time: time,
      controller: 'CTRL_CELL',
      callsign: 'CALL_CELL',
      report: report,
      rstRcvd: rstRcvd,
      qth: 'QTH_CELL',
      device: 'DEVICE_CELL',
      power: 'POWER_CELL',
      antenna: 'ANTENNA_CELL',
      height: 'HEIGHT_CELL',
      remarks: 'REMARKS_CELL',
    );

class _StaticLogProvider extends LogProvider {
  _StaticLogProvider(
    List<LogEntry> initialLogs, {
    String? sessionId,
  })  : _logs = initialLogs,
        _testSessionId = sessionId;

  List<LogEntry> _logs;
  String? _testSessionId;
  int? updatedIndex;
  LogEntry? updatedLog;
  Object? updateError;
  int updateCalls = 0;
  Completer<void>? deleteGate;
  Object? deleteError;
  int deleteCalls = 0;

  @override
  List<LogEntry> get logs => _logs;

  @override
  String? get currentSessionId => _testSessionId;

  void replaceLogs(List<LogEntry> logs) {
    _logs = logs;
    notifyListeners();
  }

  void replaceSession(String sessionId, List<LogEntry> logs) {
    _testSessionId = sessionId;
    _logs = logs;
    notifyListeners();
  }

  @override
  Future<void> updateLog(int index, LogEntry log) async {
    updateCalls += 1;
    final error = updateError;
    if (error != null) throw error;
    updatedIndex = index;
    updatedLog = log;
  }

  @override
  Future<void> deleteLogById(String syncId) async {
    deleteCalls += 1;
    await deleteGate?.future;
    final error = deleteError;
    if (error != null) throw error;
    _logs = [
      for (final log in _logs)
        if (log.id != syncId) log,
    ];
    notifyListeners();
  }
}

void _searchTests() {
  testWidgets('desktop search filters rows and pagination', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'recordEditorDialogEnabled': false},
    );
    final logProvider = _StaticLogProvider(
      List<LogEntry>.generate(
        12,
        (index) => _log(
          id: 'log-${index + 1}',
          time: 'TIME_${index + 1}',
          report: 'SENT_${index + 1}',
          rstRcvd: 'RCVD_${index + 1}',
        ),
      ),
    );
    final settingsProvider = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LogTable(readOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('log-table-search')), findsOneWidget);
    expect(find.text('SENT_12'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('log-table-search')), 'SENT_12');
    await tester.pump();

    var table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(1));
    expect(_textOf(tester, table.rows.single.cells.first.child), '12');
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('SENT_12'),
      ),
      findsOneWidget,
    );
    expect(find.text('SENT_11'), findsNothing);
    // 过滤后不足一页时不显示分页控件。
    expect(find.byKey(const Key('log-pagination')), findsNothing);

    await tester.tap(find.byKey(const Key('log-table-search-clear')));
    await tester.pump();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(10));
    expect(find.text('SENT_12'), findsOneWidget);
  });

  testWidgets('search with no matches shows a hint', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'recordEditorDialogEnabled': false},
    );
    final logProvider = _StaticLogProvider(
      [_log(id: 'log-1', time: 'T1', report: 'S1', rstRcvd: 'R1')],
    );
    final settingsProvider = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LogTable(readOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('log-table-search')),
      'NOPE_NOPE',
    );
    await tester.pump();

    expect(find.text('没有匹配的记录'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('search matches the displayed local time', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'recordEditorDialogEnabled': false},
    );
    final visibleTime = DateTime(2026, 7, 13, 20, 30);
    final logProvider = _StaticLogProvider([
      _log(
        id: 'visible-time',
        time: visibleTime.toUtc().toIso8601String(),
        report: 'VISIBLE_TIME_RESULT',
        rstRcvd: '59',
      ),
      _log(
        id: 'other-time',
        time: '07:45',
        report: 'OTHER_TIME_RESULT',
        rstRcvd: '59',
      ),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LogTable(readOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('log-table-search')),
      '20:30',
    );
    await tester.pump();

    expect(find.text('VISIBLE_TIME_RESULT'), findsOneWidget);
    expect(find.text('OTHER_TIME_RESULT'), findsNothing);
  });

  testWidgets('switching sessions clears the previous search state',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'recordEditorDialogEnabled': false},
    );
    final logProvider = _StaticLogProvider(
      [
        _log(
          id: 'old-session-log',
          time: '08:00',
          report: 'ONLY_OLD_SESSION',
          rstRcvd: '59',
        ),
      ],
      sessionId: 'session-a',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LogTable(readOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('log-table-search')),
      'ONLY_OLD_SESSION',
    );
    await tester.pump();

    logProvider.replaceSession('session-b', [
      _log(
        id: 'new-session-log',
        time: '08:01',
        report: 'VISIBLE_NEW_SESSION',
        rstRcvd: '59',
      ),
    ]);
    await tester.pump();

    final searchField =
        tester.widget<TextField>(find.byKey(const Key('log-table-search')));
    expect(searchField.controller!.text, isEmpty);
    expect(find.text('VISIBLE_NEW_SESSION'), findsOneWidget);
  });

  testWidgets('mobile search filters cards', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'recordEditorDialogEnabled': false},
    );
    final logProvider = _StaticLogProvider(
      List<LogEntry>.generate(
        6,
        (index) => _log(
          id: 'log-${index + 1}',
          time: 'TIME_${index + 1}',
          report: 'SENT_${index + 1}',
          rstRcvd: 'RCVD_${index + 1}',
        ),
      ),
    );
    final settingsProvider = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LogProvider>.value(value: logProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LogTable(readOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-log-list')), findsOneWidget);
    expect(find.byKey(const Key('log-table-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('log-table-search')),
      'SENT_3',
    );
    await tester.pump();

    expect(find.text('SENT_3'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('SENT_2'), findsNothing);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/providers/app_info_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/screens/home_screen.dart';
import 'package:openlogtool/screens/web_controller_tab_page.dart';
import 'package:openlogtool/services/web_controller_bridge.dart'
    if (dart.library.io) 'package:openlogtool/services/web_controller_bridge_stub.dart'
    as web_bridge;
import 'package:openlogtool/services/app_logger.dart';
import 'package:openlogtool/services/controller_window_service.dart';
import 'package:openlogtool/services/app_fonts.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/services/url_sync.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/utils/windows_accessibility_guard.dart';
import 'package:openlogtool/bootstrap/rust_library_loader.dart';
import 'package:openlogtool/src/bridge/frb_generated.dart';
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 主控屏标签页的初始参数快照。
/// 启动时捕获，不随主窗口后续的页面、会话切换改变。
late final ({bool isController, String? sessionId}) controllerTabRoute;

void main(List<String> args) {
  runZonedGuarded<Future<void>>(
    () => _bootstrap(args),
    (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Uncaught asynchronous error',
        source: 'Zone',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

Future<void> _bootstrap(List<String> args) async {
  // URL 只由 UrlSync 管理，避免 Flutter 路由与会话查询参数争用 history。
  controllerTabRoute = web_bridge.controllerTabRouteSnapshot();
  UrlSync.configure();
  WidgetsFlutterBinding.ensureInitialized();
  final isControllerChild =
      ControllerWindowService.isControllerChildArguments(args);
  await AppLogger.instance.init(trackRunState: !isControllerChild);
  AppLogger.instance.installDebugPrintCapture();
  FlutterError.onError = (details) {
    AppLogger.instance.log(
      AppLogLevel.error,
      'Flutter framework error',
      source: details.library ?? 'Flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.log(
      AppLogLevel.error,
      'Uncaught platform error',
      source: 'PlatformDispatcher',
      error: error,
      stackTrace: stack,
    );
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'platform',
    ));
    return true;
  };
  try {
    await loadAppFonts();
  } catch (error, stackTrace) {
    AppLogger.instance.log(
      AppLogLevel.warning,
      'Failed to load bundled fonts; using system fonts',
      source: 'Bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // 桌面子窗口只渲染主控屏，不初始化 Rust、本地数据库或主应用 Provider。
  final controllerWindow =
      await ControllerWindowService.currentWindowLaunch(args);
  if (controllerWindow != null) {
    runApp(
      WindowsAccessibilityCrashGuard(
        child: _ApplicationLifecycleLogger(
          child: ControllerDisplayWindowApp(session: controllerWindow),
        ),
      ),
    );
    return;
  }

  // Always use the Rust library shipped with this application. The generated
  // desktop fallback is relative to the process working directory and can
  // otherwise pick up a stale library from the source tree.
  await RustLib.init(externalLibrary: bundledRustLibrary());

  String dbPath;
  if (kIsWeb) {
    dbPath = 'openlogtool_rust.db';
  } else {
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      dbPath = p.join(dir.path, 'openlogtool_rust.db');
    } catch (e) {
      dbPath = 'openlogtool_rust.db';
    }
  }
  try {
    await RustApi.init(dbPath: dbPath);
  } catch (error, stackTrace) {
    AppLogger.instance.log(
      AppLogLevel.error,
      'Rust database initialization failed',
      source: 'Bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Web：把 localStorage（SharedPreferences）旧数据一次性拷贝到 IndexedDB。
  // 桌面端无需迁移，直接使用 SharedPreferences。
  // 首次启动等待迁移完成，避免 provider 先读 IndexedDB 读到默认值。
  if (kIsWeb) {
    await migrateLegacyLocalStorage(await openKeyValueStore());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppInfoProvider()..loadAppInfo()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AiRecognitionSettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(),
        ),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
        ChangeNotifierProxyProvider<ServerProvider, AccountShareProvider>(
          create: (_) => AccountShareProvider(),
          update: (_, server, previous) =>
              (previous ?? AccountShareProvider())..updateServer(server),
        ),
        ChangeNotifierProvider(create: (_) => DictionaryProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProxyProvider3<ServerProvider, SessionProvider,
            LogProvider, CollaborationProvider>(
          create: (_) => CollaborationProvider(),
          update: (_, server, sessions, logs, previous) =>
              (previous ?? CollaborationProvider())
                ..updateDependencies(server, sessions, logs),
        ),
        ChangeNotifierProxyProvider5<
            ServerProvider,
            SessionProvider,
            LogProvider,
            CollaborationProvider,
            DictionaryProvider,
            PersonalCloudProvider>(
          create: (_) => PersonalCloudProvider(),
          update: (_, server, sessions, logs, collaboration, dictionaries,
                  previous) =>
              (previous ?? PersonalCloudProvider())
                ..updateDependencies(
                  server,
                  sessions,
                  logs,
                  collaboration,
                  dictionaries,
                ),
        ),
      ],
      child: const WindowsAccessibilityCrashGuard(
        child: _ApplicationLifecycleLogger(child: MyApp()),
      ),
    ),
  );
}

class _ApplicationLifecycleLogger extends StatefulWidget {
  const _ApplicationLifecycleLogger({required this.child});

  final Widget child;

  @override
  State<_ApplicationLifecycleLogger> createState() =>
      _ApplicationLifecycleLoggerState();
}

class _ApplicationLifecycleLoggerState
    extends State<_ApplicationLifecycleLogger> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.instance.log(
      AppLogLevel.info,
      'Application UI started',
      source: 'Lifecycle',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.instance.log(
      AppLogLevel.info,
      'Lifecycle changed to ${state.name}',
      source: 'Lifecycle',
    );
    if (state == AppLifecycleState.detached) {
      unawaited(AppLogger.instance.markCleanShutdown());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = context.select<SettingsProvider,
        ({Color color, bool dark, String? fontFamily, Locale? locale})>(
      (settings) => (
        color: settings.themeColor,
        dark: settings.isDarkMode,
        fontFamily: settings.fontFamily,
        locale: settings.locale,
      ),
    );

    return MaterialApp(
      title: 'OpenLogTool',
      initialRoute: '/',
      navigatorObservers: UrlSync.navigatorObservers,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: appearance.locale,
      localeResolutionCallback: resolveAppLocale,
      theme: buildAppTheme(
        brightness: Brightness.light,
        seedColor: appearance.color,
        fontFamily: appearance.fontFamily,
      ),
      darkTheme: buildAppTheme(
        brightness: Brightness.dark,
        seedColor: appearance.color,
        fontFamily: appearance.fontFamily,
      ),
      themeMode: appearance.dark ? ThemeMode.dark : ThemeMode.light,
      home: kIsWeb && controllerTabRoute.isController
          ? WebControllerTabPage(sessionId: controllerTabRoute.sessionId)
          : const HomeScreen(),
    );
  }
}

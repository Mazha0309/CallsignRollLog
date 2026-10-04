import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/services/secure_token_store.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/widgets/settings/server_account_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'username Next focuses password and desktop Enter submits only once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = _AuthTestServer()..pending = Completer<String>();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_AuthTestApp(provider: provider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('server-login-button')));
    await tester.pumpAndSettle();
    final username = find.byKey(const Key('server-auth-username-field'));
    final password = find.byKey(const Key('server-auth-password-field'));
    await tester.enterText(username, '  BG5CRL  ');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(_authTextField(tester, password).focusNode!.hasFocus, isTrue);
    await tester.enterText(password, '  unchanged password  ');
    final oldButton = tester
        .widget<FilledButton>(
          find.byKey(const Key('server-auth-submit-button')),
        )
        .onPressed!;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // Exercise a second queued callback before the disabled UI rebuild is used.
    oldButton();
    _authTextField(tester, password).onSubmitted!('ignored');
    await tester.pump();
    expect(provider.loginCalls, 1);
    expect(provider.lastUsername, 'BG5CRL');
    expect(provider.lastPassword, '  unchanged password  ');
    expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('server-auth-submit-button')),
            )
            .onPressed,
        isNull);
    provider.pending!.complete('user-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-auth-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets(
      'phone login keeps focus and draft through provider and keyboard changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final provider = _AuthTestServer();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_AuthTestApp(provider: provider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('server-login-button')));
    await tester.pumpAndSettle();
    final username = find.byKey(const Key('server-auth-username-field'));
    final password = find.byKey(const Key('server-auth-password-field'));
    await tester.enterText(username, 'BG5CRL');
    await tester.enterText(password, 'in-progress-password');
    final userController = tester.widget<TextFormField>(username).controller;
    final passwordController =
        tester.widget<TextFormField>(password).controller;
    final passwordFocus = _authTextField(tester, password).focusNode;
    provider.emitChange();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(username).controller,
        same(userController));
    expect(tester.widget<TextFormField>(password).controller,
        same(passwordController));
    expect(passwordFocus!.hasFocus, isTrue);
    expect(userController!.text, 'BG5CRL');
    expect(passwordController!.text, 'in-progress-password');
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 640);
    await tester.pumpAndSettle();
    expect(passwordFocus.hasFocus, isTrue);
    expect(passwordController.text, 'in-progress-password');
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-auth-dialog')), findsOneWidget);
    expect(passwordController.text, 'in-progress-password');
    expect(provider.loginCalls, 0);
  });

  testWidgets('failed sign-in preserves credentials for an in-place retry',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = _AuthTestServer()..failure = 'test login failure';
    addTearDown(provider.dispose);
    await tester.pumpWidget(_AuthTestApp(provider: provider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('server-login-button')));
    await tester.pumpAndSettle();
    final username = find.byKey(const Key('server-auth-username-field'));
    final password = find.byKey(const Key('server-auth-password-field'));
    await tester.enterText(username, 'BG5CRL');
    await tester.enterText(password, 'first-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-auth-error')), findsOneWidget);
    expect(tester.widget<TextFormField>(username).controller!.text, 'BG5CRL');
    expect(tester.widget<TextFormField>(password).controller!.text,
        'first-password');
    provider.failure = null;
    await tester.enterText(password, 'second-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(provider.loginCalls, 2);
    expect(provider.lastPassword, 'second-password');
    expect(find.byKey(const Key('server-auth-dialog')), findsNothing);
  });

  for (final registration in [false, true]) {
    testWidgets(
        'changed server context blocks ${registration ? 'registration' : 'login'} credentials',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = _AuthTestServer();
      addTearDown(provider.dispose);
      await tester.pumpWidget(_AuthTestApp(provider: provider));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(
        registration ? 'server-register-button' : 'server-login-button',
      )));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('server-auth-username-field')), 'BG5CRL');
      await tester.enterText(
          find.byKey(const Key('server-auth-password-field')),
          'unchanged-password');
      if (registration) {
        await tester.enterText(
            find.byKey(const Key('server-auth-confirm-password-field')),
            'unchanged-password');
      }
      provider.revision++;
      provider.emitChange();
      await tester.pump();
      await tester.tap(find.byKey(const Key('server-auth-submit-button')));
      await tester.pumpAndSettle();
      expect(provider.loginCalls, 0);
      expect(provider.registerCalls, 0);
      expect(
          find.text(
              'The server, account or current session changed. Close this dialog and try again.'),
          findsOneWidget);
      expect(find.byKey(const Key('server-auth-dialog')), findsOneWidget);
    });
  }

  testWidgets(
      'registration Next goes to confirmation instead of submitting login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = _AuthTestServer();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_AuthTestApp(provider: provider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('server-register-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('server-auth-username-field')), 'BG5CRL');
    await tester.enterText(find.byKey(const Key('server-auth-password-field')),
        'registration-password');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final confirm = find.byKey(const Key('server-auth-confirm-password-field'));
    expect(_authTextField(tester, confirm).focusNode!.hasFocus, isTrue);
    expect(provider.registerCalls, 0);
    expect(provider.loginCalls, 0);
    await tester.enterText(confirm, 'registration-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(provider.registerCalls, 1);
    expect(provider.loginCalls, 0);
  });
  testWidgets('shows degraded token-storage keys and localized warnings',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = _StatusTokenStore(
      const TokenStorageStatus(
        backend: TokenStorageBackend.privateFileFallback,
        reason: 'keyring unavailable',
      ),
    );
    final provider = ServerProvider(
      autoLoadSettings: false,
      tokenStoreFactory: (_) => store,
    );
    await provider.setServerUrl('https://example.test');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerAccountSettings(cardPadding: 16),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const Key('token-storage-warning-privateFileFallback'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The system keyring is unavailable. Your sign-in is stored in a '
        'private file readable only by your Linux user and will move back to '
        'secure storage when a keyring becomes available.',
      ),
      findsOneWidget,
    );

    store.status.value = const TokenStorageStatus(
      backend: TokenStorageBackend.memoryOnly,
      reason: 'secure stores unavailable',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('token-storage-warning-privateFileFallback')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('token-storage-warning-memoryOnly')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Secure credential storage is unavailable. This sign-in lasts only '
        'while the app is running; you will need to sign in again after '
        'exiting.',
      ),
      findsOneWidget,
    );

    provider.dispose();
    store.status.dispose();
  });

  testWidgets(
      'restored server URL updates the field and recheck keeps the session',
      (tester) async {
    const serverUrl = 'https://example.test';
    SharedPreferences.setMockInitialValues({'server_url': serverUrl});
    final restoredSession = AuthSessionDto(
      accessToken: 'restored-access',
      accessTokenExpiresIn: 900,
      refreshToken: 'restored-refresh',
      refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
      user: const ApiUserDto(
        id: 'user-1',
        username: 'alice',
        role: 'user',
      ),
    );
    Uri? checkedUri;
    final client = MockClient((request) async {
      checkedUri = request.url;
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/server-info');
      return _jsonResponse({
        'serverInstanceId': 'server-1',
        'protocolMin': 1,
        'protocolMax': 1,
        'features': <String>[],
        'serverTime': '2026-07-13T00:00:00Z',
        'environment': 'test',
      });
    });
    final provider = ServerProvider(
      autoLoadSettings: false,
      tokenStoreFactory: (_) => MemoryTokenStore(restoredSession),
      apiFactory: ({
        required baseUri,
        required tokenStore,
        required deviceId,
        required onAuthInvalidated,
      }) =>
          ServerApi(
        baseUri: baseUri,
        tokenStore: tokenStore,
        deviceId: deviceId,
        onAuthInvalidated: onAuthInvalidated,
        httpClient: client,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerAccountSettings(cardPadding: 16),
            ),
          ),
        ),
      ),
    );

    TextField serverUrlField() => tester.widget<TextField>(
          find.byKey(const Key('server-url-field')),
        );

    expect(serverUrlField().controller!.text, isEmpty);

    await provider.loadSettings();
    await tester.pump();

    expect(serverUrlField().controller!.text, serverUrl);
    expect(provider.isLoggedIn, isTrue);
    expect(find.text('alice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('server-check-button')));
    await _pumpUntil(tester, () => provider.serverInfo != null);

    expect(checkedUri, Uri.parse('$serverUrl/api/v1/server-info'));
    expect(provider.serverUrl, serverUrl);
    expect(provider.isLoggedIn, isTrue);
    expect(find.text('alice'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      'https://pending-edit.test',
    );
    await provider.setDeviceId('device-1');
    await tester.pump();

    expect(serverUrlField().controller!.text, 'https://pending-edit.test');

    provider.dispose();
  });

  testWidgets('temporary-password sign-in requires setting a new password',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/server-info':
          return _jsonResponse({
            'serverInstanceId': 'server-1',
            'protocolMin': 1,
            'protocolMax': 1,
            'features': <String>[],
            'serverTime': '2026-07-13T00:00:00Z',
            'environment': 'test',
          });
        case 'POST /api/v1/auth/login':
          return _jsonResponse({
            'error': {
              'code': 'PASSWORD_CHANGE_REQUIRED',
              'message': 'Temporary password must be changed',
              'requestId': 'request-1',
              'details': {
                'passwordChangeToken': 'change-token',
                'passwordChangeTokenExpiresIn': 300,
                'user': {
                  'id': 'user-1',
                  'username': 'alice',
                  'role': 'user',
                },
              },
            },
          }, 403);
        case 'POST /api/v1/auth/complete-password-change':
          return _jsonResponse({
            'accessToken': 'access-token',
            'accessTokenExpiresIn': 900,
            'refreshToken': 'refresh-token',
            'refreshTokenExpiresAt': '2026-08-13T00:00:00Z',
            'user': {
              'id': 'user-1',
              'username': 'alice',
              'role': 'user',
            },
          });
        default:
          fail('Unexpected request: ${request.method} ${request.url}');
      }
    });
    final provider = ServerProvider(
      autoLoadSettings: false,
      tokenStoreFactory: (_) => MemoryTokenStore(),
      apiFactory: ({
        required baseUri,
        required tokenStore,
        required deviceId,
        required onAuthInvalidated,
      }) =>
          ServerApi(
        baseUri: baseUri,
        tokenStore: tokenStore,
        deviceId: deviceId,
        onAuthInvalidated: onAuthInvalidated,
        httpClient: client,
      ),
    );
    await provider.setServerUrl('https://example.test');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerAccountSettings(cardPadding: 16),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('server-login-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('server-auth-submit-button')),
    );
    await tester.enterText(
      find.byKey(const Key('server-auth-username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const Key('server-auth-password-field')),
      'temporary-password',
    );
    await tester.tap(find.byKey(const Key('server-auth-submit-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('required-password-change-dialog')),
    );

    expect(
      find.text('Temporary password must be changed'),
      findsOneWidget,
    );
    expect(provider.isLoggedIn, isFalse);

    await tester.enterText(
      find.byKey(const Key('required-new-password-field')),
      'new-secure-password',
    );
    await tester.enterText(
      find.byKey(const Key('required-confirm-password-field')),
      'new-secure-password',
    );
    await tester.tap(
      find.byKey(const Key('complete-password-change-button')),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('account-username')));

    expect(
        find.byKey(const Key('required-password-change-dialog')), findsNothing);
    expect(find.byKey(const Key('account-username')), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(provider.isLoggedIn, isTrue);
  });

  testWidgets('sign-in keeps legacy non-empty credential compatibility',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var loginRequested = false;
    final client = MockClient((request) async {
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/server-info':
          return _jsonResponse({
            'serverInstanceId': 'server-1',
            'protocolMin': 1,
            'protocolMax': 1,
            'features': <String>[],
            'serverTime': '2026-07-13T00:00:00Z',
            'environment': 'test',
          });
        case 'POST /api/v1/auth/login':
          loginRequested = true;
          expect(jsonDecode(request.body), {
            'username': 'x',
            'password': 'short',
          });
          return _jsonResponse({
            'accessToken': 'access-token',
            'accessTokenExpiresIn': 900,
            'refreshToken': 'refresh-token',
            'refreshTokenExpiresAt': '2026-08-13T00:00:00Z',
            'user': {
              'id': 'user-1',
              'username': 'x',
              'role': 'user',
            },
          });
        default:
          fail('Unexpected request: ${request.method} ${request.url}');
      }
    });
    final provider = ServerProvider(
      autoLoadSettings: false,
      tokenStoreFactory: (_) => MemoryTokenStore(),
      apiFactory: ({
        required baseUri,
        required tokenStore,
        required deviceId,
        required onAuthInvalidated,
      }) =>
          ServerApi(
        baseUri: baseUri,
        tokenStore: tokenStore,
        deviceId: deviceId,
        onAuthInvalidated: onAuthInvalidated,
        httpClient: client,
      ),
    );
    await provider.setServerUrl('https://example.test');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ServerProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServerAccountSettings(cardPadding: 16),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('server-login-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('server-auth-submit-button')),
    );
    await tester.enterText(
      find.byKey(const Key('server-auth-username-field')),
      'x',
    );
    await tester.enterText(
      find.byKey(const Key('server-auth-password-field')),
      'short',
    );
    await tester.tap(find.byKey(const Key('server-auth-submit-button')));
    await _pumpUntilFound(tester, find.byKey(const Key('account-username')));

    expect(loginRequested, isTrue);
    expect(provider.isLoggedIn, isTrue);
  });
}

class _AuthTestServer extends ServerProvider {
  _AuthTestServer() : super(autoLoadSettings: false);
  int loginCalls = 0;
  int registerCalls = 0;
  String? lastUsername;
  String? lastPassword;
  String? failure;
  Completer<String>? pending;
  int revision = 0;

  @override
  int get contextRevision => revision;

  void emitChange() => notifyListeners();

  @override
  Future<String> login(String username, String password) async {
    loginCalls++;
    revision++;
    lastUsername = username;
    lastPassword = password;
    if (failure case final String reason) throw StateError(reason);
    final result = pending == null ? 'user-1' : await pending!.future;
    revision++;
    return result;
  }

  @override
  Future<String> register(String username, String password) async {
    registerCalls++;
    revision++;
    lastUsername = username;
    lastPassword = password;
    return 'user-1';
  }
}

class _AuthTestApp extends StatelessWidget {
  const _AuthTestApp({required this.provider});
  final ServerProvider provider;

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<ServerProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: SingleChildScrollView(
            child: ServerAccountSettings(cardPadding: 16),
          )),
        ),
      );
}

TextField _authTextField(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)));

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 40; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('Timed out waiting for condition');
}

http.Response _jsonResponse(Object? body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

final class _StatusTokenStore implements TokenStore, TokenStorageStatusSource {
  _StatusTokenStore(TokenStorageStatus initial)
      : status = ValueNotifier(initial);

  final ValueNotifier<TokenStorageStatus> status;
  AuthSessionDto? session;

  @override
  ValueListenable<TokenStorageStatus> get storageStatus => status;

  @override
  Future<AuthSessionDto?> read() async => session;

  @override
  Future<void> write(AuthSessionDto session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

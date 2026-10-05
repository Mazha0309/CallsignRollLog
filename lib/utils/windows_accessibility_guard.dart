import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _windowsAccessibilityOverride =
    'OPENLOGTOOL_ENABLE_WINDOWS_ACCESSIBILITY';

/// Returns whether the Windows accessibility-tree compatibility guard should
/// be enabled for this process.
///
/// Flutter's Windows accessibility bridge faults while it prepares a semantics
/// update that reparents a node whose current tree entry has no parent.
/// `AccessibilityBridge::CreateRemoveReparentedNodesUpdate()` dereferences that
/// null parent behind an `assert`, so only release builds crash; the access
/// violation surfaces as `flutter_windows.dll` / `0xc0000005` in the Windows
/// event log and terminates the process before Dart can report it.
///
/// The defect affects every Windows release, Windows 11 included, and is still
/// unfixed upstream (flutter/flutter#175041, #186886, #190357). Until a fixed
/// engine ships, the guard collapses the semantics tree to a single childless
/// node so the bridge has nothing to reparent. Setting
/// `OPENLOGTOOL_ENABLE_WINDOWS_ACCESSIBILITY=1` explicitly opts back into the
/// full semantics tree for screen-reader users.
@visibleForTesting
bool shouldGuardWindowsAccessibility({
  String? operatingSystem,
  Map<String, String>? environment,
}) {
  // dart:io's Platform getters throw on Web. Callers may still inject a
  // synthetic Windows platform in tests, so only short-circuit the real Web
  // runtime when no override was supplied.
  if (kIsWeb && operatingSystem == null) return false;
  final os = operatingSystem ?? Platform.operatingSystem;
  if (os != 'windows') return false;

  final processEnvironment = environment ?? Platform.environment;
  return processEnvironment[_windowsAccessibilityOverride] != '1';
}

bool? _cachedGuardDecision;

/// Whether the Windows compatibility guard is in effect for this process.
///
/// Cached so the `Platform.environment` lookup happens once rather than on
/// every rebuild of the root widget.
bool windowsAccessibilityGuardActive() =>
    _cachedGuardDecision ??= shouldGuardWindowsAccessibility();

/// One-line startup diagnostic describing the guard state, or null when the
/// guard does not apply (Web or a non-Windows OS).
///
/// Recorded in `app.log` so a later native crash in `flutter_windows.dll` can
/// be correlated with whether the mitigation was active.
String? windowsAccessibilityGuardStatus() {
  if (kIsWeb || Platform.operatingSystem != 'windows') return null;
  return windowsAccessibilityGuardActive()
      ? 'Windows accessibility guard ACTIVE: semantics tree collapsed to a '
          'single childless node to avoid the engine reparent crash '
          '(flutter_windows.dll+0x3A9FA).'
      : 'Windows accessibility guard INACTIVE: '
          'OPENLOGTOOL_ENABLE_WINDOWS_ACCESSIBILITY=1 exposes the full '
          'semantics tree, so the engine reparent crash is reachable again.';
}

/// Prevents Windows UI Automation clients from activating Flutter's unstable,
/// rapidly changing semantics tree while the engine's reparent crash is
/// unfixed. See [shouldGuardWindowsAccessibility].
class WindowsAccessibilityCrashGuard extends StatelessWidget {
  const WindowsAccessibilityCrashGuard({
    required this.child,
    this.enabled,
    super.key,
  });

  final Widget child;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    if (!(enabled ?? windowsAccessibilityGuardActive())) return child;
    return ExcludeSemantics(child: child);
  }
}

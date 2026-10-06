import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:path/path.dart' as p;

ExternalLibrary bundledRustLibrary() {
  if (Platform.isAndroid) {
    return ExternalLibrary.open('libopenlogtool_core.so');
  }

  if (Platform.isIOS) {
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  }

  final executableDirectory = p.dirname(Platform.resolvedExecutable);
  final libraryPath = switch (Platform.operatingSystem) {
    'linux' => p.join(
        executableDirectory,
        'lib',
        'libopenlogtool_core.so',
      ),
    'windows' => p.join(executableDirectory, 'openlogtool_core.dll'),
    'macos' => p.normalize(
        p.join(
          executableDirectory,
          '..',
          'Frameworks',
          'libopenlogtool_core.dylib',
        ),
      ),
    _ => throw UnsupportedError(
        'Callsign Roll Log does not bundle a Rust core for '
        '${Platform.operatingSystem}.',
      ),
  };
  if (!File(libraryPath).existsSync()) {
    throw StateError('Bundled Rust core is missing: $libraryPath');
  }
  return ExternalLibrary.open(libraryPath);
}

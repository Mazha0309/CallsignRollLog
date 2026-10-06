import 'package:flutter/material.dart';
import 'package:openlogtool/config/app_config.dart';

class AppInfoProvider extends ChangeNotifier {
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  String get appName => 'Callsign Roll Log';
  String get version => AppConfig.versionName;
  String get buildNumber => AppConfig.buildNumber;
  String get commitHash => AppConfig.commitHash;
  String get fullVersion => AppConfig.fullVersion;

  Future<void> loadAppInfo() async {
    _isLoaded = true;
    notifyListeners();
  }
}

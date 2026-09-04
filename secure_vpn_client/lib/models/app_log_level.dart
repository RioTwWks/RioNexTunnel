enum AppLogLevel { info, debug;
  String get storageName => name;
  static AppLogLevel fromStorage(String? v) => v?.toLowerCase()=='debug'?AppLogLevel.debug:AppLogLevel.info;
  bool includesDebug() => this == AppLogLevel.debug;
}

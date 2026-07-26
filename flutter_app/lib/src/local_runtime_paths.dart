class LocalRuntimePaths {
  LocalRuntimePaths._({
    required this.homeDirectory,
    required this.runtimeHome,
    required this.dataDirectory,
    required this.envFile,
    required this.separator,
  });

  factory LocalRuntimePaths.fromEnvironment(
    Map<String, String> environment, {
    required bool isWindows,
  }) {
    final separator = isWindows ? r'\' : '/';
    final homeKey = isWindows ? 'USERPROFILE' : 'HOME';
    final homeDirectory = (environment[homeKey] ?? '').trim();
    if (homeDirectory.isEmpty) {
      throw StateError('$homeKey is required to locate NeoAgent runtime data.');
    }

    final configuredRuntimeHome = (environment['NEOAGENT_HOME'] ?? '').trim();
    final runtimeHome = configuredRuntimeHome.isNotEmpty
        ? configuredRuntimeHome
        : _join(homeDirectory, '.neoagent', separator);
    final configuredDataDirectory = (environment['NEOAGENT_DATA_DIR'] ?? '')
        .trim();
    final dataDirectory = configuredDataDirectory.isNotEmpty
        ? configuredDataDirectory
        : _join(runtimeHome, 'data', separator);
    final configuredEnvFile = (environment['NEOAGENT_ENV_FILE'] ?? '').trim();
    final envFile = configuredEnvFile.isNotEmpty
        ? configuredEnvFile
        : _join(runtimeHome, '.env', separator);

    return LocalRuntimePaths._(
      homeDirectory: homeDirectory,
      runtimeHome: runtimeHome,
      dataDirectory: dataDirectory,
      envFile: envFile,
      separator: separator,
    );
  }

  final String homeDirectory;
  final String runtimeHome;
  final String dataDirectory;
  final String envFile;
  final String separator;

  String get logDirectory => _join(dataDirectory, 'logs', separator);
  String get logFile => _join(logDirectory, 'neoagent.log', separator);
  String get pidFile => _join(dataDirectory, 'neoagent.pid', separator);

  static String _join(String parent, String child, String separator) {
    if (parent.endsWith('/') || parent.endsWith(r'\')) {
      return '$parent$child';
    }
    return '$parent$separator$child';
  }
}

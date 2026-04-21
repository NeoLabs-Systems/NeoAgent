import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'oauth_launcher.dart';

const String appUpdaterGithubOwner = String.fromEnvironment(
  'NEOAGENT_UPDATES_GITHUB_OWNER',
  defaultValue: 'NeoLabs-Systems',
);
const String appUpdaterGithubRepo = String.fromEnvironment(
  'NEOAGENT_UPDATES_GITHUB_REPO',
  defaultValue: 'NeoAgent',
);
const String appUpdaterGithubToken = String.fromEnvironment(
  'NEOAGENT_UPDATES_GITHUB_TOKEN',
);

bool get appUpdaterConfigured =>
    appUpdaterGithubOwner.trim().isNotEmpty &&
    appUpdaterGithubRepo.trim().isNotEmpty;

class AppUpdateAsset {
  const AppUpdateAsset({
    required this.name,
    required this.downloadUrl,
    this.contentType,
    this.sizeBytes,
  });

  final String name;
  final String downloadUrl;
  final String? contentType;
  final int? sizeBytes;

  String get sizeLabel {
    final size = sizeBytes;
    if (size == null || size <= 0) {
      return 'Unknown size';
    }
    if (size >= 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.title,
    required this.body,
    required this.channel,
    required this.htmlUrl,
    required this.publishedAt,
    required this.asset,
    required this.prerelease,
  });

  final String version;
  final String title;
  final String body;
  final String channel;
  final String htmlUrl;
  final DateTime? publishedAt;
  final AppUpdateAsset asset;
  final bool prerelease;

  String get channelLabel => channel == 'beta' ? 'Beta' : 'Stable';

  String get publishedLabel {
    final date = publishedAt;
    if (date == null) {
      return 'Unknown publish time';
    }
    final month = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    }[date.month];
    return '$month ${date.day}, ${date.year}';
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.channel,
    required this.updateAvailable,
    this.release,
    this.errorMessage,
  });

  final String currentVersion;
  final String channel;
  final bool updateAvailable;
  final AppReleaseInfo? release;
  final String? errorMessage;
}

class AppReleaseUpdater {
  AppReleaseUpdater({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void dispose() {
    _client.close();
  }

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    if (build.isEmpty) {
      return version;
    }
    return '$version+$build';
  }

  Future<AppUpdateCheckResult> checkForUpdate({
    required String channel,
    bool launcherMode = false,
  }) async {
    final normalizedChannel = channel.trim().toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    final installedVersion = await currentVersion();

    if (!appUpdaterConfigured) {
      return AppUpdateCheckResult(
        currentVersion: installedVersion,
        channel: normalizedChannel,
        updateAvailable: false,
        errorMessage: 'App updates are not configured for this build.',
      );
    }

    try {
      final response = await _client.get(
        Uri.https(
          'api.github.com',
          '/repos/$appUpdaterGithubOwner/$appUpdaterGithubRepo/releases',
          <String, String>{'per_page': '20'},
        ),
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'NeoAgent Flutter Updater',
          if (appUpdaterGithubToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${appUpdaterGithubToken.trim()}',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateCheckResult(
          currentVersion: installedVersion,
          channel: normalizedChannel,
          updateAvailable: false,
          errorMessage:
              'GitHub release check failed with HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return AppUpdateCheckResult(
          currentVersion: installedVersion,
          channel: normalizedChannel,
          updateAvailable: false,
          errorMessage: 'GitHub release payload was not a release list.',
        );
      }

      final release = _selectRelease(
        decoded,
        normalizedChannel,
        launcherMode: launcherMode,
      );
      if (release == null) {
        return AppUpdateCheckResult(
          currentVersion: installedVersion,
          channel: normalizedChannel,
          updateAvailable: false,
          errorMessage:
              'No ${normalizedChannel == 'beta' ? 'beta' : 'stable'} release asset matched this platform.',
        );
      }

      final newer = _isNewer(release.version, installedVersion);
      return AppUpdateCheckResult(
        currentVersion: installedVersion,
        channel: normalizedChannel,
        updateAvailable: newer,
        release: release,
      );
    } catch (error) {
      return AppUpdateCheckResult(
        currentVersion: installedVersion,
        channel: normalizedChannel,
        updateAvailable: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<OAuthLaunchResult> openReleaseAsset({
    required OAuthLauncher launcher,
    required AppReleaseInfo release,
  }) {
    return launcher.openExternal(
      url: release.asset.downloadUrl,
      label: 'app_update_${release.channel}',
    );
  }

  AppReleaseInfo? _selectRelease(
    List<dynamic> releases,
    String channel, {
    required bool launcherMode,
  }) {
    for (final candidate in releases) {
      if (candidate is! Map) {
        continue;
      }
      final prerelease = candidate['prerelease'] == true;
      final draft = candidate['draft'] == true;
      if (draft) {
        continue;
      }
      if (channel == 'stable' && prerelease) {
        continue;
      }
      final release = _parseRelease(
        Map<dynamic, dynamic>.from(candidate),
        launcherMode: launcherMode,
      );
      if (release != null) {
        return release;
      }
    }
    return null;
  }

  AppReleaseInfo? _parseRelease(
    Map<dynamic, dynamic> json, {
    required bool launcherMode,
  }) {
    final assets = json['assets'];
    if (assets is! List) {
      return null;
    }
    final asset = _pickAsset(assets, launcherMode: launcherMode);
    if (asset == null) {
      return null;
    }
    final rawTag = json['tag_name']?.toString().trim();
    final version = _normalizeVersionLabel(
      rawTag?.isNotEmpty == true ? rawTag! : json['name']?.toString() ?? '',
    );
    if (version.isEmpty) {
      return null;
    }
    return AppReleaseInfo(
      version: version,
      title: json['name']?.toString().trim().isNotEmpty == true
          ? json['name']!.toString().trim()
          : version,
      body: json['body']?.toString() ?? '',
      channel: json['prerelease'] == true ? 'beta' : 'stable',
      htmlUrl: json['html_url']?.toString() ?? '',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      asset: asset,
      prerelease: json['prerelease'] == true,
    );
  }

  AppUpdateAsset? _pickAsset(
    List<dynamic> assets, {
    required bool launcherMode,
  }) {
    final candidates = assets
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (asset) => AppUpdateAsset(
            name: asset['name']?.toString() ?? '',
            downloadUrl: asset['browser_download_url']?.toString() ?? '',
            contentType: asset['content_type']?.toString(),
            sizeBytes: asset['size'] is num
                ? (asset['size'] as num).toInt()
                : null,
          ),
        )
        .where(
          (asset) =>
              asset.name.trim().isNotEmpty &&
              asset.downloadUrl.trim().isNotEmpty,
        )
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    final matchers = _assetMatchersForCurrentPlatform(
      launcherMode: launcherMode,
    );
    for (final matcher in matchers) {
      for (final asset in candidates) {
        if (matcher(asset.name.toLowerCase())) {
          return asset;
        }
      }
    }
    return null;
  }

  List<bool Function(String)> _assetMatchersForCurrentPlatform({
    required bool launcherMode,
  }) {
    if (kIsWeb) {
      return const <bool Function(String)>[];
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return launcherMode
            ? <bool Function(String)>[
                (name) => name.endsWith('.apk') && name.contains('launcher'),
              ]
            : <bool Function(String)>[
                (name) => name.endsWith('.apk') && !name.contains('launcher'),
                (name) => name.endsWith('.apk'),
              ];
      case TargetPlatform.macOS:
        return <bool Function(String)>[
          (name) => name.endsWith('.dmg'),
          (name) => name.endsWith('.pkg'),
          (name) => name.endsWith('.zip'),
        ];
      case TargetPlatform.windows:
        return <bool Function(String)>[
          (name) => name.endsWith('.exe'),
          (name) => name.endsWith('.msix'),
          (name) => name.endsWith('.msi'),
          (name) => name.endsWith('.zip'),
        ];
      case TargetPlatform.linux:
        return <bool Function(String)>[
          (name) => name.endsWith('.deb'),
          (name) => name.endsWith('.appimage'),
          (name) => name.endsWith('.rpm'),
          (name) => name.endsWith('.tar.gz'),
          (name) => name.endsWith('.zip'),
        ];
      case TargetPlatform.iOS:
        return const <bool Function(String)>[];
      case TargetPlatform.fuchsia:
        return const <bool Function(String)>[];
    }
  }

  String _normalizeVersionLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceFirst(RegExp(r'^[vV]'), '');
  }

  bool _isNewer(String candidate, String installed) {
    final candidateVersion = _ParsedVersion.tryParse(candidate);
    final installedVersion = _ParsedVersion.tryParse(installed);
    if (candidateVersion == null || installedVersion == null) {
      return _normalizeVersionLabel(candidate) !=
          _normalizeVersionLabel(installed);
    }
    return candidateVersion.compareTo(installedVersion) > 0;
  }
}

class _ParsedVersion implements Comparable<_ParsedVersion> {
  const _ParsedVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
    required this.prereleaseLabel,
    required this.prereleaseNumber,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;
  final String? prereleaseLabel;
  final int? prereleaseNumber;

  static _ParsedVersion? tryParse(String raw) {
    final normalized = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:-([A-Za-z]+)(?:\.(\d+))?)?(?:\+(\d+))?$',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return _ParsedVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prereleaseLabel: match.group(4)?.toLowerCase(),
      prereleaseNumber: match.group(5) == null
          ? null
          : int.parse(match.group(5)!),
      build: match.group(6) == null ? 0 : int.parse(match.group(6)!),
    );
  }

  @override
  int compareTo(_ParsedVersion other) {
    final core = _compareInts(major, other.major) != 0
        ? _compareInts(major, other.major)
        : _compareInts(minor, other.minor) != 0
        ? _compareInts(minor, other.minor)
        : _compareInts(patch, other.patch);
    if (core != 0) {
      return core;
    }
    final prerelease = _comparePrerelease(this, other);
    if (prerelease != 0) {
      return prerelease;
    }
    return _compareInts(build, other.build);
  }

  static int _compareInts(int left, int right) {
    if (left < right) {
      return -1;
    }
    if (left > right) {
      return 1;
    }
    return 0;
  }

  static int _comparePrerelease(_ParsedVersion left, _ParsedVersion right) {
    final leftLabel = left.prereleaseLabel;
    final rightLabel = right.prereleaseLabel;
    if (leftLabel == null && rightLabel == null) {
      return 0;
    }
    if (leftLabel == null) {
      return 1;
    }
    if (rightLabel == null) {
      return -1;
    }
    final labelCompare = leftLabel.compareTo(rightLabel);
    if (labelCompare != 0) {
      return labelCompare;
    }
    return _compareInts(
      left.prereleaseNumber ?? 0,
      right.prereleaseNumber ?? 0,
    );
  }
}

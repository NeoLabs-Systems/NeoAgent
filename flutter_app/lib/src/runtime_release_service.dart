import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'app_release_updater.dart';
import 'local_backend_installer_models.dart';

const String runtimeSigningPublicKey = String.fromEnvironment(
  'NEOAGENT_RUNTIME_PUBLIC_KEY',
);
const String runtimeReleaseChannel = String.fromEnvironment(
  'NEOAGENT_RELEASE_CHANNEL',
  defaultValue: 'stable',
);

typedef RuntimeDownloadProgress = void Function(double progress);
typedef RuntimeCancellationCheck = void Function();

class PreparedRuntimeRelease {
  const PreparedRuntimeRelease({
    required this.manifest,
    required this.artifact,
    required this.downloadUrl,
  });

  final RuntimeArtifactManifest manifest;
  final RuntimeArtifact artifact;
  final String downloadUrl;
}

class RuntimeReleaseService {
  RuntimeReleaseService({
    required http.Client client,
    required RuntimeDownloadProgress onDownloadProgress,
    required RuntimeCancellationCheck checkCancelled,
  }) : _client = client,
       _onDownloadProgress = onDownloadProgress,
       _checkCancelled = checkCancelled;

  static const int _metadataLimitBytes = 2 * 1024 * 1024;
  static const int _signatureLimitBytes = 8192;

  final http.Client _client;
  final RuntimeDownloadProgress _onDownloadProgress;
  final RuntimeCancellationCheck _checkCancelled;

  Map<String, String> get _headers => <String, String>{
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'NeoAgent Desktop Installer',
    if (appUpdaterGithubToken.trim().isNotEmpty)
      'Authorization': 'Bearer ${appUpdaterGithubToken.trim()}',
  };

  Future<PreparedRuntimeRelease> prepare({
    required String platform,
    required String architecture,
  }) async {
    final release = await _resolveRelease();
    _checkCancelled();
    final manifestBytes = await _downloadBytes(
      release.manifestUrl,
      maxBytes: _metadataLimitBytes,
    );
    final signatureText = utf8
        .decode(
          await _downloadBytes(
            release.signatureUrl,
            maxBytes: _signatureLimitBytes,
          ),
        )
        .trim();
    await verifyRuntimeManifestSignatureData(
      manifestBytes: manifestBytes,
      signatureBase64: signatureText,
      publicKeyBase64: runtimeSigningPublicKey,
    );
    final decoded = jsonDecode(utf8.decode(manifestBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid NeoAgent runtime manifest.');
    }
    final manifest = RuntimeArtifactManifest.fromJson(decoded);
    final artifact = manifest.select(
      platform: platform,
      architecture: architecture,
    );
    final downloadUrl = release.assetUrls[artifact.assetName];
    if (downloadUrl == null) {
      throw const LocalBackendInstallerException(
        'SETUP_RUNTIME_ASSET_MISSING',
        'The matching NeoAgent runtime is missing from this release.',
      );
    }
    return PreparedRuntimeRelease(
      manifest: manifest,
      artifact: artifact,
      downloadUrl: downloadUrl,
    );
  }

  Future<void> downloadArtifact(
    PreparedRuntimeRelease release,
    File target,
  ) async {
    final request = http.Request('GET', Uri.parse(release.downloadUrl));
    request.headers.addAll(_headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const LocalBackendInstallerException(
        'SETUP_DOWNLOAD_FAILED',
        'The NeoAgent backend runtime could not be downloaded.',
      );
    }
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        _checkCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (received > release.artifact.sizeBytes) {
          throw const LocalBackendInstallerException(
            'SETUP_DOWNLOAD_INCOMPLETE',
            'The NeoAgent backend download did not match its manifest.',
          );
        }
        _onDownloadProgress(
          (received / release.artifact.sizeBytes).clamp(0, 1),
        );
      }
    } finally {
      await sink.close();
    }
    if (received != release.artifact.sizeBytes) {
      throw const LocalBackendInstallerException(
        'SETUP_DOWNLOAD_INCOMPLETE',
        'The NeoAgent backend download was incomplete.',
      );
    }
  }

  Future<_RuntimeRelease> _resolveRelease() async {
    final releasesUrl = Uri.https(
      'api.github.com',
      '/repos/$appUpdaterGithubOwner/$appUpdaterGithubRepo/releases',
      const <String, String>{'per_page': '20'},
    ).toString();
    final responseBytes = await _downloadBytes(
      releasesUrl,
      maxBytes: _metadataLimitBytes,
      errorCode: 'SETUP_RELEASE_LOOKUP_FAILED',
      errorMessage: 'NeoAgent could not check the available backend runtime.',
    );
    final decoded = jsonDecode(utf8.decode(responseBytes));
    if (decoded is! List) {
      throw const LocalBackendInstallerException(
        'SETUP_RELEASE_INVALID',
        'The NeoAgent release service returned invalid data.',
      );
    }
    for (final rawRelease in decoded.whereType<Map>()) {
      if (rawRelease['draft'] == true) continue;
      if (runtimeReleaseChannel.trim().toLowerCase() != 'beta' &&
          rawRelease['prerelease'] == true) {
        continue;
      }
      final assets = rawRelease['assets'];
      if (assets is! List) continue;
      final assetUrls = <String, String>{};
      for (final rawAsset in assets.whereType<Map>()) {
        final name = rawAsset['name']?.toString().trim() ?? '';
        final url = rawAsset['browser_download_url']?.toString().trim() ?? '';
        if (name.isNotEmpty && url.isNotEmpty) assetUrls[name] = url;
      }
      String? manifestName;
      for (final name in assetUrls.keys) {
        if (name.startsWith('neoagent-runtime-manifest-') &&
            name.endsWith('.json')) {
          manifestName = name;
          break;
        }
      }
      if (manifestName == null) continue;
      final signatureUrl = assetUrls['$manifestName.sig'];
      if (signatureUrl == null) continue;
      return _RuntimeRelease(
        manifestUrl: assetUrls[manifestName]!,
        signatureUrl: signatureUrl,
        assetUrls: assetUrls,
      );
    }
    throw const LocalBackendInstallerException(
      'SETUP_RUNTIME_NOT_PUBLISHED',
      'No verified NeoAgent backend runtime is available yet.',
    );
  }

  Future<List<int>> _downloadBytes(
    String url, {
    required int maxBytes,
    String errorCode = 'SETUP_DOWNLOAD_FAILED',
    String errorMessage =
        'A required NeoAgent setup file could not be downloaded.',
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LocalBackendInstallerException(errorCode, errorMessage);
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      _checkCancelled();
      if (bytes.length + chunk.length > maxBytes) {
        throw const LocalBackendInstallerException(
          'SETUP_DOWNLOAD_TOO_LARGE',
          'A NeoAgent setup metadata file exceeded its safe size limit.',
          retryable: false,
        );
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }
}

Future<void> verifyRuntimeManifestSignatureData({
  required List<int> manifestBytes,
  required String signatureBase64,
  required String publicKeyBase64,
}) async {
  if (publicKeyBase64.trim().isEmpty) {
    throw const LocalBackendInstallerException(
      'SETUP_TRUST_NOT_CONFIGURED',
      'This NeoAgent build is not configured to verify backend runtimes.',
      retryable: false,
    );
  }
  try {
    final publicKey = SimplePublicKey(
      base64Decode(publicKeyBase64.trim()),
      type: KeyPairType.ed25519,
    );
    final signature = Signature(
      base64Decode(signatureBase64.trim()),
      publicKey: publicKey,
    );
    final valid = await Ed25519().verify(manifestBytes, signature: signature);
    if (!valid) {
      throw const LocalBackendInstallerException(
        'SETUP_MANIFEST_SIGNATURE_INVALID',
        'The NeoAgent runtime manifest did not pass signature verification.',
        retryable: false,
      );
    }
  } on LocalBackendInstallerException {
    rethrow;
  } on Object {
    throw const LocalBackendInstallerException(
      'SETUP_MANIFEST_SIGNATURE_INVALID',
      'The NeoAgent runtime manifest signature is invalid.',
      retryable: false,
    );
  }
}

class _RuntimeRelease {
  const _RuntimeRelease({
    required this.manifestUrl,
    required this.signatureUrl,
    required this.assetUrls,
  });

  final String manifestUrl;
  final String signatureUrl;
  final Map<String, String> assetUrls;
}

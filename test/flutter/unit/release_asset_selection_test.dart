import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/app_release_updater.dart';

/// The asset names a NeoAgent release actually publishes.
const List<String> releaseAssets = <String>[
  'neoagent-windows-arm64-setup-3.4.8.exe',
  'neoagent-windows-x64-setup-3.4.8.exe',
  'neoagent-macos-arm64-3.4.8.dmg',
  'neoagent-macos-x64-3.4.8.dmg',
  'neoagent-linux-amd64-3.4.8.deb',
  'neoagent-linux-x86_64-3.4.8.AppImage',
  'neoagent-cli-windows-x64-3.4.8.exe',
  'neoagent-cli-macos-arm64-3.4.8',
  'neoagent-runtime-windows-x64-3.4.8.zip',
  'neoagent-runtime-macos-arm64-3.4.8.zip',
  'neoagent-runtime-manifest-3.4.8.json',
  'neoagent-runtime-manifest-3.4.8.json.sig',
  'neoagent-runtime-metadata-macos-arm64.json',
  'neoagent-3.4.8.apk',
  'neoagent-launcher-3.4.8.apk',
];

List<AppUpdateAsset> assets([List<String> names = releaseAssets]) => names
    .map(
      (name) =>
          AppUpdateAsset(name: name, downloadUrl: 'https://example.test/$name'),
    )
    .toList();

final List<bool Function(String)> windowsMatchers = <bool Function(String)>[
  (name) => name.endsWith('.exe'),
  (name) => name.endsWith('.msix'),
  (name) => name.endsWith('.zip'),
];

final List<bool Function(String)> macosMatchers = <bool Function(String)>[
  (name) => name.endsWith('.dmg'),
  (name) => name.endsWith('.zip'),
];

void main() {
  test('an x64 machine is never offered the arm64 build', () {
    expect(
      selectReleaseAsset(
        assets(),
        matchers: macosMatchers,
        architecture: 'x64',
      )?.name,
      'neoagent-macos-x64-3.4.8.dmg',
    );
    expect(
      selectReleaseAsset(
        assets(),
        matchers: windowsMatchers,
        architecture: 'x64',
      )?.name,
      'neoagent-windows-x64-setup-3.4.8.exe',
    );
  });

  test('an arm64 machine gets the arm64 build', () {
    expect(
      selectReleaseAsset(
        assets(),
        matchers: macosMatchers,
        architecture: 'arm64',
      )?.name,
      'neoagent-macos-arm64-3.4.8.dmg',
    );
    expect(
      selectReleaseAsset(
        assets(),
        matchers: windowsMatchers,
        architecture: 'arm64',
      )?.name,
      'neoagent-windows-arm64-setup-3.4.8.exe',
    );
  });

  test('the standalone CLI is never mistaken for the app', () {
    final withoutInstaller = releaseAssets
        .where((name) => !name.contains('windows-x64-setup'))
        .toList();

    expect(
      selectReleaseAsset(
        assets(withoutInstaller),
        matchers: windowsMatchers,
        architecture: 'x64',
      ),
      isNull,
    );
  });

  test('a signed runtime package is never mistaken for the app', () {
    expect(
      selectReleaseAsset(
        assets(<String>['neoagent-runtime-windows-x64-3.4.8.zip']),
        matchers: windowsMatchers,
        architecture: 'x64',
      ),
      isNull,
    );
  });

  test('an untagged universal asset stays eligible', () {
    expect(
      selectReleaseAsset(
        assets(<String>['neoagent-setup-3.4.8.exe']),
        matchers: windowsMatchers,
        architecture: 'arm64',
      )?.name,
      'neoagent-setup-3.4.8.exe',
    );
  });

  test('an architecture-tagged asset wins over an untagged one', () {
    expect(
      selectReleaseAsset(
        assets(<String>[
          'neoagent-setup-3.4.8.exe',
          'neoagent-windows-arm64-setup-3.4.8.exe',
        ]),
        matchers: windowsMatchers,
        architecture: 'arm64',
      )?.name,
      'neoagent-windows-arm64-setup-3.4.8.exe',
    );
  });

  test('apks carry no architecture and stay selectable', () {
    expect(
      selectReleaseAsset(
        assets(),
        matchers: <bool Function(String)>[
          (name) => name.endsWith('.apk') && !name.contains('launcher'),
        ],
        architecture: 'arm64',
      )?.name,
      'neoagent-3.4.8.apk',
    );
  });
}

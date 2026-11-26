import 'package:neoagent_flutter/src/l10n/app_language.dart';
import 'package:neolabs_flutter/installer.dart';

import 'app_release_updater.dart';
import 'setup_contract.g.dart';

const String _runtimeSigningPublicKey = String.fromEnvironment(
  'NEOAGENT_RUNTIME_PUBLIC_KEY',
  defaultValue: embeddedRuntimeSigningPublicKey,
);

/// What the shared NeoLabs installer needs to know about NeoAgent.
const NeoRuntimeApp neoAgentRuntimeApp = NeoRuntimeApp(
  name: 'NeoAgent',
  command: 'neoagent',
  repository: '$appUpdaterGithubOwner/$appUpdaterGithubRepo',
  publicKey: _runtimeSigningPublicKey,
  targets: setupRuntimeTargets,
  webIndex: <String>['public', 'index.html'],
  schemaVersion: setupContractSchemaVersion,
  extraBinDirectories: <List<String>>[
    <String>['computer-runtime', 'qemu', 'bin'],
  ],
  githubToken: appUpdaterGithubToken,
  strings: _installText,
);

String _installText(NeoInstallText text) => switch (text) {
  NeoInstallText.finding => appStrings.findingTheCorrectNeoagentRuntime,
  NeoInstallText.downloading => appStrings.downloadingTheNeoagentBackend,
  NeoInstallText.verifying => appStrings.verifyingTheDownloadedRuntime,
  NeoInstallText.extracting => appStrings.extractingTheNeoagentRuntime,
  NeoInstallText.usingInstalled => appStrings.usingTheInstalledNeoagentRuntime,
  NeoInstallText.ready => appStrings.neoagentIsReady,
  NeoInstallText.cancelled => appStrings.setupWasCancelled,
  NeoInstallText.disposed => appStrings.theInstallerIsNoLongerAvailable,
  NeoInstallText.unsupportedPlatform =>
    appStrings.noNeoagentBackendRuntimeIsAvailable,
  NeoInstallText.insecureDownload =>
    appStrings.neoagentRuntimeDownloadsRequireASecure,
  NeoInstallText.releaseLookupFailed =>
    appStrings.neoagentCouldNotCheckTheAvailable,
  NeoInstallText.releaseListInvalid =>
    appStrings.theNeoagentReleaseServiceReturnedInvalid,
  NeoInstallText.notPublished => appStrings.noVerifiedNeoagentBackendRuntimeIs,
  NeoInstallText.assetMissing => appStrings.theMatchingNeoagentRuntimeIsMissing,
  NeoInstallText.downloadFailed => appStrings.theNeoagentBackendRuntimeCouldNot,
  NeoInstallText.downloadIncomplete =>
    appStrings.theNeoagentBackendDownloadWasIncomplete,
  NeoInstallText.metadataTooLarge =>
    appStrings.aNeoagentSetupMetadataFileExceeded,
  NeoInstallText.trustNotConfigured =>
    appStrings.thisNeoagentBuildIsNotConfigured,
  NeoInstallText.signatureInvalid =>
    appStrings.theNeoagentRuntimeManifestDidNot,
  NeoInstallText.manifestInvalid => appStrings.invalidNeoagentRuntimeManifest,
  NeoInstallText.hashMismatch => appStrings.theDownloadedNeoagentRuntimeDidNot,
  NeoInstallText.archiveInvalid =>
    appStrings.theNeoagentRuntimeArchiveCouldNotBe,
  NeoInstallText.archiveUnsafe =>
    appStrings.theNeoagentRuntimeArchiveContainsAnUnsafe,
  NeoInstallText.runtimeIncomplete =>
    appStrings.theVerifiedRuntimePackageIsMissing,
  NeoInstallText.restoring => appStrings.restoringThePreviousNeoagentRuntime,
  NeoInstallText.rollbackIncomplete =>
    appStrings.automaticRollbackNeedsARetryFrom,
};

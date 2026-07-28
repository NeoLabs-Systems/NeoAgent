import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'local_backend_installer.dart';
import 'setup_contract.g.dart';

String redactSetupDiagnosticMessage(
  String message, {
  Map<String, String> environment = const <String, String>{},
}) {
  var redacted = message.replaceAll(
    RegExp(r'https?://[^\s)]+'),
    '[server-address]',
  );
  for (final homeKey in const <String>['HOME', 'USERPROFILE']) {
    final home = environment[homeKey]?.trim() ?? '';
    if (home.isNotEmpty) {
      redacted = redacted.replaceAll(home, '[user-path]');
    }
  }
  return redacted;
}

Map<String, dynamic> buildSetupDiagnosticReport({
  required LocalBackendSetupProfile profile,
  required List<LocalBackendInstallEvent> events,
  required DateTime createdAt,
  Map<String, String> environment = const <String, String>{},
}) {
  return <String, dynamic>{
    'schemaVersion': setupContractSchemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'profile': profile.name,
    'events': <Map<String, dynamic>>[
      for (final event in events)
        <String, dynamic>{
          'stage': event.stage.name,
          'state': event.state,
          'message': redactSetupDiagnosticMessage(
            event.message,
            environment: environment,
          ),
          if (event.progress != null) 'progress': event.progress,
          if (event.errorCode != null) 'errorCode': event.errorCode,
          'retryable': event.retryable,
        },
    ],
  };
}

Future<bool> saveSetupDiagnostics({
  required LocalBackendSetupProfile profile,
  required List<LocalBackendInstallEvent> events,
}) async {
  final destination = await FilePicker.platform.saveFile(
    dialogTitle: 'Save NeoAgent setup diagnostics',
    fileName: 'neoagent-setup-diagnostics.json',
  );
  if (destination == null) return false;
  final report = buildSetupDiagnosticReport(
    profile: profile,
    events: events,
    createdAt: DateTime.now(),
    environment: Platform.environment,
  );
  await File(destination).writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    flush: true,
  );
  return true;
}

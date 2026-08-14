import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks recently-used local workspace folders so the Cowork workspace
/// picker can surface them above a fresh "choose folder" browse.
class WorkspaceRecents {
  const WorkspaceRecents._();

  static const String _prefsKey = 'cowork_recent_workspace_paths';
  static const int _maxEntries = 8;

  static Future<List<String>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .map((entry) => entry.toString())
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> recordUsed(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await list();
    final updated = <String>[
      trimmed,
      ...current.where((entry) => entry != trimmed),
    ].take(_maxEntries).toList(growable: false);
    await prefs.setString(_prefsKey, jsonEncode(updated));
  }

  static Future<void> remove(String path) async {
    final trimmed = path.trim();
    final prefs = await SharedPreferences.getInstance();
    final current = await list();
    final updated = current
        .where((entry) => entry != trimmed)
        .toList(growable: false);
    await prefs.setString(_prefsKey, jsonEncode(updated));
  }
}

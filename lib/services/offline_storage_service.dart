import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStorageService {
  static const String _keyQueue = 'motosquad_unsent_queue';
  static const String _keyLastSession = 'motosquad_last_session';

  Future<void> queueUnsentLocation(Map<String, dynamic> locationPayload) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_keyQueue) ?? [];
    queue.add(jsonEncode({
      'type': 'location',
      'payload': locationPayload,
      'queuedAt': DateTime.now().toIso8601String(),
    }));
    // Keep max 100 recent points to avoid excessive memory
    if (queue.length > 100) {
      queue.removeRange(0, queue.length - 100);
    }
    await prefs.setStringList(_keyQueue, queue);
  }

  Future<List<Map<String, dynamic>>> flushQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawQueue = prefs.getStringList(_keyQueue) ?? [];
    if (rawQueue.isEmpty) return [];

    final List<Map<String, dynamic>> items = [];
    for (final itemStr in rawQueue) {
      try {
        items.add(jsonDecode(itemStr) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Clear queue after retrieval
    await prefs.remove(_keyQueue);
    return items;
  }

  Future<void> saveConvoySession(String convoyCode, Map<String, dynamic> meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSession, jsonEncode({
      'convoyCode': convoyCode,
      'meta': meta,
      'savedAt': DateTime.now().toIso8601String(),
    }));
  }

  Future<Map<String, dynamic>?> getLastConvoySession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastSession);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

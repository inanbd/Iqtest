import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/attempt.dart';

/// Local, on-device persistence for completed attempts.
///
/// Nothing leaves the device: results are held in shared preferences as a
/// single JSON array, newest first.
class HistoryStore {
  static const String _key = 'iq_test_attempts_v1';

  /// Attempts older than this are dropped so the list cannot grow unbounded.
  static const int maxAttempts = 50;

  Future<List<Attempt>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Attempt.fromJson)
          .toList(growable: false);
    } on FormatException {
      // A corrupt entry should not brick the history screen.
      return const [];
    }
  }

  Future<List<Attempt>> add(Attempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = [attempt, ...await load()];
    final trimmed = attempts.take(maxAttempts).toList(growable: false);
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((a) => a.toJson()).toList()),
    );
    return trimmed;
  }

  /// Item ids used by the most recent [sittings] attempts.
  ///
  /// The draw holds these back so a repeat taker meets fresh items. One
  /// sitting is the default because the pool is sized to guarantee a
  /// completely fresh draw at that depth, and no deeper.
  Future<Set<String>> recentItemIds({int sittings = 1}) async {
    final attempts = await load();
    return {for (final attempt in attempts.take(sittings)) ...attempt.itemIds};
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

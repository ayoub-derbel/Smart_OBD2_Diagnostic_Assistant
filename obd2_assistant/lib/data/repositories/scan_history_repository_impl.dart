import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/scan_record.dart';
import '../../domain/repositories/scan_history_repository.dart';

/// Persists scan history to local storage using SharedPreferences.
class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const String _storageKey = 'scan_history';

  @override
  Future<void> saveScan(ScanRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_storageKey) ?? [];
    existing.add(record.encode());
    await prefs.setStringList(_storageKey, existing);
  }

  @override
  Future<List<ScanRecord>> getAllScans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    final scans = raw.map((s) => ScanRecord.decode(s)).toList();
    // Most recent first
    scans.sort((a, b) => b.date.compareTo(a.date));
    return scans;
  }

  @override
  Future<List<ScanRecord>> getRecentScans({int limit = 5}) async {
    final all = await getAllScans();
    return all.take(limit).toList();
  }

  @override
  Future<void> deleteScan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_storageKey) ?? [];
    final filtered = existing.where((s) {
      try {
        final record = ScanRecord.decode(s);
        return record.id != id;
      } catch (_) {
        return false;
      }
    }).toList();
    await prefs.setStringList(_storageKey, filtered);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

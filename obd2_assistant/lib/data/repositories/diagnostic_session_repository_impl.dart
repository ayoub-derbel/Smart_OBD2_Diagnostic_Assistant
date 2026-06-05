import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/diagnostic_session.dart';
import '../../domain/repositories/diagnostic_session_repository.dart';

class DiagnosticSessionRepositoryImpl implements DiagnosticSessionRepository {
  static const String _storageKey = 'active_diagnostic_session';
  static const String _sessionPrefix = 'diagnostic_session_';

  @override
  Future<void> saveActiveSession(DiagnosticSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, session.encode());
    await saveSession(session);
  }

  @override
  Future<DiagnosticSession?> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(_storageKey);
    if (rawSession == null || rawSession.isEmpty) return null;

    try {
      return DiagnosticSession.decode(rawSession);
    } catch (_) {
      await prefs.remove(_storageKey);
      return null;
    }
  }

  @override
  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  @override
  Future<void> saveSession(DiagnosticSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_sessionPrefix${session.id}', session.encode());
  }

  @override
  Future<DiagnosticSession?> getSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_sessionPrefix$id');
    if (raw == null || raw.isEmpty) return null;
    try {
      return DiagnosticSession.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_sessionPrefix$id');
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_sessionPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

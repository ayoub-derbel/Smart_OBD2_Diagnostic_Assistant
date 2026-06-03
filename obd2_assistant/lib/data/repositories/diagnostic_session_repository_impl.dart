import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/diagnostic_session.dart';
import '../../domain/repositories/diagnostic_session_repository.dart';

class DiagnosticSessionRepositoryImpl implements DiagnosticSessionRepository {
  static const String _storageKey = 'active_diagnostic_session';

  @override
  Future<void> saveActiveSession(DiagnosticSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, session.encode());
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
}

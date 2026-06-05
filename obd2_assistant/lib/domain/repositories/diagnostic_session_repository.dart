import '../entities/diagnostic_session.dart';

abstract class DiagnosticSessionRepository {
  Future<void> saveActiveSession(DiagnosticSession session);
  Future<DiagnosticSession?> getActiveSession();
  Future<void> clearActiveSession();
  Future<void> saveSession(DiagnosticSession session);
  Future<DiagnosticSession?> getSession(String id);
  Future<void> deleteSession(String id);
  Future<void> clearAll();
}

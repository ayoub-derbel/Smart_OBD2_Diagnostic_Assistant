import '../entities/diagnostic_session.dart';

abstract class DiagnosticSessionRepository {
  Future<void> saveActiveSession(DiagnosticSession session);
  Future<DiagnosticSession?> getActiveSession();
  Future<void> clearActiveSession();
}

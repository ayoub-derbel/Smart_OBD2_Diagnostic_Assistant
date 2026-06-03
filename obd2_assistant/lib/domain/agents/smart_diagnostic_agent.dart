import 'dart:convert';

import '../../data/datasources/ai_api_service.dart';
import '../../data/services/obd2_service.dart';
import '../entities/chat_message.dart';
import '../entities/diagnostic_session.dart';
import '../entities/scan_record.dart';
import '../repositories/chat_history_repository.dart';
import '../repositories/diagnostic_session_repository.dart';
import '../repositories/scan_history_repository.dart';

class SmartDiagnosticAgent {
  final Obd2Service _obd2Service;
  final AiApiService _aiApiService;
  final ChatHistoryRepository _historyRepo;
  final ScanHistoryRepository _scanHistoryRepo;
  final DiagnosticSessionRepository _sessionRepo;

  DiagnosticSession? _activeSession;

  SmartDiagnosticAgent(
    this._obd2Service,
    this._aiApiService,
    this._historyRepo,
    this._scanHistoryRepo,
    this._sessionRepo,
  );

  Future<List<ChatMessage>> get chatHistory async {
    final session = await _getActiveSession();
    if (session == null) return const [];
    return _historyRepo.getMessages(session.id);
  }

  Map<String, dynamic>? get lastScanContext => _activeSession?.diagnosticContext;

  Future<DiagnosticSession?> getActiveSession() => _getActiveSession();

  Future<void> clearHistory() async {
    final session = await _getActiveSession();
    if (session != null) {
      await _historyRepo.clearSession(session.id);
    }
    await _sessionRepo.clearActiveSession();
    _activeSession = null;
  }

  Future<String> _buildScanHistoryPrompt() async {
    final recentScans = await _scanHistoryRepo.getRecentScans(limit: 3);
    if (recentScans.isEmpty) return '';
    return recentScans.map((scan) => scan.toPromptSummary()).join('\n');
  }

  Future<void> _saveScanRecord(DiagnosticSession session) async {
    final record = ScanRecord(
      id: session.id,
      date: session.createdAt,
      storedDtcs: session.scan.storedDtcs,
      pendingDtcs: session.scan.pendingDtcs,
      vin: session.scan.vin,
      safety: session.report.safety,
      issue: session.report.issue,
      urgency: session.report.urgency,
      aiSummary: session.report.summary,
      liveDataSnapshot: session.scan.pidValues,
    );

    await _scanHistoryRepo.saveScan(record);
  }

  DiagnosticSessionReport _buildSessionReport(String aiResponse) {
    final reportFields = _extractReportFields(aiResponse);
    final fallbackSummary = aiResponse.length > 500
        ? aiResponse.substring(0, 500)
        : aiResponse;

    return DiagnosticSessionReport(
      safety: reportFields['safety'] ?? '',
      issue: reportFields['issue'] ?? '',
      urgency: reportFields['urgency'] ?? '',
      summary: reportFields['summary'] ?? fallbackSummary,
      rawText: aiResponse,
    );
  }

  Map<String, String> _extractReportFields(String aiResponse) {
    final jsonReport = _tryDecodeJsonMap(aiResponse);
    if (jsonReport != null) {
      final safety = _firstString(jsonReport, ['safety', 'safety_status']);
      final issue = _firstString(jsonReport, ['issue', 'main_issue']);
      final urgency = _firstString(jsonReport, ['urgency']);
      final causes = _extractCauseNames(
        jsonReport['causes'] ?? jsonReport['probable_causes'],
      );

      final summaryParts = [
        if (safety.isNotEmpty) 'safety=$safety',
        if (issue.isNotEmpty) 'issue=$issue',
        if (urgency.isNotEmpty) 'urgency=$urgency',
        if (causes.isNotEmpty) 'causes=${causes.take(3).join(",")}',
      ];

      return {
        'safety': safety,
        'issue': issue,
        'urgency': urgency,
        if (summaryParts.isNotEmpty) 'summary': summaryParts.join('; '),
      };
    }

    final safety = _extractField(
      aiResponse,
      r'(?:SAFETY|SECURITE).*?:\s*(.*?)(?=\n|$)',
    );
    final issue = _extractField(
      aiResponse,
      r'(?:ISSUE|PROBLEME).*?:\s*(.*?)(?=\n|$)',
    );
    final urgency = _extractField(
      aiResponse,
      r'(?:URGENCY|URGENCE).*?:\s*(.*?)(?=\n|$)',
    );

    return {'safety': safety, 'issue': issue, 'urgency': urgency};
  }

  String _extractField(String text, String pattern) {
    final match = RegExp(
      pattern,
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    return match?.group(1)?.replaceAll('**', '').replaceAll('*', '').trim() ??
        '';
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String content) {
    try {
      var jsonText = content.trim();
      if (jsonText.contains('```json')) {
        final start = jsonText.indexOf('```json') + 7;
        final end = jsonText.lastIndexOf('```');
        if (end > start) jsonText = jsonText.substring(start, end).trim();
      } else if (jsonText.contains('{')) {
        final start = jsonText.indexOf('{');
        final end = jsonText.lastIndexOf('}');
        if (end > start) jsonText = jsonText.substring(start, end + 1).trim();
      }

      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  List<String> _extractCauseNames(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) {
          if (item is Map) {
            return (item['cause'] ??
                    item['title'] ??
                    item['probable_cause'] ??
                    '')
                .toString()
                .trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<ScanSnapshot> _executeObdScan() async {
    final supportedPids = await _obd2Service.discoverSupportedPids();
    final dtcs = await _obd2Service.readAllDTCs();
    final vin = await _obd2Service.readVin();
    final freezeFrames = await _obd2Service.readFreezeFrames();

    final pidsToRead = supportedPids.take(15).toList();
    final pidValues = await _obd2Service.readMultiplePids(pidsToRead);

    return ScanSnapshot(
      vin: vin,
      supportedPids: supportedPids,
      storedDtcs: dtcs['stored'] ?? const <String>[],
      pendingDtcs: dtcs['pending'] ?? const <String>[],
      freezeFrames: freezeFrames,
      pidValues: pidValues,
    );
  }

  Future<String> performFullScan() async {
    final previousSession = await _getActiveSession();
    if (previousSession != null) {
      await _historyRepo.clearSession(previousSession.id);
    }

    final scan = await _executeObdScan();
    final diagnosticContext = scan.toDiagnosticContext();
    final scanHistoryPrompt = await _buildScanHistoryPrompt();

    final response = await _aiApiService.chatWithUnifiedContext(
      history: [
        {'role': 'user', 'content': 'Faire un Diagnostic complet'},
      ],
      diagnosticContext: diagnosticContext,
      isDiagnosticReport: true,
      scanHistoryPrompt: scanHistoryPrompt,
    );

    final aiText = response.text ?? 'Erreur de generation du rapport.';
    final now = DateTime.now();
    final session = DiagnosticSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      createdAt: now,
      scan: scan,
      report: _buildSessionReport(aiText),
    );

    _activeSession = session;
    await _sessionRepo.saveActiveSession(session);
    await _historyRepo.clearSession(session.id);

    await _saveScanRecord(session);
    return aiText;
  }

  Future<String> askQuestion(String question) async {
    try {
      final session = await _getActiveSession();
      if (session == null) {
        const missingSessionMessage =
            "Aucun diagnostic actif n'est disponible. Lancez d'abord un diagnostic complet depuis l'interface, puis posez vos questions sur ce scan.";
        return missingSessionMessage;
      }

      await _historyRepo.saveMessage(
        sessionId: session.id,
        message: ChatMessage(
          sessionId: session.id,
          role: MessageRole.user,
          content: question,
        ),
      );

      final response = await _aiApiService.chatWithUnifiedContext(
        history: [
          {'role': 'user', 'content': question},
        ],
        diagnosticContext: session.diagnosticContext,
        isDiagnosticReport: false,
      );

      final answer = response.text?.trim().isNotEmpty == true
          ? response.text!.trim()
          : "Je n'ai pas pu generer de reponse a partir du diagnostic actif.";
      await _historyRepo.saveMessage(
        sessionId: session.id,
        message: ChatMessage(
          sessionId: session.id,
          role: MessageRole.assistant,
          content: answer,
        ),
      );
      return answer;
    } catch (e) {
      final errorMsg = "Desole, j'ai rencontre une erreur : $e";
      final session = await _getActiveSession();
      if (session != null) {
        await _historyRepo.saveMessage(
          sessionId: session.id,
          message: ChatMessage(
            sessionId: session.id,
            role: MessageRole.assistant,
            content: errorMsg,
          ),
        );
      }
      return errorMsg;
    }
  }

  Future<DiagnosticSession?> _getActiveSession() async {
    if (_activeSession != null) return _activeSession;
    _activeSession = await _sessionRepo.getActiveSession();
    return _activeSession;
  }
}

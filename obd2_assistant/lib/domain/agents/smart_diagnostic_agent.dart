import 'dart:convert';
import '../../data/datasources/ai_api_service.dart';
import '../../data/services/obd2_service.dart';
import '../entities/full_diagnostic_report.dart';
import '../entities/chat_message.dart';
import '../entities/scan_record.dart';
import '../repositories/chat_history_repository.dart';
import '../repositories/scan_history_repository.dart';

class SmartDiagnosticAgent {
  final Obd2Service _obd2Service;
  final AiApiService _aiApiService;
  final ChatHistoryRepository _historyRepo;
  final ScanHistoryRepository _scanHistoryRepo;
  
  // Internal state
  Map<String, dynamic>? _lastScanContext;

  SmartDiagnosticAgent(this._obd2Service, this._aiApiService, this._historyRepo, this._scanHistoryRepo);

  Future<List<ChatMessage>> get chatHistory => _historyRepo.getMessages();
  Map<String, dynamic>? get lastScanContext => _lastScanContext;

  /// Récupère l'historique des scans pour injection dans le prompt
  Future<String> _buildScanHistoryPrompt() async {
    final recentScans = await _scanHistoryRepo.getRecentScans(limit: 3);
    if (recentScans.isEmpty) return '';
    
    final summaries = recentScans.map((s) => s.toPromptSummary()).join('\n');
    return '\n\nVEHICLE DIAGNOSTIC HISTORY (last ${recentScans.length} scans):\n$summaries\n\nUse this history to detect recurring issues, trends, or improvements since the last scan.';
  }

  /// Sauvegarde un scan dans l'historique persistant
  Future<void> _saveScanRecord(String aiResponse) async {
    if (_lastScanContext == null) return;

    // Extraire safety, issue, urgency du rapport IA
    final safety = _extractField(aiResponse, r'(?:SAFETY|SÉCURITÉ|SECURITE).*?:\s*(.*?)(?=\n|$)');
    final issue = _extractField(aiResponse, r'(?:ISSUE|PROBLÈME|PROBLEME).*?:\s*(.*?)(?=\n|$)');
    final urgency = _extractField(aiResponse, r'(?:URGENCY|URGENCE).*?:\s*(.*?)(?=\n|$)');

    final record = ScanRecord(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      storedDtcs: List<String>.from(_lastScanContext!['stored_dtcs'] ?? []),
      pendingDtcs: List<String>.from(_lastScanContext!['pending_dtcs'] ?? []),
      vin: _lastScanContext!['vin']?.toString(),
      safety: safety,
      issue: issue,
      urgency: urgency,
      aiSummary: aiResponse.length > 500 ? aiResponse.substring(0, 500) : aiResponse,
      liveDataSnapshot: Map<String, String>.from(
        (_lastScanContext!['pid_values_raw'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {}
      ),
    );

    await _scanHistoryRepo.saveScan(record);
  }

  String _extractField(String text, String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
    return match?.group(1)?.replaceAll('**', '').replaceAll('*', '').trim() ?? '';
  }

  /// Effectue le scan OBD physique
  Future<void> _executeObdScan() async {
    final supportedPids = await _obd2Service.discoverSupportedPids();
    final dtcs = await _obd2Service.readAllDTCs();
    final vin = await _obd2Service.readVin();
    final freezeFrames = await _obd2Service.readFreezeFrames();

    final pidsToRead = supportedPids.take(15).toList();
    final pidValues = await _obd2Service.readMultiplePids(pidsToRead);

    _lastScanContext = {
      "vin": vin,
      "supported_pids": supportedPids,
      "stored_dtcs": dtcs["stored"] ?? [],
      "pending_dtcs": dtcs["pending"] ?? [],
      "freeze_frames": freezeFrames,
      "pid_values_raw": pidValues,
    };
  }

  /// Appelé directement depuis le bouton (Bypass du Function Calling)
  Future<void> performFullScan() async {
    await _executeObdScan();

    // On n'efface PLUS l'historique ! On ajoute simplement l'intention
    await _historyRepo.saveMessage(ChatMessage(
      role: MessageRole.user,
      content: "Faire un Diagnostic complet",
    ));

    final history = await _historyRepo.getMessages();
    final scanHistoryPrompt = await _buildScanHistoryPrompt();
    
    final response = await _aiApiService.chatWithUnifiedContext(
      history: history.map((m) => m.toApiJson()).toList(),
      diagnosticContext: _lastScanContext,
      isDiagnosticReport: true,
      scanHistoryPrompt: scanHistoryPrompt,
    );

    final aiText = response.text ?? "Erreur de génération du rapport.";
    
    await _historyRepo.saveMessage(ChatMessage(
      role: MessageRole.assistant,
      content: aiText,
    ));

    // Sauvegarder ce scan dans l'historique persistant
    await _saveScanRecord(aiText);
  }

  /// Appelé depuis le champ de texte (Gère le Function Calling)
  Future<String> askQuestion(String question) async {
    await _historyRepo.saveMessage(ChatMessage(role: MessageRole.user, content: question));

    // Build apiHistory from stored messages
    final history = await _historyRepo.getMessages();
    final apiHistory = history.map((m) => m.toApiJson()).toList();

    final scanHistoryPrompt = await _buildScanHistoryPrompt();

    try {
      final response = await _aiApiService.chatWithUnifiedContext(
        history: apiHistory,
        diagnosticContext: _lastScanContext,
        isDiagnosticReport: false,
        scanHistoryPrompt: scanHistoryPrompt,
      );


      // Si l'IA décide d'utiliser l'outil (Function Calling)
      if (response.wantsToScan) {
        final toolCall = response.toolCallData[0];
        final toolCallId = toolCall['id'];
        final toolName = toolCall['function']['name'];

        // 1. Sauvegarder la demande de l'assistant dans l'historique
        await _historyRepo.saveMessage(ChatMessage(
          role: MessageRole.assistant,
          toolCalls: response.toolCallData,
        ));

        // 2. Exécuter l'outil (Scan OBD)
        await _executeObdScan();

        // 3. Sauvegarder le résultat de l'outil dans l'historique
        await _historyRepo.saveMessage(ChatMessage(
          role: MessageRole.tool,
          toolCallId: toolCallId,
          name: toolName,
          content: jsonEncode(_lastScanContext),
        ));

        // 4. Deuxième appel à l'API pour générer le rapport final
        final historyAfterTool = await _historyRepo.getMessages();
        final finalResponse = await _aiApiService.chatWithUnifiedContext(
          history: historyAfterTool.map((m) => m.toApiJson()).toList(),
          diagnosticContext: _lastScanContext,
          isDiagnosticReport: true,
          scanHistoryPrompt: scanHistoryPrompt,
        );

        final aiText = finalResponse.text ?? "Diagnostic terminé.";

        await _historyRepo.saveMessage(ChatMessage(
          role: MessageRole.assistant, 
          content: aiText,
        ));

        // Sauvegarder ce scan dans l'historique persistant
        await _saveScanRecord(aiText);

        return aiText;
      }

      // Si l'IA répond normalement par du texte
      await _historyRepo.saveMessage(ChatMessage(
        role: MessageRole.assistant, 
        content: response.text ?? ""
      ));
      return response.text ?? "";
      
    } catch (e) {
      final errorMsg = "Désolé, j'ai rencontré une erreur : $e";
      await _historyRepo.saveMessage(ChatMessage(role: MessageRole.assistant, content: errorMsg));
      return errorMsg;
    }
  }


  FullDiagnosticReport _parseReport(String jsonText) {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    final issuesRaw = map["issues"] as List<dynamic>? ?? [];
    final pidsRaw = map["abnormal_pids"] as List<dynamic>? ?? [];

    return FullDiagnosticReport(
      vehicleInfo: map["vehicle_info"]?.toString() ?? "Unknown",
      vehicleSummary: map["vehicle_summary"]?.toString() ?? "Summary unavailable",
      globalHealth: map["global_health"]?.toString() ?? "unknown",
      logicExplanation: map["logic_explanation"]?.toString() ?? "No technical explanation provided.",
      abnormalPids: pidsRaw.map((e) {
        final pid = e as Map<String, dynamic>;
        return AbnormalPid(
          pid: pid["pid"]?.toString() ?? "Unknown PID",
          value: pid["value"]?.toString() ?? "N/A",
          reason: pid["reason"]?.toString() ?? "Abnormal value detected",
        );
      }).toList(),
      issues: issuesRaw.map((e) {
        final issue = e as Map<String, dynamic>;
        return FullDiagnosticIssue(
          title: issue["title"]?.toString() ?? "Issue",
          severity: issue["severity"]?.toString() ?? "medium",
          probableCause: issue["probable_cause"]?.toString() ?? "Cause not specified",
          recommendation: issue["recommendation"]?.toString() ?? "No recommendation",
        );
      }).toList(),
      immediateActions: (map["immediate_actions"] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      preventiveActions: (map["preventive_actions"] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

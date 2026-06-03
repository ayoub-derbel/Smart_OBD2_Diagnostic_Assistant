import 'dart:convert';

import '../../data/datasources/ai_api_service.dart';
import '../../data/services/obd2_service.dart';
import '../entities/full_diagnostic_report.dart';

class DiagnosticAgent {
  final Obd2Service _obd2Service;
  final AiApiService _aiApiService;

  DiagnosticAgent(this._obd2Service, this._aiApiService);

  Future<FullDiagnosticReport> runFullDiagnostic() async {
    final supportedPids = await _obd2Service.discoverSupportedPids();
    final dtcs = await _obd2Service.readAllDTCs();
    final vin = await _obd2Service.readVin();
    final freezeFrames = await _obd2Service.readFreezeFrames();

    final pidsToRead = supportedPids.take(12).toList();
    final pidValues = await _obd2Service.readMultiplePids(pidsToRead);

    final context = {
      "vin": vin,
      "supported_pids": supportedPids,
      "stored_dtcs": dtcs["stored"] ?? const <String>[],
      "pending_dtcs": dtcs["pending"] ?? const <String>[],
      "freeze_frames": freezeFrames,
      "pid_values_raw": pidValues,
    };

    final response = await _aiApiService.chatWithUnifiedContext(
      history: [
        {'role': 'user', 'content': 'Faire un Diagnostic complet'}
      ],
      diagnosticContext: context,
      isDiagnosticReport: true,
    );
    // Comme on n'utilise plus de JSON strict, on renvoie un rapport simplifié ou on gère l'erreur
    // Pour éviter de casser l'existant, on peut essayer de parser, ou renvoyer un objet vide
    try {
      return _parseReport(response.text ?? "");
    } catch (e) {
      return FullDiagnosticReport(
        overview: DiagnosticOverview(
          status: "danger",
          summary: "Erreur lors de la génération du rapport textuel.",
          primaryProblem: "Rapport introuvable ou mal formaté.",
        ),
        problems: [],
        causes: [],
        repairPlan: RepairPlan(
          urgency: "unknown",
          steps: [],
          estimatedDifficulty: "unknown",
        ),
      );
    }
  }

  FullDiagnosticReport _parseReport(String jsonText) {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    
    final overviewMap = map["overview"] as Map<String, dynamic>? ?? {};
    final problemsRaw = map["problems"] as List<dynamic>? ?? [];
    final causesRaw = map["causes"] as List<dynamic>? ?? [];
    final repairPlanMap = map["repair_plan"] as Map<String, dynamic>? ?? {};
    final stepsRaw = repairPlanMap["steps"] as List<dynamic>? ?? [];

    return FullDiagnosticReport(
      overview: DiagnosticOverview(
        status: overviewMap["status"]?.toString() ?? "unknown",
        summary: overviewMap["summary"]?.toString() ?? "Summary unavailable",
        primaryProblem: overviewMap["primary_problem"]?.toString() ?? "Unknown problem",
      ),
      problems: problemsRaw.map((e) {
        final problem = e as Map<String, dynamic>;
        return DiagnosticProblem(
          title: problem["title"]?.toString() ?? "Issue",
          severity: problem["severity"]?.toString() ?? "medium",
          description: problem["description"]?.toString() ?? "No description",
        );
      }).toList(),
      causes: causesRaw.map((e) {
        final cause = e as Map<String, dynamic>;
        return DiagnosticCause(
          cause: cause["cause"]?.toString() ?? "Unknown cause",
          probability: cause["probability"]?.toString() ?? "medium",
          evidence: cause["evidence"]?.toString() ?? "No evidence",
        );
      }).toList(),
      repairPlan: RepairPlan(
        urgency: repairPlanMap["urgency"]?.toString() ?? "unknown",
        estimatedDifficulty: repairPlanMap["estimated_difficulty"]?.toString() ?? "unknown",
        steps: stepsRaw.map((e) {
          final step = e as Map<String, dynamic>;
          return RepairStep(
            stepNumber: int.tryParse(step["step_number"]?.toString() ?? "0") ?? 0,
            action: step["action"]?.toString() ?? "Action",
            type: step["type"]?.toString() ?? "maintenance",
          );
        }).toList(),
      ),
    );
  }
}

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
    );
    // Comme on n'utilise plus de JSON strict, on renvoie un rapport simplifié ou on gère l'erreur
    // Pour éviter de casser l'existant, on peut essayer de parser, ou renvoyer un objet vide
    try {
      return _parseReport(response.text ?? "");
    } catch (e) {
      return FullDiagnosticReport(
        vehicleInfo: "Véhicule détecté",
        vehicleSummary: "Rapport textuel disponible dans le chat",
        globalHealth: "warning",
        logicExplanation: response.text ?? "",
        abnormalPids: [],
        issues: [],
        immediateActions: [],
        preventiveActions: [],
      );
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
      immediateActions: (map["immediate_actions"] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      preventiveActions: (map["preventive_actions"] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

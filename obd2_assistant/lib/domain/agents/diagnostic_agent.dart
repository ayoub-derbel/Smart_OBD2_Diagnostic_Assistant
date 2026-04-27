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

    final llmResponse = await _aiApiService.analyzeFullDiagnosticContext(context);
    return _parseReport(llmResponse);
  }

  FullDiagnosticReport _parseReport(String jsonText) {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    final issuesRaw = map["issues"] as List<dynamic>? ?? [];

    return FullDiagnosticReport(
      vehicleSummary: map["vehicle_summary"]?.toString() ?? "Vehicule non identifie",
      globalHealth: map["global_health"]?.toString() ?? "Etat inconnu",
      issues: issuesRaw.map((e) {
        final issue = e as Map<String, dynamic>;
        return FullDiagnosticIssue(
          title: issue["title"]?.toString() ?? "Issue",
          severity: issue["severity"]?.toString() ?? "medium",
          probableCause: issue["probable_cause"]?.toString() ?? "Cause non precisee",
          recommendation: issue["recommendation"]?.toString() ?? "Aucune recommendation",
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

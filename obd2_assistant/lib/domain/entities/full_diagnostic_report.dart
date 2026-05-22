class FullDiagnosticIssue {
  final String title;
  final String severity;
  final String probableCause;
  final String recommendation;

  FullDiagnosticIssue({
    required this.title,
    required this.severity,
    required this.probableCause,
    required this.recommendation,
  });
}

class AbnormalPid {
  final String pid;
  final String value;
  final String reason;

  AbnormalPid({
    required this.pid,
    required this.value,
    required this.reason,
  });
}

class FullDiagnosticReport {
  final String vehicleInfo;
  final String vehicleSummary;
  final String globalHealth;
  final String logicExplanation;
  final List<AbnormalPid> abnormalPids;
  final List<FullDiagnosticIssue> issues;
  final List<String> immediateActions;
  final List<String> preventiveActions;

  FullDiagnosticReport({
    required this.vehicleInfo,
    required this.vehicleSummary,
    required this.globalHealth,
    required this.logicExplanation,
    required this.abnormalPids,
    required this.issues,
    required this.immediateActions,
    required this.preventiveActions,
  });
}

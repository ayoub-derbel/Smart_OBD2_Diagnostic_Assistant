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

class FullDiagnosticReport {
  final String vehicleSummary;
  final String globalHealth;
  final List<FullDiagnosticIssue> issues;
  final List<String> immediateActions;
  final List<String> preventiveActions;

  FullDiagnosticReport({
    required this.vehicleSummary,
    required this.globalHealth,
    required this.issues,
    required this.immediateActions,
    required this.preventiveActions,
  });
}

class DiagnosticOverview {
  final String status;
  final String summary;
  final String primaryProblem;

  DiagnosticOverview({
    required this.status,
    required this.summary,
    required this.primaryProblem,
  });
}

class DiagnosticProblem {
  final String title;
  final String severity;
  final String description;

  DiagnosticProblem({
    required this.title,
    required this.severity,
    required this.description,
  });
}

class DiagnosticCause {
  final String cause;
  final String probability;
  final String evidence;

  DiagnosticCause({
    required this.cause,
    required this.probability,
    required this.evidence,
  });
}

class RepairStep {
  final int stepNumber;
  final String action;
  final String type;

  RepairStep({
    required this.stepNumber,
    required this.action,
    required this.type,
  });
}

class RepairPlan {
  final String urgency;
  final List<RepairStep> steps;
  final String estimatedDifficulty;

  RepairPlan({
    required this.urgency,
    required this.steps,
    required this.estimatedDifficulty,
  });
}

class FullDiagnosticReport {
  final DiagnosticOverview overview;
  final List<DiagnosticProblem> problems;
  final List<DiagnosticCause> causes;
  final RepairPlan repairPlan;

  FullDiagnosticReport({
    required this.overview,
    required this.problems,
    required this.causes,
    required this.repairPlan,
  });
}

class DiagnosticResult {
  final String? identifiedVehicle;
  final String interpretation;
  final String possibleCauses;
  final String troubleshootingSteps;

  DiagnosticResult({
    this.identifiedVehicle,
    required this.interpretation,
    required this.possibleCauses,
    required this.troubleshootingSteps,
  });
}

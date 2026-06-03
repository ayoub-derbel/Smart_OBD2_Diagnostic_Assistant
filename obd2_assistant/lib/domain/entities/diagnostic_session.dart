import 'dart:convert';

class ScanSnapshot {
  final String? vin;
  final List<String> supportedPids;
  final List<String> storedDtcs;
  final List<String> pendingDtcs;
  final List<Map<String, String>> freezeFrames;
  final Map<String, String> pidValues;

  const ScanSnapshot({
    this.vin,
    required this.supportedPids,
    required this.storedDtcs,
    required this.pendingDtcs,
    required this.freezeFrames,
    required this.pidValues,
  });

  Map<String, dynamic> toDiagnosticContext() => {
    'vin': vin,
    'supported_pids': supportedPids,
    'stored_dtcs': storedDtcs,
    'pending_dtcs': pendingDtcs,
    'freeze_frames': freezeFrames,
    'pid_values_raw': pidValues,
  };

  Map<String, dynamic> toJson() => {
    'vin': vin,
    'supportedPids': supportedPids,
    'storedDtcs': storedDtcs,
    'pendingDtcs': pendingDtcs,
    'freezeFrames': freezeFrames,
    'pidValues': pidValues,
  };

  factory ScanSnapshot.fromJson(Map<String, dynamic> json) => ScanSnapshot(
    vin: json['vin'] as String?,
    supportedPids: _stringList(json['supportedPids']),
    storedDtcs: _stringList(json['storedDtcs']),
    pendingDtcs: _stringList(json['pendingDtcs']),
    freezeFrames: _stringMapList(json['freezeFrames']),
    pidValues: _stringMap(json['pidValues']),
  );
}

class DiagnosticSessionReport {
  final String safety;
  final String issue;
  final String urgency;
  final String summary;
  final String rawText;

  const DiagnosticSessionReport({
    required this.safety,
    required this.issue,
    required this.urgency,
    required this.summary,
    required this.rawText,
  });

  Map<String, dynamic> toJson() => {
    'safety': safety,
    'issue': issue,
    'urgency': urgency,
    'summary': summary,
    'rawText': rawText,
  };

  factory DiagnosticSessionReport.fromJson(Map<String, dynamic> json) =>
      DiagnosticSessionReport(
        safety: json['safety']?.toString() ?? '',
        issue: json['issue']?.toString() ?? '',
        urgency: json['urgency']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        rawText: json['rawText']?.toString() ?? '',
      );
}

class DiagnosticSession {
  final String id;
  final DateTime createdAt;
  final ScanSnapshot scan;
  final DiagnosticSessionReport report;
  final bool isActive;

  const DiagnosticSession({
    required this.id,
    required this.createdAt,
    required this.scan,
    required this.report,
    this.isActive = true,
  });

  Map<String, dynamic> get diagnosticContext => scan.toDiagnosticContext();

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'scan': scan.toJson(),
    'report': report.toJson(),
    'isActive': isActive,
  };

  factory DiagnosticSession.fromJson(Map<String, dynamic> json) =>
      DiagnosticSession(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        scan: ScanSnapshot.fromJson(
          Map<String, dynamic>.from(json['scan'] as Map),
        ),
        report: DiagnosticSessionReport.fromJson(
          Map<String, dynamic>.from(json['report'] as Map),
        ),
        isActive: json['isActive'] as bool? ?? true,
      );

  String encode() => jsonEncode(toJson());

  static DiagnosticSession decode(String source) =>
      DiagnosticSession.fromJson(jsonDecode(source));
}

List<String> _stringList(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry(key.toString(), item.toString()),
  );
}

List<Map<String, String>> _stringMapList(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Map>()
      .map((item) => _stringMap(item))
      .toList();
}

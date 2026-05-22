import 'dart:convert';

/// Represents a saved OBD-II scan snapshot for history tracking.
class ScanRecord {
  final String id;
  final DateTime date;
  final List<String> storedDtcs;
  final List<String> pendingDtcs;
  final String? vin;
  final String safety;
  final String issue;
  final String urgency;
  final String aiSummary;
  final Map<String, String> liveDataSnapshot;

  ScanRecord({
    required this.id,
    required this.date,
    required this.storedDtcs,
    required this.pendingDtcs,
    this.vin,
    required this.safety,
    required this.issue,
    required this.urgency,
    required this.aiSummary,
    required this.liveDataSnapshot,
  });

  /// Compact summary for AI prompt injection (keeps token count low)
  String toPromptSummary() {
    final dtcList = storedDtcs.isNotEmpty ? storedDtcs.join(', ') : 'None';
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '[$dateStr] DTCs: $dtcList | Safety: $safety | Issue: $issue | Urgency: $urgency';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'storedDtcs': storedDtcs,
    'pendingDtcs': pendingDtcs,
    'vin': vin,
    'safety': safety,
    'issue': issue,
    'urgency': urgency,
    'aiSummary': aiSummary,
    'liveDataSnapshot': liveDataSnapshot,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    storedDtcs: List<String>.from(json['storedDtcs'] ?? []),
    pendingDtcs: List<String>.from(json['pendingDtcs'] ?? []),
    vin: json['vin'] as String?,
    safety: json['safety'] as String? ?? '',
    issue: json['issue'] as String? ?? '',
    urgency: json['urgency'] as String? ?? '',
    aiSummary: json['aiSummary'] as String? ?? '',
    liveDataSnapshot: Map<String, String>.from(json['liveDataSnapshot'] ?? {}),
  );

  String encode() => jsonEncode(toJson());
  static ScanRecord decode(String source) => ScanRecord.fromJson(jsonDecode(source));
}

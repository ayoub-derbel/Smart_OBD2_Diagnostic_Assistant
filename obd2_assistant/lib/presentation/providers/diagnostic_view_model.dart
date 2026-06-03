import 'package:flutter/material.dart';

import '../../domain/agents/smart_diagnostic_agent.dart';

class DiagnosticViewModel extends ChangeNotifier {
  final SmartDiagnosticAgent _agent;

  DiagnosticViewModel(this._agent);

  bool _isScanning = false;
  String? _error;
  String? _reportText;

  bool get isScanning => _isScanning;
  String? get error => _error;
  String? get reportText => _reportText;

  bool get hasReport => _reportText != null && _reportText!.isNotEmpty;
  Map<String, dynamic>? get lastScanContext => _agent.lastScanContext;

  Future<void> loadActiveSession() async {
    final session = await _agent.getActiveSession();
    if (session == null) return;
    _reportText = session.report.rawText;
    _error = null;
    notifyListeners();
  }

  Future<void> runFullDiagnostic() async {
    _isScanning = true;
    _error = null;
    _reportText = null;
    notifyListeners();

    try {
      _reportText = await _agent.performFullScan();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> reset() async {
    _isScanning = false;
    _error = null;
    _reportText = null;
    await _agent.clearHistory();
    notifyListeners();
  }
}

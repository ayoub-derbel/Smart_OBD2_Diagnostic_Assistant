import 'package:flutter/material.dart';

import '../../domain/agents/diagnostic_agent.dart';
import '../../domain/entities/full_diagnostic_report.dart';

class FullDiagnosticViewModel extends ChangeNotifier {
  final DiagnosticAgent _diagnosticAgent;

  FullDiagnosticViewModel(this._diagnosticAgent);

  bool _isLoading = false;
  String? _error;
  FullDiagnosticReport? _report;

  bool get isLoading => _isLoading;
  String? get error => _error;
  FullDiagnosticReport? get report => _report;

  Future<void> runDiagnostic() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _report = await _diagnosticAgent.runFullDiagnostic();
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
      _report = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _error = null;
    _report = null;
    notifyListeners();
  }
}

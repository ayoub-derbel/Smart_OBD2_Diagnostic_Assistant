import 'package:flutter/material.dart';

import '../../domain/agents/smart_diagnostic_agent.dart';
import '../../domain/entities/scan_step.dart';
import '../../domain/entities/diagnostic_session.dart';

class DiagnosticViewModel extends ChangeNotifier {
  final SmartDiagnosticAgent _agent;

  DiagnosticViewModel(this._agent);

  bool _isScanning = false;
  String? _error;
  String? _reportText;
  ScanStep? _currentStep;
  String? _userNote;

  bool get isScanning => _isScanning;
  String? get error => _error;
  String? get reportText => _reportText;
  ScanStep? get currentStep => _currentStep;
  String? get userNote => _userNote;

  bool get hasReport => _reportText != null && _reportText!.isNotEmpty;
  Map<String, dynamic>? get lastScanContext => _agent.lastScanContext;
  DateTime? get lastScanDate => _agent.lastScanDate;

  Future<void> loadActiveSession() async {
    final session = await _agent.getActiveSession();
    if (session == null) return;
    _reportText = session.report.rawText;
    _error = null;
    notifyListeners();
  }

  Future<void> loadSession(DiagnosticSession session) async {
    await _agent.loadSession(session.id);
    _reportText = session.report.rawText;
    _error = null;
    notifyListeners();
  }

  Future<void> runFullDiagnostic({String? userNote}) async {
    _isScanning = true;
    _error = null;
    _reportText = null;
    _currentStep = ScanStep.connectingObd;
    _userNote = userNote;
    notifyListeners();

    try {
      _reportText = await _agent.performFullScan(
        userNote: userNote,
        onStepChanged: (step) {
          _currentStep = step;
          notifyListeners();
        },
      );
      _currentStep = ScanStep.done;
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
    _currentStep = null;
    _userNote = null;
    await _agent.clearHistory();
    notifyListeners();
  }
}

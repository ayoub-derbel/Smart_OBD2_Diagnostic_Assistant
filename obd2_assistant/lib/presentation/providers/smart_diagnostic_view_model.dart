import 'package:flutter/material.dart';
import '../../domain/agents/smart_diagnostic_agent.dart';
import '../../domain/entities/full_diagnostic_report.dart';
import '../../domain/entities/chat_message.dart';

class SmartDiagnosticViewModel extends ChangeNotifier {
  final SmartDiagnosticAgent _agent;

  SmartDiagnosticViewModel(this._agent);

  bool _isScanning = false;
  bool _isAsking = false;
  String? _error;
  
  // Suggestions initiales (Verticales)
  List<String> _suggestions = [
    "🚀 Faire un Diagnostic complet", 
    "❓ Comment ça marche ?", 
    "ℹ️ Aide"
  ];

  List<ChatMessage> _chatHistory = [
    ChatMessage(
      role: MessageRole.assistant, 
      content: "Bonjour ! Je suis votre assistant intelligent OBD2. Comment puis-je vous aider aujourd'hui ?"
    )
  ];

  bool get isScanning => _isScanning;
  bool get isAsking => _isAsking;
  String? get error => _error;
  List<ChatMessage> get chatHistory => _chatHistory;
  List<String> get suggestions => _suggestions;

  Future<void> _updateHistory() async {
    final history = await _agent.chatHistory;
    if (history.isNotEmpty) {
      _chatHistory = history;
    }
    notifyListeners();
  }

  /// Phase unique: Diagnostic et Chat via le même flux
  Future<void> runFullDiagnostic() async {
    _isScanning = true;
    _error = null;
    _suggestions = [];
    notifyListeners();

    try {
      await _agent.performFullScan();
      await _updateHistory();
      _generateDynamicSuggestions();
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void _generateDynamicSuggestions() {
    _suggestions = [
      "🤔 Est-ce grave ?",
      "💰 Coût des réparations ?",
      "🛣️ Puis-je rouler ?",
      "🛠️ Conseils d'entretien"
    ];
  }

  /// Phase 2: Ask a question or trigger action
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Détection de l'action de diagnostic
    if (text.contains("Diagnostic complet")) {
      await runFullDiagnostic();
      return;
    }
    
    _isAsking = true;
    notifyListeners();

    try {
      await _agent.askQuestion(text);
      await _updateHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isAsking = false;
      notifyListeners();
    }
  }

  void reset() {
    _error = null;
    _suggestions = [
      "🚀 Faire un Diagnostic complet", 
      "❓ Comment ça marche ?", 
      "ℹ️ Aide"
    ];
    _chatHistory = [
      ChatMessage(
        role: MessageRole.assistant, 
        content: "Bonjour ! Je suis votre assistant intelligent OBD2. Comment puis-je vous aider aujourd'hui ?"
      )
    ];
    notifyListeners();
  }
}

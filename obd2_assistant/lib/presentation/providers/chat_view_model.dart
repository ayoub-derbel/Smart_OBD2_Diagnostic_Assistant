import 'dart:convert';

import 'package:flutter/material.dart';
import '../../domain/agents/smart_diagnostic_agent.dart';
import '../../domain/entities/chat_message.dart';

class ChatViewModel extends ChangeNotifier {
  final SmartDiagnosticAgent _agent;

  ChatViewModel(this._agent);

  bool _isAsking = false;
  String? _error;
  List<ChatMessage> _chatHistory = [];

  bool get isAsking => _isAsking;
  String? get error => _error;
  List<ChatMessage> get chatHistory => _chatHistory;

  Future<void> updateHistory() async {
    final history = await _agent.chatHistory;
    _chatHistory = history.where(_isVisibleChatMessage).toList();
    notifyListeners();
  }

  bool _isVisibleChatMessage(ChatMessage message) {
    final content = message.content?.trim();
    if (content == null ||
        content.isEmpty ||
        message.role == MessageRole.tool) {
      return false;
    }

    if (message.role == MessageRole.user &&
        content.toLowerCase() == 'faire un diagnostic complet') {
      return false;
    }

    if (message.role == MessageRole.assistant && _isDiagnosticReport(content)) {
      return false;
    }

    return true;
  }

  bool _isDiagnosticReport(String content) {
    final jsonReport = _tryDecodeJsonMap(content);
    if (jsonReport != null) {
      return jsonReport.containsKey('overview') ||
          jsonReport.containsKey('repair_plan') ||
          jsonReport.containsKey('safety') ||
          jsonReport.containsKey('safety_status') ||
          jsonReport.containsKey('dtcs') ||
          jsonReport.containsKey('detected_dtcs') ||
          jsonReport.containsKey('causes') ||
          jsonReport.containsKey('probable_causes');
    }

    final normalized = content.toLowerCase();
    final hasSafety =
        normalized.contains('safety:') ||
        normalized.contains('securite:') ||
        normalized.contains('sÃ©curitÃ©:');
    final hasIssue =
        normalized.contains('issue:') ||
        normalized.contains('probleme:') ||
        normalized.contains('problÃ¨me:');
    final hasRepair =
        normalized.contains('repair:') ||
        normalized.contains('reparation:') ||
        normalized.contains('rÃ©paration:');
    final hasUrgency =
        normalized.contains('urgency:') || normalized.contains('urgence:');
    return hasSafety && hasIssue && (hasRepair || hasUrgency);
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String content) {
    try {
      var jsonText = content.trim();
      if (jsonText.contains('```json')) {
        final start = jsonText.indexOf('```json') + 7;
        final end = jsonText.lastIndexOf('```');
        if (end > start) jsonText = jsonText.substring(start, end).trim();
      } else if (jsonText.contains('{')) {
        final start = jsonText.indexOf('{');
        final end = jsonText.lastIndexOf('}');
        if (end > start) jsonText = jsonText.substring(start, end + 1).trim();
      }

      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> initWithContext(Map<String, dynamic>? scanContext) async {
    await updateHistory();
  }

  Future<void> sendMessage(String text) async {
    final messageText = text.trim();
    if (messageText.isEmpty || _isAsking) return;

    _isAsking = true;
    _error = null;
    _chatHistory = [
      ..._chatHistory,
      ChatMessage(role: MessageRole.user, content: messageText),
    ];
    notifyListeners();

    try {
      await _agent.askQuestion(messageText);
      await updateHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isAsking = false;
      notifyListeners();
    }
  }

  Future<void> reset() async {
    _isAsking = false;
    _error = null;
    _chatHistory = [];
    notifyListeners();
  }
}

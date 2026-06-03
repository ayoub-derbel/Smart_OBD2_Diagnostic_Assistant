import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_history_repository.dart';

class ChatHistoryRepositoryImpl implements ChatHistoryRepository {
  static const String _keyPrefix = 'active_chat_history_';

  String _keyFor(String sessionId) => '$_keyPrefix$sessionId';

  @override
  Future<void> saveMessage({
    required String sessionId,
    required ChatMessage message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(sessionId);
    final existing = prefs.getStringList(key) ?? [];

    final visibleMessage = ChatMessage(
      sessionId: sessionId,
      role: message.role,
      content: message.content,
      timestamp: message.timestamp,
    );

    await prefs.setStringList(key, [...existing, visibleMessage.encode()]);
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawMessages = prefs.getStringList(_keyFor(sessionId)) ?? [];
    return rawMessages
        .map((raw) {
          try {
            return ChatMessage.decode(raw);
          } catch (_) {
            return null;
          }
        })
        .whereType<ChatMessage>()
        .where((message) =>
            message.sessionId == null || message.sessionId == sessionId)
        .toList();
  }

  @override
  Future<void> clearSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(sessionId));
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

import '../entities/chat_message.dart';

abstract class ChatHistoryRepository {
  Future<void> saveMessage({
    required String sessionId,
    required ChatMessage message,
  });
  Future<List<ChatMessage>> getMessages(String sessionId);
  Future<void> clearSession(String sessionId);
  Future<void> clearAll();
}

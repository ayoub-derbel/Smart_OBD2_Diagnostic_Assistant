import '../entities/chat_message.dart';

abstract class ChatHistoryRepository {
  Future<void> saveMessage(ChatMessage message);
  Future<List<ChatMessage>> getMessages();
  Future<void> clearHistory();
}

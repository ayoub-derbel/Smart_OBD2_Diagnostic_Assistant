import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_history_repository.dart';

class ChatHistoryRepositoryImpl implements ChatHistoryRepository {
  final List<ChatMessage> _cache = [];

  @override
  Future<void> clearHistory() async {
    _cache.clear();
  }

  @override
  Future<List<ChatMessage>> getMessages() async {
    return List.from(_cache);
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    _cache.add(message);
  }
}

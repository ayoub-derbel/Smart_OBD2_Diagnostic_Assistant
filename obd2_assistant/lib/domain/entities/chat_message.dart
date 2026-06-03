import 'dart:convert';

enum MessageRole { user, assistant, system, tool }

class ChatMessage {
  final String? sessionId;
  final MessageRole role;
  final String? content;
  final DateTime timestamp;

  ChatMessage({
    this.sessionId,
    required this.role,
    this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'role': role.name,
    'content': content,
    'createdAt': timestamp.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    sessionId: json['sessionId']?.toString(),
    role: MessageRole.values.firstWhere(
      (role) => role.name == json['role'],
      orElse: () => MessageRole.assistant,
    ),
    content: json['content']?.toString(),
    timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
  );

  static ChatMessage decode(String source) =>
      ChatMessage.fromJson(jsonDecode(source));

  Map<String, dynamic> toApiJson() => {
    'role': role.name,
    'content': content ?? '',
  };
}

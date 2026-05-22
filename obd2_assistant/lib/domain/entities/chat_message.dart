enum MessageRole { user, assistant, system, tool }

class ChatMessage {
  final MessageRole role;
  final String? content;
  final DateTime timestamp;
  
  // Nouveaux champs pour le Function Calling
  final List<dynamic>? toolCalls; // Pour l'assistant qui demande l'outil
  final String? toolCallId;       // Pour le tool qui répond
  final String? name;             // Pour identifier le tool

  ChatMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiJson() {
    final map = <String, dynamic>{
      'role': role.name,
    };
    
    // Pour un message tool, le content doit toujours être une chaîne, même vide
    if (content != null || role == MessageRole.tool) {
      map['content'] = content ?? "";
    } else {
      map['content'] = null; // Important pour l'assistant qui appelle l'outil (content doit être null)
    }

    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] = toolCalls;
    }
    if (toolCallId != null) {
      map['tool_call_id'] = toolCallId;
    }
    if (name != null) {
      map['name'] = name;
    }

    return map;
  }
}


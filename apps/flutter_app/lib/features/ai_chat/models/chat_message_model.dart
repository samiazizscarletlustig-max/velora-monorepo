enum MessageRole { user, model }

class Citation {
  final String title;
  final String url;

  const Citation({
    required this.title,
    required this.url,
  });
}

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final List<Citation> citations;
  final bool isThinking;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.citations = const [],
    this.isThinking = false,
  });
  
  ChatMessage copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    List<Citation>? citations,
    bool? isThinking,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      citations: citations ?? this.citations,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}

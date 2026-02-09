class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;
  final String? language;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.language,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'language': language,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      language: json['language'],
    );
  }

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Message>? messages,
    String? language,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      language: language ?? this.language,
    );
  }
}

class Message {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  Message({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ConversationInsights {
  final String summary;
  final List<String> topics;
  final String userIntent;
  final String conversationTone;

  ConversationInsights({
    required this.summary,
    required this.topics,
    required this.userIntent,
    required this.conversationTone,
  });

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'topics': topics,
      'userIntent': userIntent,
      'conversationTone': conversationTone,
    };
  }

  factory ConversationInsights.fromJson(Map<String, dynamic> json) {
    return ConversationInsights(
      summary: json['summary'],
      topics: List<String>.from(json['topics']),
      userIntent: json['userIntent'],
      conversationTone: json['conversationTone'],
    );
  }
}

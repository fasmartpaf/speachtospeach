import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';

class ConversationService {
  static const String _conversationsKey = 'conversations';
  static const int _maxHistoryMessages = 30; // Keep last 30 messages for context

  /// Get all conversations
  Future<List<Conversation>> getAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final conversationsJson = prefs.getStringList(_conversationsKey) ?? [];
    
    return conversationsJson
        .map((json) => Conversation.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Most recent first
  }

  /// Get a specific conversation by ID
  Future<Conversation?> getConversation(String id) async {
    final conversations = await getAllConversations();
    try {
      return conversations.firstWhere((conv) => conv.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new conversation
  Future<Conversation> createConversation({String? title, String? language}) async {
    final conversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Conversation ${DateTime.now().day}/${DateTime.now().month}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
      language: language,
    );

    await _saveConversation(conversation);
    return conversation;
  }

  /// Add a message to a conversation
  Future<void> addMessage(String conversationId, Message message) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null) return;

    final updatedMessages = [...conversation.messages, message];
    
    // Trim history to keep only last N messages
    final trimmedMessages = updatedMessages.length > _maxHistoryMessages
        ? updatedMessages.sublist(updatedMessages.length - _maxHistoryMessages)
        : updatedMessages;

    final updatedConversation = conversation.copyWith(
      messages: trimmedMessages,
      updatedAt: DateTime.now(),
    );

    await _saveConversation(updatedConversation);
  }

  /// Get conversation history for OpenAI (formatted as OpenAI messages)
  Future<List<Map<String, String>>> getConversationHistory(String conversationId) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null) return [];

    // Convert to OpenAI format: [{'role': 'user', 'content': '...'}, ...]
    return conversation.messages
        .map((msg) => {
              'role': msg.role,
              'content': msg.content,
            })
        .toList();
  }

  /// Update conversation title
  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null) return;

    final updated = conversation.copyWith(title: newTitle);
    await _saveConversation(updated);
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    final conversations = await getAllConversations();
    final updated = conversations.where((c) => c.id != conversationId).toList();
    await _saveAllConversations(updated);
  }

  /// Generate conversation insights
  Future<ConversationInsights> generateInsights(String conversationId) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null || conversation.messages.isEmpty) {
      return ConversationInsights(
        summary: 'No conversation history available.',
        topics: [],
        userIntent: 'Unknown',
        conversationTone: 'Neutral',
      );
    }

    // This will be called from AI service to generate insights
    // For now, return basic insights
    final topics = _extractTopics(conversation.messages);
    
    return ConversationInsights(
      summary: 'Conversation with ${conversation.messages.length} messages.',
      topics: topics,
      userIntent: 'General conversation',
      conversationTone: conversation.language?.startsWith('ur') == true ? 'Polite' : 'Casual',
    );
  }

  List<String> _extractTopics(List<Message> messages) {
    // Simple topic extraction - can be enhanced with AI
    final topics = <String>[];
    final content = messages.map((m) => m.content.toLowerCase()).join(' ');
    
    if (content.contains('weather') || content.contains('موسم')) {
      topics.add('Weather');
    }
    if (content.contains('health') || content.contains('صحت')) {
      topics.add('Health');
    }
    if (content.contains('help') || content.contains('مدد')) {
      topics.add('Help');
    }
    
    return topics.isEmpty ? ['General'] : topics;
  }

  /// Save a conversation
  Future<void> _saveConversation(Conversation conversation) async {
    final conversations = await getAllConversations();
    final existingIndex = conversations.indexWhere((c) => c.id == conversation.id);
    
    if (existingIndex >= 0) {
      conversations[existingIndex] = conversation;
    } else {
      conversations.add(conversation);
    }

    await _saveAllConversations(conversations);
  }

  /// Save all conversations
  Future<void> _saveAllConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final conversationsJson = conversations
        .map((conv) => jsonEncode(conv.toJson()))
        .toList();
    await prefs.setStringList(_conversationsKey, conversationsJson);
  }
}

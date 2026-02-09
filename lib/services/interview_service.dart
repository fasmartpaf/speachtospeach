import 'package:shared_preferences/shared_preferences.dart';
import '../models/running_models.dart';
import 'ai_service.dart';
import 'tts_service_wrapper.dart';
import 'backend_service.dart';

/// Service for managing dynamic AI-driven interview
class InterviewService {
  final AIService _aiService = AIService();
  final TTSServiceWrapper _ttsService = TTSServiceWrapper();
  final BackendService _backendService = BackendService();

  List<Map<String, String>> _conversationHistory = [];
  Map<String, dynamic> _extractedData = {};
  bool _isComplete = false;

  List<Map<String, String>> get conversationHistory => List.unmodifiable(_conversationHistory);
  Map<String, dynamic> get extractedData => Map.unmodifiable(_extractedData);
  bool get isComplete => _isComplete;

  /// Start the interview with an initial greeting/question
  Future<String> startInterview({
    required Future<void> Function(String) onQuestion,
    required Function(String) onError,
  }) async {
    _conversationHistory = [];
    _extractedData = {};
    _isComplete = false;

    final systemPrompt = '''You are a friendly running coach conducting an interview to understand a runner's goals, experience, and preferences.

Your role:
1. Ask natural, conversational questions about their running goals, experience, training preferences, and availability
2. Make the conversation feel like a friendly chat, not a formal interview
3. Ask follow-up questions based on their answers
4. Extract key information: primary goal, weekly distance target, training events, recent race results, available days
5. When you have enough information, say "INTERVIEW_COMPLETE" to end the interview

Keep questions short (1-2 sentences max). Be warm and encouraging. Start with a friendly greeting and first question.''';

    try {
      final response = await _aiService.getAIResponse(
        'Start the interview with a friendly greeting and ask the first question about their running goals.',
        conversationHistory: [
          {'role': 'system', 'content': systemPrompt},
        ],
      );

      _conversationHistory.add({'role': 'assistant', 'content': response});
      onQuestion(response);
      return response;
    } catch (e) {
      print('Error starting interview: $e');
      onError('Failed to start interview. Please try again.');
      rethrow;
    }
  }

  /// Process user's answer and generate next question
  Future<String?> processAnswer(
    String userAnswer, {
    required Future<void> Function(String) onQuestion,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    if (_isComplete) {
      return null;
    }

    // Add user message to history FIRST (before processing)
    // This ensures AI has full context including current answer
    _conversationHistory.add({'role': 'user', 'content': userAnswer});

    final systemPrompt = '''You are an AI AGENT with full memory conducting a running coach interview.

CRITICAL MEMORY RULES - YOU MUST:
- Remember ALL previous questions you asked
- Remember ALL previous answers the user gave
- NEVER repeat a question you already asked
- NEVER ask "Could you repeat that?" or "I didn't catch that" - instead rephrase the question differently
- If user's answer is unclear, rephrase your question in a different way or break it into smaller parts
- Build on previous answers - ask NEW follow-up questions based on what they said
- Keep track of what information you've collected
- Review conversation history before asking each question

Your role:
1. Ask natural, conversational questions about their running goals, experience, training preferences, and availability
2. Make the conversation feel like a friendly chat, not a formal interview
3. Ask NEW follow-up questions based on their answers (NEVER repeat questions)
4. Extract key information: primary goal, weekly distance target, training events, recent race results, available days
5. When you have enough information, say "INTERVIEW_COMPLETE" to end the interview

Keep questions short (1-2 sentences max). Be warm and encouraging.
CRITICAL: If the user's answer is unclear or too short, rephrase your question in a different way. Don't ask them to repeat - just ask it differently or more specifically.
If you have all the information you need, say "INTERVIEW_COMPLETE".''';

    try {
      // Build full conversation history with system prompt
      final fullHistory = [
        {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory, // Includes all previous Q&A + current user answer
      ];
      
      // Get AI response with FULL conversation context
      final response = await _aiService.getAIResponse(
        userAnswer,
        conversationHistory: fullHistory,
      );

      // Check if interview is complete
      if (response.toUpperCase().contains('INTERVIEW_COMPLETE')) {
        _isComplete = true;
        await _extractStructuredData();
        await _saveProfile();
        onComplete();
        return null;
      }

      // Add AI response to history
      _conversationHistory.add({'role': 'assistant', 'content': response});
      await onQuestion(response);
      return response;
    } catch (e) {
      print('Error processing answer: $e');
      onError('Failed to process answer. Please try again.');
      return null;
    }
  }

  /// Extract structured data from conversation
  Future<void> _extractStructuredData() async {
    try {
      final extractionPrompt = '''Extract structured data from this conversation:

${_conversationHistory.map((m) => '${m['role']}: ${m['content']}').join('\n')}

Extract:
- primaryGoal: Main running goal (string)
- kilometersPerWeek: Weekly distance target (integer, default 5 if not mentioned)
- trainingEvent: Specific event training for (string or null)
- recentRaceResult: Recent race distance and time (string or null)
- availableDays: Days of week available (list of strings like ["Monday", "Wednesday"])

Return JSON format only, no other text.''';

      final response = await _aiService.getAIResponse(extractionPrompt);
      
      // Parse JSON response (simplified - in production use proper JSON parsing)
      // For now, extract key fields from conversation
      _extractedData = _parseExtractedData(response);
    } catch (e) {
      print('Error extracting data: $e');
      // Use fallback extraction
      _extractedData = _extractFromConversation();
    }
  }

  /// Parse extracted data from AI response
  Map<String, dynamic> _parseExtractedData(String response) {
    final data = <String, dynamic>{};
    
    // Try to extract JSON (simplified parsing)
    try {
      // Look for primaryGoal pattern
      final primaryGoalPattern = 'primaryGoal';
      final primaryGoalPatternAlt = 'primary_goal';
      if (response.contains(primaryGoalPattern) || response.contains(primaryGoalPatternAlt)) {
        // Simplified regex pattern
        final regexPattern = 'primaryGoal\\s*:\\s*["\']([^"\']+)["\']';
        final regex = RegExp(regexPattern, caseSensitive: false);
        final match = regex.firstMatch(response);
        if (match != null) {
          final group1 = match.group(1);
          if (group1 != null && group1.isNotEmpty) {
            data['primaryGoal'] = group1;
          }
        }
      }
      
      // Look for kilometersPerWeek pattern
      final kmPattern = 'kilometersPerWeek';
      final kmPatternAlt = 'kilometers_per_week';
      if (response.contains(kmPattern) || response.contains(kmPatternAlt)) {
        // Simplified regex pattern
        final regexPatternStr = 'kilometersPerWeek\\s*:\\s*(\\d+)';
        final regex = RegExp(regexPatternStr, caseSensitive: false);
        final match = regex.firstMatch(response);
        if (match != null) {
          final group1 = match.group(1);
          if (group1 != null) {
            data['kilometersPerWeek'] = int.tryParse(group1) ?? 5;
          }
        }
      }
    } catch (e) {
      print('Error parsing extracted data: $e');
    }
    
    // Fallback to conversation extraction if no data found
    if (data.isEmpty) {
      return _extractFromConversation();
    }
    
    return data;
  }

  /// Extract data directly from conversation history
  Map<String, dynamic> _extractFromConversation() {
    final data = <String, dynamic>{
      'primaryGoal': 'General fitness',
      'kilometersPerWeek': 5,
      'trainingEvent': null,
      'recentRaceResult': null,
      'availableDays': [],
    };

    // Extract from user messages
    for (final msg in _conversationHistory) {
      if (msg['role'] == 'user') {
        final content = msg['content']?.toLowerCase() ?? '';
        
        // Extract goal
        if (content.contains('goal') || content.contains('want to')) {
          data['primaryGoal'] = msg['content'];
        }
        
        // Extract kilometers
        final kmMatch = RegExp(r'(\d+)\s*(?:km|kilometer|kilometre)', caseSensitive: false).firstMatch(content);
        if (kmMatch != null) {
          data['kilometersPerWeek'] = int.tryParse(kmMatch.group(1) ?? '5') ?? 5;
        }
        
        // Extract days
        final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        final mentionedDays = days.where((day) => content.contains(day)).toList();
        if (mentionedDays.isNotEmpty) {
          data['availableDays'] = mentionedDays.map((d) => d.substring(0, 1).toUpperCase() + d.substring(1)).toList();
        }
      }
    }

    return data;
  }

  /// Save user profile with extracted data
  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) return;

      final profile = UserProfile(
        id: userId,
        primaryGoal: _extractedData['primaryGoal'] as String? ?? 'General fitness',
        trainingEvent: _extractedData['trainingEvent'] as String?,
        recentRaceResult: null, // Can be parsed from string if needed
        availableDays: (_extractedData['availableDays'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _backendService.saveUserProfile(profile);
    } catch (e) {
      print('Error saving profile: $e');
    }
  }

  /// Add user message to conversation history
  void addUserMessage(String message) {
    _conversationHistory.add({'role': 'user', 'content': message});
  }
  
  /// Get conversation summary for analytics
  String getConversationSummary() {
    return _conversationHistory
        .map((m) => '${m['role'] == 'user' ? 'User' : 'Coach'}: ${m['content']}')
        .join('\n\n');
  }
}

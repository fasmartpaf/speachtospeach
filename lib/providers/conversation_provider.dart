import 'package:flutter/foundation.dart';
import '../models/app_state.dart';
import '../models/conversation.dart';
import '../services/speech_service.dart';
import '../services/tts_service_wrapper.dart';
import '../services/ai_service.dart';
import '../services/conversation_service.dart';

class ConversationProvider with ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  final TTSServiceWrapper _ttsService = TTSServiceWrapper();
  final AIService _aiService = AIService();
  final ConversationService _conversationService = ConversationService();
  
  bool _continuousMode = false; // Auto-listen after AI responds

  ConversationState _state = ConversationState();
  Conversation? _currentConversation;
  List<Conversation> _conversations = [];

  ConversationState get state => _state;
  bool get isListening => _speechService.isListening;
  bool get isSpeaking => _ttsService.isSpeaking;
  Conversation? get currentConversation => _currentConversation;
  List<Conversation> get conversations => _conversations;
  bool get continuousMode => _continuousMode;
  
  /// Toggle continuous listening mode
  void toggleContinuousMode() {
    _continuousMode = !_continuousMode;
    notifyListeners();
  }

  ConversationProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _speechService.initialize();
    await loadConversations();
    // Create default conversation if none exists
    if (_conversations.isEmpty) {
      await createNewConversation();
    } else {
      // Set most recent conversation as current
      _currentConversation = _conversations.first;
    }
    notifyListeners();
  }

  /// Load all conversations
  Future<void> loadConversations() async {
    _conversations = await _conversationService.getAllConversations();
    notifyListeners();
  }

  /// Create a new conversation
  Future<void> createNewConversation({String? language}) async {
    _currentConversation = await _conversationService.createConversation(
      language: language,
    );
    await loadConversations();
    notifyListeners();
  }

  /// Switch to a different conversation
  Future<void> switchConversation(String conversationId) async {
    _currentConversation = await _conversationService.getConversation(conversationId);
    // Reload conversations to get updated list
    await loadConversations();
    notifyListeners();
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    await _conversationService.deleteConversation(conversationId);
    await loadConversations();
    if (_currentConversation?.id == conversationId) {
      _currentConversation = _conversations.isNotEmpty ? _conversations.first : null;
      if (_currentConversation == null) {
        await createNewConversation();
      }
    }
    notifyListeners();
  }

  /// Start listening to user's voice
  Future<void> startListening() async {
    // First ensure speech service is initialized
    final isInitialized = await _speechService.initialize();
    
    if (!isInitialized) {
      _state = _state.copyWith(
        currentState: AppState.error,
        errorMessage: 'Microphone permission denied. Please enable microphone access in Settings.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      currentState: AppState.listening,
      errorMessage: null,
    );
    notifyListeners();

    await _speechService.startListening(
      onResult: (text) async {
        if (text.isNotEmpty) {
          await _processUserMessage(text);
        }
      },
      onError: () {
        _state = _state.copyWith(
          currentState: AppState.error,
          errorMessage: 'Failed to listen. Please check microphone permissions in Settings.',
        );
        notifyListeners();
      },
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    await _speechService.stopListening();
    if (_state.currentState == AppState.listening) {
      _state = _state.copyWith(currentState: AppState.idle);
      notifyListeners();
    }
  }

  /// Process user message and get AI response
  Future<void> _processUserMessage(String userMessage) async {
    // Ensure we have a current conversation
    if (_currentConversation == null) {
      await createNewConversation();
    }

    _state = _state.copyWith(
      userMessage: userMessage,
      currentState: AppState.processing,
    );
    notifyListeners();

    try {
      // Save user message to conversation
      final userMsg = Message(
        role: 'user',
        content: userMessage,
        timestamp: DateTime.now(),
      );
      await _conversationService.addMessage(_currentConversation!.id, userMsg);

      // Get conversation history for context
      final history = await _conversationService.getConversationHistory(
        _currentConversation!.id,
      );

      // Get AI response with conversation history
      final aiResponse = await _aiService.getAIResponse(
        userMessage,
        conversationHistory: history,
      );

      // Save AI response to conversation
      final aiMsg = Message(
        role: 'assistant',
        content: aiResponse,
        timestamp: DateTime.now(),
      );
      await _conversationService.addMessage(_currentConversation!.id, aiMsg);

      // Reload conversation to get updated messages
      _currentConversation = await _conversationService.getConversation(
        _currentConversation!.id,
      );

      // Detect language for TTS
      final languageCode = _aiService.detectLanguage(aiResponse);

      _state = _state.copyWith(
        aiResponse: aiResponse,
        currentState: AppState.speaking,
      );
      notifyListeners();

      // Speak the response immediately (removed delay for faster response)
      await _ttsService.speak(aiResponse, languageCode: languageCode);

      // Wait for TTS to finish naturally
      while (_ttsService.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 50)); // Reduced from 100ms
      }

      _state = _state.copyWith(currentState: AppState.idle);
      notifyListeners();

      // Auto-start listening in continuous mode
      if (_continuousMode) {
        // Reduced delay for faster response
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_ttsService.isSpeaking && _state.currentState == AppState.idle) {
          await startListening();
        }
      }
    } catch (e) {
      // Human-like error message
      final isUrdu = _aiService.detectLanguage(userMessage).startsWith('ur');
      _state = _state.copyWith(
        currentState: AppState.error,
        errorMessage: isUrdu 
            ? 'معذرت، دوبارہ کوشش کریں۔' 
            : 'Sorry, I didn\'t catch that. Could you say it again?',
      );
      notifyListeners();
    }
  }

  /// Replay the last AI response
  Future<void> replayResponse() async {
    if (_state.aiResponse != null) {
      final languageCode = _aiService.detectLanguage(_state.aiResponse!);
      _state = _state.copyWith(currentState: AppState.speaking);
      notifyListeners();

      // Speak immediately (removed delay for faster response)
      await _ttsService.speak(_state.aiResponse!, languageCode: languageCode);

      while (_ttsService.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 50)); // Reduced from 100ms
      }

      _state = _state.copyWith(currentState: AppState.idle);
      notifyListeners();

      // Auto-start listening in continuous mode
      if (_continuousMode) {
        // Reduced delay for faster response
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_ttsService.isSpeaking && _state.currentState == AppState.idle) {
          await startListening();
        }
      }
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    _state = _state.copyWith(currentState: AppState.idle);
    notifyListeners();
  }

  /// Reset conversation state
  void reset() {
    _state = ConversationState();
    notifyListeners();
  }
}

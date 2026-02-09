import 'package:shared_preferences/shared_preferences.dart';
import '../models/running_models.dart';
import 'ai_service.dart';
import 'elevenlabs_tts_service.dart';
import 'backend_service.dart';

class OnboardingService {
  final AIService _aiService = AIService();
  final ElevenLabsTTSService _ttsService = ElevenLabsTTSService();
  final BackendService _backendService = BackendService();

  final List<OnboardingQuestion> _questions = [
    OnboardingQuestion(
      id: 'primary_goal',
      question: 'What is your primary running goal right now?',
      questionUrdu: 'آپ کا بنیادی رننگ کا مقصد کیا ہے؟',
      field: 'primaryGoal',
    ),
    OnboardingQuestion(
      id: 'kilometers_per_week',
      question: 'How many kilometers do you want to run per week?',
      questionUrdu: 'آپ ہفتے میں کتنے کلومیٹر دوڑنا چاہتے ہیں؟',
      field: 'kilometersPerWeek',
    ),
    OnboardingQuestion(
      id: 'training_event',
      question: 'Is there a specific event you are training for?',
      questionUrdu: 'کیا آپ کسی خاص ایونٹ کے لیے ٹریننگ کر رہے ہیں؟',
      field: 'trainingEvent',
    ),
    OnboardingQuestion(
      id: 'recent_race',
      question: 'What is your most recent race result? Tell me the distance and time.',
      questionUrdu: 'آپ کا حالیہ ریس کا نتیجہ کیا تھا؟ فاصلہ اور وقت بتائیں۔',
      field: 'recentRaceResult',
    ),
    OnboardingQuestion(
      id: 'available_days',
      question: 'On which days of the week can you run?',
      questionUrdu: 'آپ ہفتے کے کون سے دن دوڑ سکتے ہیں؟',
      field: 'availableDays',
    ),
  ];

  int _currentQuestionIndex = 0;
  Map<String, dynamic> _answers = {};
  String? _detectedLanguage;

  List<OnboardingQuestion> get questions => _questions;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isComplete => _currentQuestionIndex >= _questions.length;
  Map<String, dynamic> get answers => Map.unmodifiable(_answers);

  /// Start onboarding interview
  Future<void> startOnboarding({
    required Function(String) onQuestion,
    required Function(String) onError,
  }) async {
    _currentQuestionIndex = 0;
    _answers = {};
    
    if (_questions.isNotEmpty) {
      await _askQuestion(_questions[0], onQuestion, onError);
    }
  }

  /// Process answer and move to next question
  Future<void> processAnswer(
    String answer, {
    required Function(String) onNextQuestion,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    print('OnboardingService.processAnswer called with: "$answer"');
    print('Current question index: $_currentQuestionIndex, Total questions: ${_questions.length}');
    
    if (_currentQuestionIndex >= _questions.length) {
      print('All questions answered, completing...');
      onComplete();
      return;
    }

    // Validate answer is not empty
    if (answer.trim().isEmpty || answer.trim().length < 3) {
      print('Answer too short: "${answer.trim()}"');
      onError('Answer too short. Please try again.');
      return;
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    print('Processing answer for question: ${currentQuestion.id}');
    _detectedLanguage = _aiService.detectLanguage(answer);

    // Extract structured data from answer using AI
    try {
      print('Extracting data from answer...');
      final extractedData = await _extractAnswerData(
        currentQuestion,
        answer,
      );
      
      print('Extracted data: $extractedData');
      
      // Validate extracted data is not null/empty
      if (extractedData == null || 
          (extractedData is String && extractedData.trim().isEmpty) ||
          (extractedData is List && extractedData.isEmpty)) {
        print('Extracted data is invalid, retrying...');
        onError('Could not understand your answer properly. Please try again.');
        return;
      }
      
      // Additional validation: Check if extracted data makes sense
      // For text fields, ensure it's not just random words
      if (extractedData is String) {
        final extractedText = extractedData.trim();
        // If extracted text is too short or seems invalid, reject it
        if (extractedText.length < 3 || extractedText.toLowerCase() == 'none' || extractedText.toLowerCase() == 'no') {
          // For some questions, "none" or "no" might be valid, but check context
          if (currentQuestion.id == 'training_event' && extractedText.toLowerCase() == 'none') {
            // "none" is valid for training_event
          } else if (extractedText.length < 3) {
            print('Extracted text too short or invalid: "$extractedText"');
            onError('Your answer is not clear enough. Please try again.');
            return;
          }
        }
      }

      _answers[currentQuestion.field] = extractedData;
      print('Answer saved for field: ${currentQuestion.field}');

      // Only move to next question if current one is answered
      _currentQuestionIndex++;
      print('Moved to question index: $_currentQuestionIndex');

      if (_currentQuestionIndex < _questions.length) {
        print('Asking next question...');
        await _askQuestion(
          _questions[_currentQuestionIndex],
          onNextQuestion,
          onError,
        );
      } else {
        // Onboarding complete
        print('All questions answered, saving profile...');
        await _saveProfile();
        onComplete();
      }
    } catch (e) {
      print('Error in processAnswer: $e');
      print('Stack trace: ${StackTrace.current}');
      onError('Failed to process answer. Please try again.');
    }
  }

  /// Ask a question using TTS
  Future<void> _askQuestion(
    OnboardingQuestion question,
    Function(String) onQuestion,
    Function(String) onError,
  ) async {
    try {
      final languageCode = _detectedLanguage ?? 'en-US';
      final questionText = languageCode.startsWith('ur')
          ? question.questionUrdu
          : question.question;

      // Stop any existing TTS before asking new question
      _ttsService.stop();
      
      // Call onQuestion callback (this will trigger TTS in provider)
      onQuestion(questionText);
      
      // Don't speak here - let the provider handle TTS to avoid duplicate
    } catch (e) {
      onError('Failed to ask question. Please try again.');
    }
  }

  /// Extract structured data from user's voice answer
  Future<dynamic> _extractAnswerData(
    OnboardingQuestion question,
    String answer,
  ) async {
    try {
      print('_extractAnswerData: Starting extraction for question ${question.id}');
      print('Answer: "$answer"');
      
      // For simple text fields, use answer directly if AI fails
      if (question.id == 'primary_goal' || question.id == 'training_event') {
        // Try AI extraction first, but fallback to raw answer
        try {
          final extractionPrompt = _getExtractionPrompt(question, answer);
          print('Extraction prompt: "$extractionPrompt"');
          
          print('Calling AI service with timeout...');
          final extracted = await _aiService.getAIResponse(
            extractionPrompt,
            conversationHistory: [],
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('AI extraction timeout, using raw answer');
              return answer.trim();
            },
          );
          
          print('AI response: "$extracted"');
          final parsed = _parseExtractedData(question, extracted);
          print('Parsed data: $parsed');
          
          // If parsed is null/empty, use raw answer
          if (parsed == null || (parsed is String && parsed.trim().isEmpty)) {
            print('Parsed data is empty, using raw answer');
            return answer.trim();
          }
          
          return parsed;
        } catch (e) {
          print('AI extraction failed: $e, using raw answer');
          return answer.trim();
        }
      }
      
      // For other fields, use AI extraction
      final extractionPrompt = _getExtractionPrompt(question, answer);
      print('Extraction prompt: "$extractionPrompt"');
      
      print('Calling AI service...');
      final extracted = await _aiService.getAIResponse(
        extractionPrompt,
        conversationHistory: [],
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('AI extraction timeout');
          // Return fallback based on question type
          if (question.id == 'kilometers_per_week') {
            return '5'; // Default
          }
          return answer.trim();
        },
      );
      
      print('AI response: "$extracted"');
      final parsed = _parseExtractedData(question, extracted);
      print('Parsed data: $parsed');
      
      return parsed;
    } catch (e) {
      print('Error extracting data: $e');
      print('Stack trace: ${StackTrace.current}');
      // Return fallback based on question type
      if (question.id == 'primary_goal' || question.id == 'training_event') {
        return answer.trim(); // Use raw answer for text fields
      } else if (question.id == 'kilometers_per_week') {
        return 5; // Default
      }
      return null;
    }
  }

  String _getExtractionPrompt(OnboardingQuestion question, String answer) {
    switch (question.id) {
      case 'primary_goal':
        return 'Extract the primary running goal from this answer. Return only the goal in one short sentence: $answer';
      case 'kilometers_per_week':
        return 'Extract the number of kilometers per week from this answer. Return only the number (e.g., "20" or "30"): $answer';
      case 'training_event':
        return 'Extract the training event name from this answer. Return only the event name or "none": $answer';
      case 'recent_race':
        return 'Extract race distance (in km) and time (in format "HH:MM:SS" or minutes) from: $answer. Return as JSON: {"distance": X, "time_seconds": Y}';
      case 'available_days':
        return 'Extract days of the week from this answer. Return as comma-separated list (Monday, Tuesday, etc.): $answer';
      default:
        return answer;
    }
  }

  dynamic _parseExtractedData(OnboardingQuestion question, String extracted) {
    switch (question.id) {
      case 'primary_goal':
      case 'training_event':
        return extracted.trim();
      case 'recent_race':
        // Try to parse JSON or extract manually
        try {
          // Simple extraction - can be enhanced
          return extracted; // Will be parsed properly later
        } catch (e) {
          return null;
        }
      case 'kilometers_per_week':
        // Extract number from text - handle various formats
        try {
          print('Parsing kilometers from: "$extracted"');
          // Try to parse as integer first
          final numberMatch = RegExp(r'\d+').firstMatch(extracted);
          if (numberMatch != null) {
            final number = int.tryParse(numberMatch.group(0) ?? '0');
            print('Found number: $number');
            if (number != null && number > 0) {
              return number;
            }
          }
          // If no number found, try to extract from original answer as fallback
          print('No number found in extracted text, trying original answer...');
          final fallbackMatch = RegExp(r'\d+').firstMatch(extracted);
          if (fallbackMatch != null) {
            final fallbackNumber = int.tryParse(fallbackMatch.group(0) ?? '0');
            if (fallbackNumber != null && fallbackNumber > 0) {
              print('Using fallback number: $fallbackNumber');
              return fallbackNumber;
            }
          }
          // If still no number, return a default value instead of null
          print('No number found, returning default 5');
          return 5; // Default to 5 km per week
        } catch (e) {
          print('Error parsing kilometers: $e');
          return 5; // Default fallback
        }
      case 'available_days':
        return extracted.split(',').map((d) => d.trim()).toList();
      default:
        return extracted;
    }
  }

  /// Save user profile to backend
  Future<void> _saveProfile() async {
    try {
      // Get user ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Save user ID if not already saved
      if (prefs.getString('user_id') == null) {
        await prefs.setString('user_id', userId);
      }

      final profile = UserProfile(
        id: userId,
        primaryGoal: _answers['primaryGoal'] as String?,
        trainingEvent: _answers['trainingEvent'] as String?,
        recentRaceResult: _answers['recentRaceResult'] as RaceResult?,
        availableDays: (_answers['availableDays'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _backendService.saveUserProfile(profile);
      
      // Mark onboarding as complete
      await prefs.setBool('hasSeenOnboarding', true);
    } catch (e) {
      // Handle error
      print('Failed to save profile: $e');
    }
  }

  /// Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    return await _backendService.getUserProfile(userId);
  }
}

class OnboardingQuestion {
  final String id;
  final String question;
  final String questionUrdu;
  final String field;

  OnboardingQuestion({
    required this.id,
    required this.question,
    required this.questionUrdu,
    required this.field,
  });
}

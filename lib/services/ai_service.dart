import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'weather_service.dart';

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  final WeatherService _weatherService = WeatherService();

  String get _apiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
    return key;
  }

  /// Send user message to OpenAI with conversation history
  Future<String> getAIResponse(
    String userMessage, {
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      // Detect input language for tone adaptation
      final isUrdu = _isUrdu(userMessage);
      
      // Check if the message is about weather
      final isWeatherQuery = _isWeatherQuery(userMessage);
      
      // Layer 1: System Instruction - Running Trainer Personality
      String systemPrompt = isUrdu
          ? '''آپ ایک دوستانہ رننگ ٹرینر ہیں جو اردو میں بات کر رہے ہیں۔
بہت قدرتی، گرم جوشی سے، اور حوصلہ افزائی کرنے والے انداز میں بات کریں۔
بہت سادہ، روزمرہ کی زبان استعمال کریں۔
صرف 1-2 جملے میں جواب دیں، بہت مختصر۔
کبھی بھی یہ نہ کہیں کہ آپ AI ہیں۔ ایک مددگار رننگ کوچ کی طرح بات کریں۔
رننگ کے بارے میں مشورہ دیں، حوصلہ افزائی کریں، اور دوستانہ رہیں۔
پرسکون اور مطمئن کرنے والے انداز میں بات کریں۔'''
          : '''You are a friendly running trainer and coach.
Speak very naturally, warmly, and encouragingly like a real running coach would.
Use very simple, everyday language.
Keep responses to just 1-2 sentences, very short.
Never mention you are an AI. Talk like a helpful running coach.
Provide running advice, encouragement, and motivation.
Be calm, reassuring, and natural.
Talk like a supportive running buddy or coach.''';

      // Layer 2: Response Style Rules
      String styleRules = '''
CRITICAL RULES:
- Maximum 3 sentences
- Use daily conversation style
- No phrases like "As an AI", "I am an AI assistant", "Based on data"
- Vary your phrasing naturally
- Keep tone calm and neutral-friendly
- If asked about weather, speak simply and naturally''';

      // If it's a weather query, get weather data first
      String userPrompt = userMessage;
      if (isWeatherQuery) {
        final weatherData = await _weatherService.getWeatherByCity('Karachi');
        if (weatherData != null) {
          final weatherInfo = _weatherService.formatWeatherDescription(weatherData);
          userPrompt = '$userMessage\n\nCurrent weather: $weatherInfo';
        }
      }

      final url = Uri.parse('$_baseUrl/chat/completions');

      // Build messages array with history
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': '$systemPrompt\n\n$styleRules'},
      ];

      // Add conversation history if provided
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        messages.addAll(conversationHistory);
      }

      // Add current user message
      messages.add({'role': 'user', 'content': userPrompt});

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': messages,
          'max_tokens': 60, // Very short for natural, human-like responses
          'temperature': 0.9, // Higher for more natural variation and human-like phrasing
        }),
      ).timeout(
        const Duration(seconds: 10), // Timeout for faster failure handling
        onTimeout: () {
          throw Exception('AI response timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String responseText = data['choices'][0]['message']['content'].trim();
        
        // Clean up any AI-like phrases that might slip through
        responseText = _cleanAIReferences(responseText);
        
        return responseText;
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        return isUrdu 
            ? 'معذرت، دوبارہ کوشش کریں۔' 
            : 'Sorry, I didn\'t catch that. Could you say it again?';
      }
    } catch (e) {
      print('AI Service Error: $e');
      final isUrdu = _isUrdu(userMessage);
      return isUrdu 
          ? 'معذرت، دوبارہ کوشش کریں۔' 
          : 'Sorry, I didn\'t catch that. Could you say it again?';
    }
  }

  /// Remove any AI references from response
  String _cleanAIReferences(String text) {
    // Remove common AI-like phrases
    final aiPhrases = [
      'As an AI',
      'I am an AI',
      'I\'m an AI',
      'As an artificial intelligence',
      'Based on the data',
      'According to my knowledge',
    ];
    
    String cleaned = text;
    for (var phrase in aiPhrases) {
      cleaned = cleaned.replaceAll(RegExp(phrase, caseSensitive: false), '');
    }
    
    return cleaned.trim();
  }

  /// Check if text is Urdu
  bool _isUrdu(String text) {
    final urduPattern = RegExp(r'[\u0600-\u06FF]');
    return urduPattern.hasMatch(text);
  }

  /// Detect if the query is about weather
  bool _isWeatherQuery(String message) {
    final lowerMessage = message.toLowerCase();
    final weatherKeywords = [
      'weather',
      'temperature',
      'temp',
      'hot',
      'cold',
      'rain',
      'sunny',
      'cloudy',
      'humidity',
      'موسم', // Urdu: weather
      'درجہ حرارت', // Urdu: temperature
      'بارش', // Urdu: rain
    ];
    return weatherKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Detect language from text (simple heuristic)
  String detectLanguage(String text) {
    // Simple detection - can be enhanced with a proper language detection library
    final urduPattern = RegExp(r'[\u0600-\u06FF]');
    if (urduPattern.hasMatch(text)) {
      return 'ur-PK'; // Urdu
    }
    return 'en-US'; // Default to English
  }
}

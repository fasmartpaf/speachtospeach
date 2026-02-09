import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  /// Initialize text-to-speech
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage("en-US");
    // Natural pacing: slightly slower for calm, human feel
    await _flutterTts.setSpeechRate(0.45); // Slower than before for more natural pace
    await _flutterTts.setVolume(1.0);
    // Neutral pitch - not too high (robotic) or too low (unnatural)
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  /// Speak text with auto language detection and natural pacing
  Future<void> speak(String text, {String? languageCode}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (languageCode != null) {
      await _flutterTts.setLanguage(languageCode);
      // Adjust speech rate based on language for natural feel
      if (languageCode.startsWith('ur')) {
        // Urdu: slightly slower for polite, soft tone
        await _flutterTts.setSpeechRate(0.42);
      } else {
        // English: natural conversational pace
        await _flutterTts.setSpeechRate(0.45);
      }
    }

    // No abrupt start - let TTS engine prepare naturally
    await _flutterTts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// Pause speaking
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  /// Get available languages
  Future<List<dynamic>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _flutterTts.getLanguages;
  }

  /// Set language for TTS
  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterTts.setLanguage(languageCode);
  }
}

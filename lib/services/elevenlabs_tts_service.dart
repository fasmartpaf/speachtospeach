import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class ElevenLabsTTSService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;

  String get _apiKey {
    final key = dotenv.env['ELEVENLABS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('ELEVENLABS_API_KEY not found in .env file');
    }
    return key;
  }

  bool get isSpeaking => _isSpeaking;

  /// Get voice ID based on language
  /// ElevenLabs voices: Use pre-configured voice IDs
  /// For Urdu: Use a voice that supports multilingual (like Rachel or Adam)
  /// For English: Use natural voices like Rachel, Adam, or custom voices
  String _getVoiceIdForLanguage(String languageCode) {
    // Default to Rachel (natural, warm voice that works well for both languages)
    // You can change these to your preferred ElevenLabs voice IDs
    if (languageCode.startsWith('ur')) {
      // For Urdu, use a multilingual voice
      // Rachel (21m00Tcm4TlvDq8ikWAM) works well for multiple languages
      return dotenv.env['ELEVENLABS_VOICE_ID_URDU'] ?? 
             '21m00Tcm4TlvDq8ikWAM'; // Rachel - good for multilingual
    }
    // For English, use natural voices
    // You can use: Rachel, Adam, or any custom voice you've created
    return dotenv.env['ELEVENLABS_VOICE_ID_ENGLISH'] ?? 
           '21m00Tcm4TlvDq8ikWAM'; // Rachel - natural and warm
  }

  /// Generate speech audio from text using ElevenLabs TTS
  Future<String> _generateSpeechAudio(String text, String languageCode) async {
    try {
      final voiceId = _getVoiceIdForLanguage(languageCode);
      
      final url = Uri.parse('$_baseUrl/text-to-speech/$voiceId');
      
      // ElevenLabs API parameters for natural voice
      final requestBody = {
        'text': text,
        'model_id': 'eleven_multilingual_v2', // Multilingual model
        'voice_settings': {
          'stability': 0.5, // Lower = more variation, higher = more stable
          'similarity_boost': 0.75, // How similar to original voice
          'style': 0.0, // Style exaggeration (0-1)
          'use_speaker_boost': true, // Enhance speaker clarity
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(
        const Duration(seconds: 5), // Timeout for faster failure handling
        onTimeout: () {
          throw Exception('TTS generation timeout');
        },
      );

      if (response.statusCode == 200) {
        // Save audio to temporary file
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        throw Exception('ElevenLabs TTS API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate speech: $e');
    }
  }

  /// Speak text using ElevenLabs TTS (ultra-natural human voices)
  Future<void> speak(String text, {String? languageCode}) async {
    try {
      _isSpeaking = true;

      // Generate audio file using ElevenLabs TTS
      final audioPath = await _generateSpeechAudio(
        text,
        languageCode ?? 'en-US',
      );

      // Set up completion listener before playing
      final completer = Completer<void>();
      late StreamSubscription subscription;
      
      subscription = _audioPlayer.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        subscription.cancel();
        // Clean up temporary file
        try {
          File(audioPath).deleteSync();
        } catch (e) {
          // File may already be deleted, ignore
        }
        completer.complete();
      });

      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(audioPath));
      
      // Wait for playback to complete
      await completer.future;
    } catch (e) {
      _isSpeaking = false;
      throw Exception('Failed to speak: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isSpeaking = false;
  }

  /// Pause speaking
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Resume speaking
  Future<void> resume() async {
    await _audioPlayer.resume();
  }
}

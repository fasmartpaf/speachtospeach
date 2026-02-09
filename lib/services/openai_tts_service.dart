import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class OpenAITTSService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;
  
  OpenAITTSService() {
    // Configure audio player for better iOS compatibility
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    _audioPlayer.setVolume(1.0);
    // Enable playback on iOS even when device is in silent mode
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;

  String get _apiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
    return key;
  }

  bool get isSpeaking => _isSpeaking;

  /// Get voice model based on language
  /// OpenAI TTS voices: alloy, echo, fable, onyx, nova, shimmer
  /// For Urdu: Use 'nova' or 'shimmer' (more natural, warmer)
  /// For English: Use 'alloy' or 'nova' (neutral, friendly)
  String _getVoiceForLanguage(String languageCode) {
    if (languageCode.startsWith('ur')) {
      // Urdu: Use warmer, more natural voice
      return 'nova'; // or 'shimmer' for softer tone
    }
    // English: Use neutral, friendly voice
    return 'alloy'; // or 'nova' for warmer tone
  }

  /// Generate speech audio from text using OpenAI TTS
  Future<String> _generateSpeechAudio(String text, String languageCode) async {
    try {
      final voice = _getVoiceForLanguage(languageCode);
      
      final url = Uri.parse('$_baseUrl/audio/speech');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'tts-1', // Faster model (tts-1-hd is slower)
          'input': text,
          'voice': voice,
          'speed': 1.0, // Normal speed (1.0 is natural, conversational pace)
        }),
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
        print('✅ OpenAI TTS: Audio file saved: ${file.path} (${response.bodyBytes.length} bytes)');
        return file.path;
      } else {
        print('❌ OpenAI TTS API Error: ${response.statusCode} - ${response.body}');
        throw Exception('OpenAI TTS API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate speech: $e');
    }
  }

  /// Speak text using OpenAI TTS (natural human voices)
  Future<void> speak(String text, {String? languageCode}) async {
    try {
      print('📢 OpenAI TTS: Starting to speak: "$text"');
      _isSpeaking = true;

      // Generate audio file using OpenAI TTS (this is the slow part - API call)
      print('📢 OpenAI TTS: Generating audio...');
      final generationStartTime = DateTime.now();
      final audioPath = await _generateSpeechAudio(
        text,
        languageCode ?? 'en-US',
      );
      final generationDuration = DateTime.now().difference(generationStartTime);
      print('✅ OpenAI TTS: Audio generated at: $audioPath (took ${generationDuration.inMilliseconds}ms)');

      // Set up completion listener before playing
      final completer = Completer<void>();
      late StreamSubscription subscription;
      bool completed = false;
      
      subscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (!completed) {
          completed = true;
          print('✅ OpenAI TTS: Playback completed (onPlayerComplete)');
          _isSpeaking = false;
          subscription.cancel();
          // Small delay to ensure audio output is fully stopped
          Future.delayed(const Duration(milliseconds: 200), () {
            // Clean up temporary file (ignore errors)
            try {
              File(audioPath).deleteSync();
              print('✅ OpenAI TTS: Temporary file deleted');
            } catch (e) {
              // File may already be deleted, ignore
              print('⚠️ OpenAI TTS: Could not delete temp file: $e');
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        }
      });

      // Add state change listener to catch completion
      late StreamSubscription stateSubscription;
      stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        print('📢 OpenAI TTS: Player state changed: $state');
        if (state == PlayerState.completed && !completed) {
          if (!completer.isCompleted) {
            completed = true;
            _isSpeaking = false;
            print('✅ OpenAI TTS: Playback completed (via state change)');
            stateSubscription.cancel();
            try {
              File(audioPath).deleteSync();
            } catch (e) {
              // Ignore
            }
            completer.complete();
          }
        } else if (state == PlayerState.stopped && !completed) {
          // If stopped unexpectedly, complete anyway
          if (!completer.isCompleted) {
            completed = true;
            _isSpeaking = false;
            print('⚠️ OpenAI TTS: Playback stopped, completing');
            stateSubscription.cancel();
            completer.complete();
          }
        }
      });

      // Play the audio file
      print('📢 OpenAI TTS: Playing audio...');
      // Ensure settings are applied before playing
      await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Play the audio
      print('📢 OpenAI TTS: Starting playback of file: $audioPath');
      print('📢 OpenAI TTS: File exists: ${File(audioPath).existsSync()}');
      print('📢 OpenAI TTS: File size: ${File(audioPath).lengthSync()} bytes');
      
      await _audioPlayer.play(DeviceFileSource(audioPath));
      print('✅ OpenAI TTS: Play command sent');
      
      // Wait a moment and verify audio is actually playing
      await Future.delayed(const Duration(milliseconds: 200));
      final playerState = _audioPlayer.state;
      print('📢 OpenAI TTS: Player state after play: $playerState');
      
      if (playerState != PlayerState.playing) {
        print('⚠️ OpenAI TTS: Audio not playing, trying again...');
        // Try stopping and playing again
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 300));
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(DeviceFileSource(audioPath));
        await Future.delayed(const Duration(milliseconds: 200));
        final newState = _audioPlayer.state;
        print('📢 OpenAI TTS: Player state after retry: $newState');
        
        if (newState != PlayerState.playing) {
          print('❌ OpenAI TTS: Audio still not playing');
          print('⚠️ Note: iOS Simulator may not play audio. Try on a real device.');
        }
      } else {
        print('✅ OpenAI TTS: Audio is playing successfully');
      }
      
      // Estimate duration based on text length (rough: 150 words per minute)
      final wordCount = text.split(' ').length;
      final estimatedDuration = Duration(milliseconds: (wordCount / 2.5 * 1000).round()); // ~150 WPM
      print('📊 OpenAI TTS: Estimated duration: ${estimatedDuration.inMilliseconds}ms (${wordCount} words)');
      
      // Wait for playback to complete with timeout (use estimated duration + buffer)
      final timeoutMs = estimatedDuration.inMilliseconds + 2000; // Add 2 second buffer
      // Clamp between 3 seconds and 30 seconds
      final clampedTimeoutMs = timeoutMs < 3000 
          ? 3000
          : (timeoutMs > 30000 ? 30000 : timeoutMs);
      final timeoutDuration = Duration(milliseconds: clampedTimeoutMs);
      
      try {
        await completer.future.timeout(
          timeoutDuration,
          onTimeout: () {
            print('⚠️ OpenAI TTS: Playback timeout after ${timeoutDuration.inSeconds}s, completing anyway');
            _completeSubscription?.cancel();
            _stateSubscription?.cancel();
            if (!completer.isCompleted) {
              completed = true;
              _isSpeaking = false;
              try {
                File(audioPath).deleteSync();
              } catch (e) {
                // Ignore
              }
              completer.complete();
            }
          },
        );
        print('✅ OpenAI TTS: Finished speaking');
      } finally {
        // Ensure subscriptions are cancelled
        _completeSubscription?.cancel();
        _stateSubscription?.cancel();
      }
    } catch (e) {
      _isSpeaking = false;
      print('❌ OpenAI TTS Error: $e');
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

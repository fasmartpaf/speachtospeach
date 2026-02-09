import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Local TTS Service using system TTS (instant, no cloud delay)
/// Uses device's native TTS engine for fastest response
class LocalTTSService {
  FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isInitialized = false;
  Completer<void>? _currentCompleter;

  bool get isSpeaking => _isSpeaking;
  
  /// Check if TTS is currently speaking (async version for polling)
  Future<bool> isSpeakingAsync() async {
    return _isSpeaking;
  }

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up TTS parameters for natural, human-like voice
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.4); // Slower = more natural, human-like (0.0 to 1.0, 0.4 = slightly slower, more natural)
      await _flutterTts.setVolume(1.0); // Full volume
      await _flutterTts.setPitch(0.9); // Slightly lower pitch = more natural, less robotic (0.5 to 2.0, 0.9 = slightly lower, warmer)
      
      // Try to use enhanced/premium voices if available (more natural, human-like)
      try {
        // Get available voices and prefer enhanced/premium voices
        List<dynamic> voices = await _flutterTts.getVoices;
        if (voices.isNotEmpty) {
          Map? selectedVoice;
          // Priority: enhanced > premium > neural > natural > default
          for (var voice in voices) {
            final voiceMap = voice as Map;
            final name = voiceMap['name']?.toString().toLowerCase() ?? '';
            final locale = voiceMap['locale']?.toString() ?? '';
            
            // Prefer voices that sound more human
            if (name.contains('enhanced') || name.contains('premium')) {
              selectedVoice = voiceMap;
              print('✅ Using enhanced/premium voice: ${voiceMap['name']}');
              break;
            } else if (name.contains('neural') || name.contains('natural')) {
              if (selectedVoice == null) {
                selectedVoice = voiceMap;
                print('✅ Using neural/natural voice: ${voiceMap['name']}');
              }
            } else if (locale.contains('en-US') && selectedVoice == null) {
              // Fallback to any English voice
              selectedVoice = voiceMap;
            }
          }
          
          if (selectedVoice != null) {
            await _flutterTts.setVoice({
              'name': selectedVoice['name'],
              'locale': selectedVoice['locale']
            });
            print('✅ Voice set: ${selectedVoice['name']}');
          }
        }
      } catch (e) {
        // Voice selection not available on all platforms, continue with default
        print('Voice selection not available: $e');
      }
      
      // Use natural voice settings
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );

      // Set completion handler (set once during initialization)
      // IMPORTANT: Must be set before any speak() calls
      // Note: This handler is set once and reused for all speak() calls
      _flutterTts.setCompletionHandler(() {
        final completionTime = DateTime.now();
        print('✅ Local TTS: Completion handler called - speech finished!');
        print('⏱️ TIMING: Completion handler fired at ${completionTime.millisecondsSinceEpoch}');
        _isSpeaking = false;
        // Notify any waiting completer IMMEDIATELY (no delay)
        if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
          print('✅ Local TTS: Completing completer - full text was spoken');
          _currentCompleter!.complete();
          _currentCompleter = null;
        } else {
          print('⚠️ Local TTS: Completion handler called but no active completer (may be from previous call)');
        }
      });
      
      // Also set up a progress handler to track speech progress (iOS specific)
      try {
        _flutterTts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
          // This can help debug if speech is actually progressing
          print('📊 Local TTS: Progress - word: "$word", offset: $startOffset-$endOffset');
        });
      } catch (e) {
        // Progress handler not available on all platforms
        print('⚠️ Progress handler not available: $e');
      }

      // Set error handler
      _flutterTts.setErrorHandler((msg) {
        print('❌ TTS Error: $msg');
        _isSpeaking = false;
        // Complete with error if waiting
        if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
          _currentCompleter!.complete();
          _currentCompleter = null;
        }
      });
      
      // Also set up status listener as backup
      _flutterTts.setStartHandler(() {
        print('📢 Local TTS: Started speaking');
      });
      
      _flutterTts.setPauseHandler(() {
        print('⏸️ Local TTS: Paused');
      });
      
      _flutterTts.setContinueHandler(() {
        print('▶️ Local TTS: Continued');
      });

      _isInitialized = true;
      print('✅ Local TTS initialized');
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  /// Get voice for language (system will use best available)
  Future<void> _setLanguage(String languageCode) async {
    try {
      // Map language codes to system TTS languages
      String lang = "en-US";
      if (languageCode.startsWith('ur')) {
        lang = "ur-PK"; // Urdu
      } else if (languageCode.startsWith('es')) {
        lang = "es-ES";
      } else if (languageCode.startsWith('fr')) {
        lang = "fr-FR";
      } else {
        lang = languageCode;
      }

      // Get available languages and use best match
      List<dynamic> languages = await _flutterTts.getLanguages;
      if (languages.contains(lang)) {
        await _flutterTts.setLanguage(lang);
        print('✅ Language set to: $lang');
      } else {
        // Fallback to English
        await _flutterTts.setLanguage("en-US");
        print('✅ Language set to: en-US (fallback)');
      }
      
      // After setting language, try to select best voice for that language
      try {
        List<dynamic> voices = await _flutterTts.getVoices;
        if (voices.isNotEmpty) {
          // Find voices for current language that sound most natural
          Map? bestVoice;
          for (var voice in voices) {
            final voiceMap = voice as Map;
            final voiceLocale = voiceMap['locale']?.toString() ?? '';
            final voiceName = voiceMap['name']?.toString().toLowerCase() ?? '';
            
            if (voiceLocale == lang || voiceLocale.startsWith(lang.split('-')[0])) {
              // Prefer enhanced/premium voices
              if (voiceName.contains('enhanced') || voiceName.contains('premium')) {
                bestVoice = voiceMap;
                break;
              } else if (bestVoice == null) {
                bestVoice = voiceMap;
              }
            }
          }
          
          if (bestVoice != null) {
            await _flutterTts.setVoice({
              'name': bestVoice['name'],
              'locale': bestVoice['locale']
            });
            print('✅ Best voice selected: ${bestVoice['name']}');
          }
        }
      } catch (e) {
        print('Voice selection after language change: $e');
      }
    } catch (e) {
      print('Error setting language: $e');
      await _flutterTts.setLanguage("en-US");
    }
  }

  /// Speak text using local system TTS (instant, no cloud delay)
  Future<void> speak(String text, {String? languageCode}) async {
    if (text.trim().isEmpty) return;

    try {
      // Initialize if needed
      if (!_isInitialized) {
        await initialize();
      }

      // Set language
      await _setLanguage(languageCode ?? 'en-US');

      // Ensure any previous completer is cleared
      if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
        print('⚠️ Local TTS: Previous completer still active, cancelling it');
        _currentCompleter!.complete();
        _currentCompleter = null;
      }

      _isSpeaking = true;
      final speakStartTime = DateTime.now();
      print('📢 Local TTS: Starting to speak: "$text"');
      print('⏱️ TIMING: Local TTS speak() called at ${speakStartTime.millisecondsSinceEpoch}');

      // Create completer for this speak call
      _currentCompleter = Completer<void>();

      // Estimate speech duration more accurately
      // Speech rate is 0.4 (slower), so ~90 words per minute
      // Add 50% buffer to ensure we don't cut off long text
      final wordCount = text.split(' ').length;
      final baseDuration = (wordCount / 1.2 * 1000).round(); // ~72 WPM (accounting for slower rate)
      final estimatedDuration = Duration(milliseconds: (baseDuration * 1.5).round()); // Add 50% buffer
      print('📊 Local TTS: Estimated duration: ${estimatedDuration.inMilliseconds}ms (${wordCount} words, with buffer)');

      // Speak immediately (no API call, instant start - starts in milliseconds!)
      final speakCommandTime = DateTime.now();
      final result = await _flutterTts.speak(text);
      final speakCommandEndTime = DateTime.now();
      final speakCommandDuration = speakCommandEndTime.difference(speakCommandTime);
      print('📢 Local TTS: Speak command sent, result: $result');
      print('⏱️ TIMING: speak() command took: ${speakCommandDuration.inMilliseconds}ms');
      print('📢 Local TTS: Full text length: ${text.length} characters');

      // Wait for completion handler FIRST, with a longer timeout as fallback
      // Priority: actual completion > estimated time (with generous buffer)
      try {
        // Wait for completion with timeout
        try {
          await Future.any([
            _currentCompleter!.future, // Completion handler (fires when TTS actually finishes)
            Future.delayed(estimatedDuration, () {
              // Fallback: only complete if handler hasn't fired after generous timeout
              if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
                final timeoutTime = DateTime.now();
                final actualDuration = timeoutTime.difference(speakStartTime);
                print('⚠️ Local TTS: Completion handler did not fire, completing at estimated time (${estimatedDuration.inMilliseconds}ms)');
                print('⏱️ TIMING: Timeout fired at ${timeoutTime.millisecondsSinceEpoch}');
                print('⏱️ TIMING: Actual TTS duration from start: ${actualDuration.inMilliseconds}ms (${(actualDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');
                _isSpeaking = false;
                _currentCompleter!.complete();
                _currentCompleter = null;
              }
            }),
          ]);
          final completionTime = DateTime.now();
          final totalDuration = completionTime.difference(speakStartTime);
          print('✅ Local TTS: Finished speaking (completion handler fired or timeout reached)');
          print('⏱️ TIMING: Total speak() method duration: ${totalDuration.inMilliseconds}ms (${(totalDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');
        } catch (e) {
          print('❌ Local TTS: Error waiting for completion: $e');
          _isSpeaking = false;
          if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
            _currentCompleter!.complete();
          }
          _currentCompleter = null;
        }
      } catch (e) {
        print('❌ Local TTS: Error: $e, completing immediately');
        _isSpeaking = false;
        if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
          _currentCompleter!.complete();
        }
        _currentCompleter = null;
      } finally {
        // Only mark as done if completer was actually completed
        if (_currentCompleter == null || _currentCompleter!.isCompleted) {
          _isSpeaking = false;
        }
      }
    } catch (e) {
      print('❌ Error speaking: $e');
      _isSpeaking = false;
      rethrow;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    // Only log if we're actually speaking (to avoid noise when using cloud TTS)
    final wasSpeaking = _isSpeaking;
    try {
      if (wasSpeaking) {
        print('🛑 Local TTS: Stopping speech...');
      }
      // Cancel any active completer first
      if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
        if (wasSpeaking) {
          print('🛑 Local TTS: Cancelling active completer');
        }
        _currentCompleter!.complete();
        _currentCompleter = null;
      }
      // Stop the TTS engine
      await _flutterTts.stop();
      _isSpeaking = false;
      if (wasSpeaking) {
        print('✅ Local TTS: Stopped successfully');
      }
      // Small delay to ensure TTS engine is fully stopped
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      if (wasSpeaking) {
        print('❌ Error stopping TTS: $e');
      }
      _isSpeaking = false;
      _currentCompleter = null;
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      print('Error pausing TTS: $e');
    }
  }

  /// Resume speaking
  Future<void> resume() async {
    try {
      // FlutterTts doesn't have resume, so we can't resume
      // This is a limitation of the package
    } catch (e) {
      print('Error resuming TTS: $e');
    }
  }
}

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _lastWords = '';
  bool _continuousMode = false;
  Function(String)? _onResultCallback;
  Function()? _onErrorCallback;
  int _restartAttempts = 0;
  static const int _maxRestartAttempts = 3;
  DateTime? _lastRestartTime;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    // Check if microphone permission is already granted
    var status = await Permission.microphone.status;
    
    // If not granted, request permission
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    
    // If permanently denied, return false
    if (status.isPermanentlyDenied) {
      print('Microphone permission is permanently denied. Please enable it in Settings.');
      return false;
    }
    
    // If not granted, return false
    if (!status.isGranted) {
      print('Microphone permission not granted. Status: $status');
      return false;
    }

    // Initialize speech recognition with error and status handlers
    _isAvailable = await _speech.initialize(
      onError: (error) {
        print('Speech recognition error: ${error.errorMsg}, permanent: ${error.permanent}');
        // Handle error_no_match gracefully - it just means no speech detected yet
        if (error.errorMsg == 'error_no_match') {
          print('⚠️ No speech detected (error_no_match) - this is normal, not restarting');
          // Reset restart attempts since this is expected
          _restartAttempts = 0;
          // Don't call error callback - this is normal
          // Don't restart - just continue listening if in continuous mode
          return;
        }
        // For other errors, call the error callback
        _onErrorCallback?.call();
      },
      onStatus: (status) {
        print('Speech recognition status: $status');
        // Handle status changes
        if (status == 'listening') {
          _isListening = true;
          _restartAttempts = 0; // Reset counter when successfully listening
          print('✅ Speech recognition is actively listening');
        } else if (status == 'done' || status == 'notListening') {
          // In continuous mode, "done" just means a pause - don't stop listening
          // Only mark as not listening if we're NOT in continuous mode
          if (!_continuousMode) {
            _isListening = false;
            print('⏸️ Speech recognition stopped (not in continuous mode)');
          } else {
            // In continuous mode, "done" is normal - just a pause between phrases
            // Don't restart immediately - wait to see if user continues speaking
            print('⏸️ Speech recognition paused (continuous mode - waiting for more speech)');
            // Don't set _isListening = false in continuous mode - keep it true
            // The error handler will manage actual errors
          }
        }
      },
    );

    return _isAvailable;
  }

  /// Start listening for speech
  Future<void> startListening({
    required Function(String) onResult,
    Function()? onError,
    bool continuous = true, // Keep listening until answer is received
  }) async {
    print('🎤 SpeechService.startListening called (continuous: $continuous)');
    
    // Stop any existing listening first
    if (_isListening) {
      print('🛑 Stopping existing listening before starting new one...');
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    if (!_isAvailable) {
      print('⚠️ Speech not available, initializing...');
      await initialize();
    }

    if (!_isAvailable) {
      print('❌ Speech not available after initialization');
      onError?.call();
      return;
    }

    // Store callbacks for restart
    _continuousMode = continuous;
    _onResultCallback = onResult;
    _onErrorCallback = onError;

    _lastWords = '';
    _isListening = true;
    
    print('🎤 Starting speech recognition (continuous: $continuous)...');

    await _speech.listen(
      onResult: (result) {
        try {
          _lastWords = result.recognizedWords;
          print('SpeechService: Received result - finalResult: ${result.finalResult}, words: "${result.recognizedWords}"');
          
          // Reset restart attempts on successful result
          _restartAttempts = 0;
          
          // In continuous mode, always send results for accumulation (even partial)
          if (continuous) {
            // Send all results (partial and final) for accumulation
            if (result.recognizedWords.isNotEmpty) {
              // Always send the current recognized words for accumulation
              onResult(result.recognizedWords.trim());
            }
          } else {
            // For non-continuous mode:
            // - Send partial results for UI display (accumulation)
            // - Process final results when they arrive
            if (result.recognizedWords.isNotEmpty) {
              // Send partial results for display
              onResult(result.recognizedWords.trim());
              
              // If this is a final result, stop listening
              if (result.finalResult && result.recognizedWords.trim().length >= 3) {
                print('SpeechService: Final result received (length: ${result.recognizedWords.trim().length})');
                _isListening = false;
                _continuousMode = false;
                _speech.stop();
                // Final result already sent above via onResult
              }
            }
          }
        } catch (e) {
          print('Error in speech onResult: $e');
          // Don't crash - continue listening
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 2), // Reduced pause time for faster response
      localeId: null,
      listenOptions: stt.SpeechListenOptions(
        listenMode: continuous 
            ? stt.ListenMode.dictation
            : stt.ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true, // Critical for low latency
      ),
    );
  }

  /// Restart listening if needed (for continuous mode)
  Future<void> _restartListeningIfNeeded() async {
    // Prevent rapid restarts
    final now = DateTime.now();
    if (_lastRestartTime != null) {
      final timeSinceLastRestart = now.difference(_lastRestartTime!);
      if (timeSinceLastRestart.inSeconds < 3) {
        print('Skipping restart - too soon since last restart (${timeSinceLastRestart.inSeconds}s)');
        return;
      }
    }
    
    if (_continuousMode && _onResultCallback != null && _restartAttempts < _maxRestartAttempts) {
      _restartAttempts++;
      _lastRestartTime = now;
      print('Restarting continuous listening... (attempt $_restartAttempts/$_maxRestartAttempts)');
      
      try {
        // Stop existing listening first
        if (_isListening) {
          await _speech.stop();
          await Future.delayed(const Duration(milliseconds: 1000)); // Wait longer before restart
        }
        
        // Only restart if still in continuous mode
        if (_continuousMode && _onResultCallback != null && _restartAttempts <= _maxRestartAttempts) {
          await startListening(
            onResult: _onResultCallback!,
            onError: _onErrorCallback,
            continuous: true,
          );
        }
      } catch (e) {
        print('Error restarting listening: $e');
        if (_restartAttempts >= _maxRestartAttempts) {
          print('Max restart attempts reached, stopping continuous listening');
          _isListening = false;
          _continuousMode = false;
          _onErrorCallback?.call();
        }
      }
    } else if (_restartAttempts >= _maxRestartAttempts) {
      print('Max restart attempts reached, stopping continuous listening');
      _isListening = false;
      _continuousMode = false;
      _onErrorCallback?.call();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      _continuousMode = false; // Disable continuous mode when stopping
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  /// Get available languages
  Future<List<stt.LocaleName>> getAvailableLanguages() async {
    if (!_isAvailable) {
      await initialize();
    }
    return _speech.locales();
  }
}

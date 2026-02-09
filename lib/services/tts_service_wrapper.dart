import 'dart:io';
import 'package:flutter/foundation.dart';
import 'local_tts_service.dart';
import 'elevenlabs_tts_service.dart';
import 'openai_tts_service.dart';

/// TTS Service Wrapper - Uses local system TTS for instant response
/// Falls back to cloud TTS only if local TTS fails
class TTSServiceWrapper {
  final LocalTTSService _localService = LocalTTSService();
  final ElevenLabsTTSService _elevenLabsService = ElevenLabsTTSService();
  final OpenAITTSService _openAIService = OpenAITTSService();
  
  bool _useLocal = true; // Enable local TTS (works better on iOS Simulator)
  bool _useElevenLabs = false; // Disabled - using OpenAI TTS for faster, more reliable performance
  bool _isSpeaking = false;
  String? _activeService; // Track which service is currently active

  bool get isSpeaking => _isSpeaking;

  /// Speak text - Uses OpenAI TTS for fast, reliable performance
  /// Falls back to local TTS only if OpenAI completely fails
  Future<void> speak(String text, {String? languageCode}) async {
    _isSpeaking = true;
    
    try {
      // Use OpenAI TTS directly (fast, reliable, good quality)
      try {
        print('📢 Using OpenAI TTS (fast, reliable)');
        _activeService = 'openai';
        await _openAIService.speak(text, languageCode: languageCode);
        _isSpeaking = false;
        _activeService = null;
        return;
      } catch (e) {
        _activeService = null;
        print('❌ OpenAI TTS error: $e');
        // Only use local TTS as absolute last resort (if cloud completely fails)
        if (_useLocal) {
          try {
            print('📢 Using Local System TTS (last resort fallback)');
            _activeService = 'local';
            await _localService.speak(text, languageCode: languageCode);
            _isSpeaking = false;
            _activeService = null;
            return;
          } catch (e2) {
            _activeService = null;
            print('❌ Local TTS error: $e2');
            _useLocal = false;
          }
        }
        // If all services fail, still set _isSpeaking to false and continue
        _isSpeaking = false;
        print('❌ All TTS services failed, but continuing anyway');
        // Don't throw - allow app to continue (listening will start anyway)
      }
    } catch (e) {
      _isSpeaking = false;
      print('❌ TTS Wrapper Error: $e');
      // Don't throw - just log the error so the app continues
    }
  }

  /// Stop speaking - only stops the active service
  Future<void> stop() async {
    // Only stop the service that's actually active to avoid unnecessary logs
    if (_activeService == 'elevenlabs') {
      await _elevenLabsService.stop();
    } else if (_activeService == 'openai') {
      await _openAIService.stop();
    } else if (_activeService == 'local') {
      await _localService.stop();
    } else {
      // If no active service tracked, stop all (but silently for unused services)
      // This handles edge cases where stop() is called before speak() completes
      try {
        if (_elevenLabsService.isSpeaking) await _elevenLabsService.stop();
      } catch (e) {}
      try {
        if (_openAIService.isSpeaking) await _openAIService.stop();
      } catch (e) {}
      try {
        if (_localService.isSpeaking) await _localService.stop();
      } catch (e) {}
    }
    _isSpeaking = false;
    _activeService = null;
  }

  /// Pause speaking
  Future<void> pause() async {
    await _localService.pause();
    await _elevenLabsService.pause();
    await _openAIService.pause();
  }

  /// Resume speaking
  Future<void> resume() async {
    await _localService.resume();
    await _elevenLabsService.resume();
    await _openAIService.resume();
  }
  
  /// Reset to use local TTS again
  void resetToLocal() {
    _useLocal = true;
  }
  
  /// Reset to use ElevenLabs again (if quota is restored)
  void resetToElevenLabs() {
    _useElevenLabs = true;
  }
}

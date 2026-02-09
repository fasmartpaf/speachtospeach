import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/running_models.dart';
import '../services/speech_service.dart';
import '../services/tts_service_wrapper.dart';
import '../services/ai_service.dart';
import '../services/interview_service.dart';
import '../services/location_service.dart';
import '../services/backend_service.dart';
import 'dart:async';

class RunningProvider with ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  final TTSServiceWrapper _ttsService = TTSServiceWrapper();
  final AIService _aiService = AIService();
  final InterviewService _interviewService = InterviewService();
  final LocationService _locationService = LocationService();
  final BackendService _backendService = BackendService();

  // Interview state
  InterviewState _interviewState = InterviewState();
  InterviewState get interviewState => _interviewState;
  
  // Pre-generated first question (set when Start button is tapped)
  String? _preGeneratedFirstQuestion;

  // Running state
  RunSession? _currentRun;
  RunningMetrics _currentMetrics = RunningMetrics();
  bool _isRunning = false;
  bool _isPaused = false;
  List<RunSession> _runHistory = [];

  RunSession? get currentRun => _currentRun;
  RunningMetrics get currentMetrics => _currentMetrics;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  List<RunSession> get runHistory => List.unmodifiable(_runHistory);

  // Milestones
  final List<Milestone> _milestones = [];
  List<Milestone> get milestones => List.unmodifiable(_milestones);

  // Timeout timer for listening
  Timer? _listeningTimeout;
  int _listeningRestartAttempts = 0;
  static const int _maxListeningRestartAttempts = 3;

  RunningProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _speechService.initialize();
  }

  /// Pre-generate first question when Start button is tapped (before navigation)
  /// This allows the question to be ready immediately when interview screen loads
  Future<void> preGenerateFirstQuestion() async {
    try {
      print('📢 Pre-generating first question...');
      final firstQuestion = await _interviewService.startInterview(
        onQuestion: (question) async {
          // Store the question for immediate use
          _preGeneratedFirstQuestion = question;
          print('✅ First question pre-generated: "$question"');
        },
        onError: (error) {
          print('❌ Error pre-generating question: $error');
          _preGeneratedFirstQuestion = null;
        },
      );
      _preGeneratedFirstQuestion = firstQuestion;
      print('✅ First question ready: "$firstQuestion"');
    } catch (e) {
      print('❌ Error in preGenerateFirstQuestion: $e');
      _preGeneratedFirstQuestion = null;
    }
  }

  /// Start dynamic AI-driven interview
  Future<void> startInterview() async {
    _interviewState = InterviewState(
      status: InterviewStatus.idle,
    );
    notifyListeners();

    try {
      // Check if we have a pre-generated first question (from Start button)
      if (_preGeneratedFirstQuestion != null) {
        print('✅ Using pre-generated first question');
        final question = _preGeneratedFirstQuestion!;
        _preGeneratedFirstQuestion = null; // Clear it after use
        
        // Use the pre-generated question immediately
        await _speakFirstQuestion(question);
        return;
      }
      
      // Otherwise, generate first question now (fallback)
      print('📢 Generating first question now...');
      final firstQuestion = await _interviewService.startInterview(
        onQuestion: (question) async {
          await _speakFirstQuestion(question);
        },
        onError: (error) {
          print('Error starting interview: $error');
          _interviewState = _interviewState.copyWith(
            status: InterviewStatus.idle,
          );
          notifyListeners();
        },
      );
    } catch (e) {
      print('Error in startInterview: $e');
      _interviewState = _interviewState.copyWith(
        status: InterviewStatus.idle,
      );
      notifyListeners();
    }
  }
  
  /// Speak the first question (shared logic for pre-generated and newly generated)
  Future<void> _speakFirstQuestion(String question) async {
    // Update UI IMMEDIATELY - show question and speaking status right away
    _interviewState = _interviewState.copyWith(
      currentMessage: question,
      status: InterviewStatus.speaking,
      questionCount: _interviewState.questionCount + 1,
    );
    notifyListeners(); // UI updates immediately - user sees question and speaking indicator
    
    // Stop any existing TTS (no delay - do it in parallel)
    final stopFuture = _ttsService.stop();
    
    // Speak the question - start generating audio immediately
    final languageCode = 'en-US';
    print('📢 Starting to speak first question: "$question"');
    
    // Wait for stop to complete (if needed), then start speaking
    await stopFuture;
    
    // Speak first, THEN start listening (prevents microphone from picking up TTS)
    final ttsStartTime = DateTime.now();
    print('⏱️ TIMING: TTS started at ${ttsStartTime.millisecondsSinceEpoch}');
    print('⏱️ TIMING: About to call _ttsService.speak()...');
    
    // Start a watchdog timer to ensure we transition even if TTS callback fails
    Timer? watchdogTimer;
    final maxWaitTime = const Duration(seconds: 30); // Maximum wait time
    watchdogTimer = Timer(maxWaitTime, () {
      print('⚠️ TIMING: Watchdog timer fired! TTS took longer than ${maxWaitTime.inSeconds}s, forcing transition to listening');
      if (_interviewState.status == InterviewStatus.speaking) {
        _interviewState = _interviewState.copyWith(
          status: InterviewStatus.listening,
        );
        notifyListeners();
        _startInterviewListening();
      }
    });
    
    _ttsService.speak(question, languageCode: languageCode).then((_) async {
      watchdogTimer?.cancel(); // Cancel watchdog if callback fires
      final ttsEndTime = DateTime.now();
      final ttsDuration = ttsEndTime.difference(ttsStartTime);
      print('✅ Finished speaking first question (TTS took: ${ttsDuration.inMilliseconds}ms / ${(ttsDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');
      print('⏱️ TIMING: TTS completed, now waiting for audio to fully stop...');
      final waitStartTime = DateTime.now();
      
      // TTS completion handler should have already set isSpeaking to false
      // But double-check with aggressive polling (every 50ms) to ensure audio actually stopped
      int waitCount = 0;
      while (_ttsService.isSpeaking && waitCount < 20) { // Max 1 second (20 * 50ms)
        await Future.delayed(const Duration(milliseconds: 50)); // Faster polling
        waitCount++;
      }
      final pollingEndTime = DateTime.now();
      final pollingDuration = pollingEndTime.difference(waitStartTime);
      print('⏱️ Polling TTS completion took: ${pollingDuration.inMilliseconds}ms (checked ${waitCount} times)');
      
      // Reduced buffer delay - only 500ms instead of 1500ms
      // The aggressive polling in LocalTTSService should catch completion faster
      final bufferStartTime = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 500)); // Reduced from 1500ms
      final bufferEndTime = DateTime.now();
      final bufferDuration = bufferEndTime.difference(bufferStartTime);
      print('⏱️ Buffer delay took: ${bufferDuration.inMilliseconds}ms');
      
      final totalWaitTime = DateTime.now().difference(waitStartTime);
      print('✅ Audio fully stopped (total wait: ${totalWaitTime.inMilliseconds}ms), starting to listen...');
      
      // After audio has fully stopped, start listening
      final stateChangeStartTime = DateTime.now();
      _interviewState = _interviewState.copyWith(
        status: InterviewStatus.listening,
      );
      notifyListeners();
      final stateChangeEndTime = DateTime.now();
      final stateChangeDuration = stateChangeEndTime.difference(stateChangeStartTime);
      print('⏱️ State change to listening took: ${stateChangeDuration.inMilliseconds}ms');
      
      final listenStartTime = DateTime.now();
      _startInterviewListening();
      final listenCallDuration = DateTime.now().difference(listenStartTime);
      print('⏱️ _startInterviewListening() call took: ${listenCallDuration.inMilliseconds}ms');
      
      final totalTimeFromTTS = DateTime.now().difference(ttsEndTime);
      print('⏱️ TOTAL TIME from TTS end to listening start: ${totalTimeFromTTS.inMilliseconds}ms (${(totalTimeFromTTS.inMilliseconds / 1000).toStringAsFixed(2)}s)');
    }).catchError((e) {
      print('❌ Error speaking question: $e');
      print('⏱️ TIMING: TTS error occurred, starting to listen anyway after delay');
      // Even if TTS fails, start listening after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        print('⏱️ TIMING: Error recovery - changing to listening state');
        _interviewState = _interviewState.copyWith(
          status: InterviewStatus.listening,
        );
        notifyListeners();
        _startInterviewListening();
      });
    });
  }

  /// Start listening for user response (waits for user to finish, no interruption)
  Future<void> _startInterviewListening() async {
    final listenMethodStartTime = DateTime.now();
    
    // Ensure we're in listening state
    if (_interviewState.status != InterviewStatus.listening) {
      print('⚠️ Cannot start listening - not in listening state: ${_interviewState.status}');
      return;
    }
    
    print('🎤 Starting to listen for user response...');
    
    // Stop any existing listening first
    if (_speechService.isListening) {
      print('🛑 Stopping existing listening...');
      await _speechService.stopListening();
      // Wait a moment for it to fully stop
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // Cancel any existing timeout
    _listeningTimeout?.cancel();
    
    // Store the current answer to accumulate text
    String? accumulatedAnswer;
    bool hasProcessedFinalResult = false;
    Timer? silenceTimer;
    Timer? noSpeechTimer; // Timer to detect when no speech is detected
    
    // Start listening IMMEDIATELY (no delay)
    try {
      print('🎤 Calling speechService.startListening... (attempt ${_listeningRestartAttempts + 1}/$_maxListeningRestartAttempts)');
      await _speechService.startListening(
      onResult: (text) async {
        // User is speaking - reset restart attempts and no-speech timer
        if (text.trim().isNotEmpty) {
          _listeningRestartAttempts = 0; // Reset on successful speech
          noSpeechTimer?.cancel();
          
          accumulatedAnswer = text.trim();
          _interviewState = _interviewState.copyWith(
            userAnswer: accumulatedAnswer,
          );
          notifyListeners();
          
          // Reset silence timer - user is still speaking
          silenceTimer?.cancel();
          
          // Wait 2 seconds of silence before processing (user finished speaking)
          if (!hasProcessedFinalResult) {
            silenceTimer?.cancel(); // Cancel previous timer
            silenceTimer = Timer(const Duration(milliseconds: 2000), () async {
              if (!hasProcessedFinalResult && 
                  _interviewState.status == InterviewStatus.listening &&
                  accumulatedAnswer != null &&
                  accumulatedAnswer!.trim().isNotEmpty &&
                  accumulatedAnswer!.trim().length >= 3) {
                hasProcessedFinalResult = true;
                silenceTimer?.cancel();
                noSpeechTimer?.cancel();
                _listeningTimeout?.cancel();
                _listeningRestartAttempts = 0; // Reset on successful answer
                await _speechService.stopListening();
                print('✅ User finished speaking, processing: "$accumulatedAnswer"');
                await _processUserResponse(accumulatedAnswer!.trim());
              }
            });
          }
        }
      },
      onError: () {
        print('Speech error in interview');
        silenceTimer?.cancel();
        noSpeechTimer?.cancel();
        // On error, retry listening after short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_interviewState.status == InterviewStatus.listening) {
            _startInterviewListening();
          }
        });
      },
      continuous: true, // Use continuous mode for better text accumulation
      );
      print('✅ Speech service started listening');
      
      // Set up timer to detect when no speech is detected after "done" status
      // If speech recognition goes to "done" with no speech, restart listening
      noSpeechTimer = Timer(const Duration(seconds: 5), () async {
        // Check if we got any speech
        if (!hasProcessedFinalResult && 
            _interviewState.status == InterviewStatus.listening &&
            (accumulatedAnswer == null || accumulatedAnswer!.trim().isEmpty)) {
          // No speech detected - restart listening if we haven't exceeded max attempts
          if (_listeningRestartAttempts < _maxListeningRestartAttempts) {
            _listeningRestartAttempts++;
            print('⚠️ No speech detected after 5 seconds, restarting listening (attempt $_listeningRestartAttempts/$_maxListeningRestartAttempts)');
            await _speechService.stopListening();
            await Future.delayed(const Duration(milliseconds: 500));
            if (_interviewState.status == InterviewStatus.listening) {
              _startInterviewListening();
            }
          } else {
            // Max attempts reached - re-ask the question
            print('⚠️ No speech detected after $_maxListeningRestartAttempts attempts, re-asking question');
            _listeningRestartAttempts = 0; // Reset for next question
            hasProcessedFinalResult = true;
            noSpeechTimer?.cancel();
            silenceTimer?.cancel();
            _listeningTimeout?.cancel();
            await _speechService.stopListening();
            await _rephraseQuestion();
          }
        }
      });
    } catch (e) {
      print('❌ Error starting speech service: $e');
      // Retry after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_interviewState.status == InterviewStatus.listening) {
          _startInterviewListening();
        }
      });
      return;
    }
    
    // Fallback timeout: if no answer after 30 seconds, rephrase question
    _listeningTimeout = Timer(const Duration(seconds: 30), () async {
      if (!hasProcessedFinalResult) {
        hasProcessedFinalResult = true;
        silenceTimer?.cancel();
        noSpeechTimer?.cancel();
        await _speechService.stopListening();
        
        if (accumulatedAnswer != null && accumulatedAnswer!.trim().isNotEmpty) {
          // User provided an answer - process it
          print('✅ Timeout reached, processing: "$accumulatedAnswer"');
          _listeningRestartAttempts = 0; // Reset on successful answer
          await _processUserResponse(accumulatedAnswer!.trim());
        } else {
          // No answer received - rephrase question
          print('⚠️ No answer received after 30 seconds, rephrasing question');
          _listeningRestartAttempts = 0; // Reset for next question
          await _rephraseQuestion();
        }
      }
    });
  }
  
  /// Process user response: Validate → Think → Reply → Ask next question
  Future<void> _processUserResponse(String userAnswer) async {
    // Step 1: Stop listening and move to processing/thinking state
    await _speechService.stopListening();
    _listeningTimeout?.cancel();
    _listeningRestartAttempts = 0; // Reset restart attempts on successful answer
    
    print('🔄 Processing user response: "$userAnswer"');
    
    _interviewState = _interviewState.copyWith(
      userAnswer: userAnswer,
      status: InterviewStatus.processing, // "Thinking" state
    );
    notifyListeners();
    
    try {
      // Step 2: Basic validation - only reject completely empty or noise
      if (userAnswer.trim().length < 2) {
        print('⚠️ Response too short, getting AI to rephrase question');
        // Instead of asking to repeat, let AI rephrase the question naturally
        await _rephraseQuestion();
        return;
      }
      
      print('✅ Response received, getting AI response...');
      
      // Step 3: Process answer and get AI response (thinking)
      // Let AI handle validation - it will ask follow-up if needed
      await _interviewService.processAnswer(
        userAnswer,
        onQuestion: (question) async {
          print('✅ AI response received: "$question"');
          
          // Step 4: AI responds and asks next question - move to speaking
          _interviewState = _interviewState.copyWith(
            currentMessage: question,
            userAnswer: null, // Clear user answer for next question
            status: InterviewStatus.speaking,
            questionCount: _interviewState.questionCount + 1,
          );
          notifyListeners();

          // Step 5: Speak the response/question
          // Stop any existing TTS (no delay - do it in parallel)
          final stopFuture = _ttsService.stop();
          final languageCode = 'en-US';
          print('📢 Speaking question...');
          
          // Wait for stop to complete (if needed), then start speaking
          await stopFuture;
          
          // Speak first, THEN start listening (prevents microphone from picking up TTS)
          final ttsStartTime = DateTime.now();
          print('⏱️ TIMING: TTS started at ${ttsStartTime.millisecondsSinceEpoch}');
          print('⏱️ TIMING: About to call _ttsService.speak()...');
          
          // Start a watchdog timer to ensure we transition even if TTS callback fails
          Timer? watchdogTimer;
          final maxWaitTime = const Duration(seconds: 30); // Maximum wait time
          watchdogTimer = Timer(maxWaitTime, () {
            print('⚠️ TIMING: Watchdog timer fired! TTS took longer than ${maxWaitTime.inSeconds}s, forcing transition to listening');
            if (_interviewState.status == InterviewStatus.speaking) {
              _interviewState = _interviewState.copyWith(
                status: InterviewStatus.listening,
              );
              notifyListeners();
              _startInterviewListening();
            }
          });
          
          _ttsService.speak(question, languageCode: languageCode).then((_) async {
            watchdogTimer?.cancel(); // Cancel watchdog if callback fires
            final ttsEndTime = DateTime.now();
            final ttsDuration = ttsEndTime.difference(ttsStartTime);
            print('✅ Finished speaking (TTS took: ${ttsDuration.inMilliseconds}ms / ${(ttsDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)');
            print('⏱️ TIMING: TTS completed, now waiting for audio to fully stop...');
            final waitStartTime = DateTime.now();
            
            // Poll isSpeaking more aggressively to detect when audio actually stops
            // Check every 50ms instead of 100ms for faster detection
            int waitCount = 0;
            while (_ttsService.isSpeaking && waitCount < 60) { // Increased max wait to 3 seconds (60 * 50ms)
              await Future.delayed(const Duration(milliseconds: 50)); // Faster polling
              waitCount++;
              if (waitCount % 10 == 0) {
                print('⏱️ Still waiting for TTS to stop... (${waitCount * 50}ms)');
              }
            }
            final pollingEndTime = DateTime.now();
            final pollingDuration = pollingEndTime.difference(waitStartTime);
            print('⏱️ Polling TTS completion took: ${pollingDuration.inMilliseconds}ms (checked ${waitCount} times)');
            
            // Reduced buffer delay - only 800ms instead of 1500ms
            // The aggressive polling should catch completion faster
            final bufferStartTime = DateTime.now();
            await Future.delayed(const Duration(milliseconds: 800)); // Reduced from 1500ms
            final bufferEndTime = DateTime.now();
            final bufferDuration = bufferEndTime.difference(bufferStartTime);
            print('⏱️ Buffer delay took: ${bufferDuration.inMilliseconds}ms');
            
            final totalWaitTime = DateTime.now().difference(waitStartTime);
            print('✅ Audio fully stopped (total wait: ${totalWaitTime.inMilliseconds}ms), starting to listen...');
            
            // Start listening after audio has fully stopped
            final stateChangeStartTime = DateTime.now();
            _interviewState = _interviewState.copyWith(
              status: InterviewStatus.listening,
            );
            notifyListeners();
            final stateChangeEndTime = DateTime.now();
            final stateChangeDuration = stateChangeEndTime.difference(stateChangeStartTime);
            print('⏱️ State change to listening took: ${stateChangeDuration.inMilliseconds}ms');
            
            final listenStartTime = DateTime.now();
            _startInterviewListening();
            final listenCallDuration = DateTime.now().difference(listenStartTime);
            print('⏱️ _startInterviewListening() call took: ${listenCallDuration.inMilliseconds}ms');
            
            final totalTimeFromTTS = DateTime.now().difference(ttsEndTime);
            print('⏱️ TOTAL TIME from TTS end to listening start: ${totalTimeFromTTS.inMilliseconds}ms (${(totalTimeFromTTS.inMilliseconds / 1000).toStringAsFixed(2)}s)');
          }).catchError((e) {
            watchdogTimer?.cancel(); // Cancel watchdog on error
            print('❌ Error speaking: $e, starting to listen after delay');
            Future.delayed(const Duration(milliseconds: 500), () {
              _interviewState = _interviewState.copyWith(
                status: InterviewStatus.listening,
              );
              notifyListeners();
              _startInterviewListening();
            });
          });
        },
        onComplete: () async {
          print('✅ Interview complete!');
          _interviewState = _interviewState.copyWith(
            status: InterviewStatus.complete,
          );
          notifyListeners();
          
          // Mark interview as complete
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasSeenOnboarding', true);
        },
        onError: (error) async {
          print('❌ Error processing answer: $error');
          // On error, rephrase the question instead of asking to repeat
          await _rephraseQuestion();
        },
      );
    } catch (e) {
      print('❌ Exception in _processUserResponse: $e');
      print('Stack trace: ${StackTrace.current}');
      await _rephraseQuestion();
    }
  }
  
  /// Rephrase the current question naturally (instead of asking to repeat)
  Future<void> _rephraseQuestion() async {
    // Get the last question from conversation history
    final conversationHistory = _interviewService.conversationHistory;
    final lastQuestion = conversationHistory.isNotEmpty && 
        conversationHistory.last['role'] == 'assistant'
        ? conversationHistory.last['content'] ?? ''
        : 'What are your running goals?';
    
    // Ask AI to rephrase the question in a different way
    final rephrasePrompt = '''The user didn't provide a clear answer to this question: "$lastQuestion"

Please rephrase the question in a different, more specific way. Make it easier to answer. Don't ask them to repeat - just ask the same thing differently or break it down into smaller parts.

Keep it short (1-2 sentences). Be friendly and encouraging.''';

    try {
      final rephrasedQuestion = await _aiService.getAIResponse(
        rephrasePrompt,
        conversationHistory: [
          {'role': 'system', 'content': 'You are a friendly running coach. Rephrase questions to make them easier to answer.'},
          ...conversationHistory,
        ],
      );
      
      _interviewState = _interviewState.copyWith(
        currentMessage: rephrasedQuestion,
        userAnswer: null,
        status: InterviewStatus.speaking,
      );
      notifyListeners();
      
      // Speak the rephrased question, THEN start listening
      // Stop any existing TTS (no delay - do it in parallel)
      final stopFuture = _ttsService.stop();
      final ttsStartTime = DateTime.now();
      
      // Wait for stop to complete (if needed), then start speaking
      await stopFuture;
      print('⏱️ TIMING: TTS started at ${ttsStartTime.millisecondsSinceEpoch}');
      print('⏱️ TIMING: About to call _ttsService.speak() for rephrased question...');
      
      // Start a watchdog timer to ensure we transition even if TTS callback fails
      Timer? watchdogTimer;
      final maxWaitTime = const Duration(seconds: 30); // Maximum wait time
      watchdogTimer = Timer(maxWaitTime, () {
        print('⚠️ TIMING: Watchdog timer fired! TTS took longer than ${maxWaitTime.inSeconds}s, forcing transition to listening');
        if (_interviewState.status == InterviewStatus.speaking) {
          _interviewState = _interviewState.copyWith(
            status: InterviewStatus.listening,
          );
          notifyListeners();
          _startInterviewListening();
        }
      });
      
      _ttsService.speak(rephrasedQuestion, languageCode: 'en-US').then((_) async {
        watchdogTimer?.cancel(); // Cancel watchdog if callback fires
        final ttsEndTime = DateTime.now();
        final ttsDuration = ttsEndTime.difference(ttsStartTime);
        print('✅ Finished speaking rephrased question (TTS took: ${ttsDuration.inMilliseconds}ms), waiting for audio to fully stop...');
        final waitStartTime = DateTime.now();
        
        // Poll isSpeaking more aggressively to detect when audio actually stops
        // Check every 50ms instead of 100ms for faster detection
        int waitCount = 0;
        while (_ttsService.isSpeaking && waitCount < 60) { // Increased max wait to 3 seconds (60 * 50ms)
          await Future.delayed(const Duration(milliseconds: 50)); // Faster polling
          waitCount++;
          if (waitCount % 10 == 0) {
            print('⏱️ Still waiting for TTS to stop... (${waitCount * 50}ms)');
          }
        }
        final pollingEndTime = DateTime.now();
        final pollingDuration = pollingEndTime.difference(waitStartTime);
        print('⏱️ Polling TTS completion took: ${pollingDuration.inMilliseconds}ms (checked ${waitCount} times)');
        
        // Reduced buffer delay - only 800ms instead of 1500ms
        // The aggressive polling should catch completion faster
        final bufferStartTime = DateTime.now();
        await Future.delayed(const Duration(milliseconds: 800)); // Reduced from 1500ms
        final bufferEndTime = DateTime.now();
        final bufferDuration = bufferEndTime.difference(bufferStartTime);
        print('⏱️ Buffer delay took: ${bufferDuration.inMilliseconds}ms');
        
        final totalWaitTime = DateTime.now().difference(waitStartTime);
        print('✅ Audio fully stopped (total wait: ${totalWaitTime.inMilliseconds}ms), starting to listen...');
        
        // Start listening after audio has fully stopped
        final stateChangeStartTime = DateTime.now();
        _interviewState = _interviewState.copyWith(
          status: InterviewStatus.listening,
        );
        notifyListeners();
        final stateChangeEndTime = DateTime.now();
        final stateChangeDuration = stateChangeEndTime.difference(stateChangeStartTime);
        print('⏱️ State change to listening took: ${stateChangeDuration.inMilliseconds}ms');
        
        final listenStartTime = DateTime.now();
        _startInterviewListening();
        final listenCallDuration = DateTime.now().difference(listenStartTime);
        print('⏱️ _startInterviewListening() call took: ${listenCallDuration.inMilliseconds}ms');
        
        final totalTimeFromTTS = DateTime.now().difference(ttsEndTime);
        print('⏱️ TOTAL TIME from TTS end to listening start: ${totalTimeFromTTS.inMilliseconds}ms (${(totalTimeFromTTS.inMilliseconds / 1000).toStringAsFixed(2)}s)');
      }).catchError((e) {
        watchdogTimer?.cancel(); // Cancel watchdog on error
        print('Error speaking rephrased question: $e');
        Future.delayed(const Duration(milliseconds: 500), () {
          _interviewState = _interviewState.copyWith(
            status: InterviewStatus.listening,
          );
          notifyListeners();
          _startInterviewListening();
        });
      });
    } catch (e) {
      print('Error rephrasing question: $e');
      // Fallback: just ask the question again
      await _startInterviewListening();
    }
  }
  

  /// Start a new run session
  Future<void> startRun(String conversationId) async {
    _currentRun = RunSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      startTime: DateTime.now(),
      status: RunStatus.running,
    );

    _isRunning = true;
    _isPaused = false;
    _milestones.clear();
    _currentMetrics = RunningMetrics();

    // Start location tracking
    await _locationService.startTracking(
      onLocationUpdate: (point) {
        if (_currentRun != null) {
          final updatedRoute = List<LocationPoint>.from(_currentRun!.route)..add(point);
          _currentRun = _currentRun!.copyWith(route: updatedRoute);
          _updateMetrics();
          _checkMilestones();
          
          // Periodically update backend (every 10 points to reduce API calls)
          if (updatedRoute.length % 10 == 0) {
            _backendService.updateRunSession(_currentRun!);
          }
        }
      },
      onError: (error) {
        // Handle error
        print('Location tracking error: $error');
      },
    );

    notifyListeners();
  }

  /// Pause run
  Future<void> pauseRun() async {
    if (_currentRun != null) {
      _currentRun = _currentRun!.copyWith(status: RunStatus.paused);
      _isPaused = true;
      await _locationService.stopTracking();
      notifyListeners();
    }
  }

  /// Resume run
  Future<void> resumeRun() async {
    if (_currentRun != null) {
      _currentRun = _currentRun!.copyWith(status: RunStatus.running);
      _isPaused = false;
      // Resume tracking
      await _locationService.startTracking(
        onLocationUpdate: (point) {
          if (_currentRun != null) {
            final updatedRoute = List<LocationPoint>.from(_currentRun!.route)..add(point);
            _currentRun = _currentRun!.copyWith(route: updatedRoute);
            _updateMetrics();
            _checkMilestones();
          }
        },
        onError: (error) {},
      );
      notifyListeners();
    }
  }

  /// Stop and save run
  Future<void> stopRun() async {
    if (_currentRun == null) return;

    await _locationService.stopTracking();

    final endTime = DateTime.now();
    final duration = endTime.difference(_currentRun!.startTime);

    _currentRun = _currentRun!.copyWith(
      endTime: endTime,
      totalDistance: _currentMetrics.currentDistance,
      duration: duration,
      averagePace: _currentMetrics.currentPace,
      milestones: _milestones,
      status: RunStatus.completed,
    );

    // Generate AI insight
    final insight = await _generateRunInsight();
    _currentRun = _currentRun!.copyWith(aiInsight: insight);

    // Save to backend
    await _backendService.saveRunSession(_currentRun!);
    
    // Add to history
    _runHistory.insert(0, _currentRun!);

    _isRunning = false;
    _isPaused = false;
    notifyListeners();
  }

  /// Load run history
  Future<void> loadRunHistory(String userId) async {
    _runHistory = await _backendService.getUserRunSessions(userId);
    notifyListeners();
  }

  /// Get interview analytics
  Future<Map<String, dynamic>> getInterviewAnalytics() async {
    try {
      print('📊 Getting interview analytics...');
      final conversationSummary = _interviewService.getConversationSummary();
      print('📊 Conversation summary: $conversationSummary');
      
      // Convert conversation summary to a format the backend expects
      // The backend expects answers map with conversation key
      final answers = <String, dynamic>{
        'conversation': conversationSummary,
      };
      final analytics = await _backendService.getOnboardingAnalytics(answers);
      print('✅ Analytics received: ${analytics?.keys}');
      return analytics ?? {
        'summary': conversationSummary,
        'topics': [],
        'userIntent': 'Running goals and preferences',
        'tone': 'Friendly and conversational',
      };
    } catch (e) {
      print('❌ Error getting analytics: $e');
      // Return default analytics if backend fails
      final conversationSummary = _interviewService.getConversationSummary();
      return {
        'summary': conversationSummary,
        'topics': [],
        'userIntent': 'Running goals and preferences',
        'tone': 'Friendly and conversational',
      };
    }
  }

  /// Stop interview and clean up
  Future<void> stopInterview() async {
    _listeningTimeout?.cancel();
    await _speechService.stopListening();
    _interviewState = InterviewState(status: InterviewStatus.idle);
    notifyListeners();
  }

  @override
  void dispose() {
    _listeningTimeout?.cancel();
    stopInterview();
    super.dispose();
  }

  /// Update running metrics
  void _updateMetrics() {
    if (_currentRun == null || _currentRun!.route.length < 2) {
      // Still update time even if no route yet
      final elapsedTime = DateTime.now().difference(_currentRun!.startTime);
      _currentMetrics = RunningMetrics(
        currentDistance: 0.0,
        elapsedTime: elapsedTime,
        currentPace: 0.0,
      );
      notifyListeners();
      return;
    }

    final totalDistance = _locationService.calculateTotalDistance(_currentRun!.route);
    final elapsedTime = DateTime.now().difference(_currentRun!.startTime);
    final averagePace = _locationService.calculateAveragePace(totalDistance, elapsedTime);

    _currentMetrics = RunningMetrics(
      currentDistance: totalDistance,
      elapsedTime: elapsedTime,
      currentPace: averagePace,
      currentSpeed: _currentRun!.route.isNotEmpty
          ? (_currentRun!.route.last.speed ?? 0) * 3.6 // Convert m/s to km/h
          : null,
    );

    notifyListeners();
  }

  /// Check and trigger milestones
  void _checkMilestones() {
    final distance = _currentMetrics.currentDistance;
    final time = _currentMetrics.elapsedTime;

    // Distance milestones (1km, 5km, 10km, etc.)
    final distanceMilestones = [1.0, 5.0, 10.0, 21.1, 42.2];
    for (var km in distanceMilestones) {
      if (distance >= km && !_milestones.any((m) => m.type == MilestoneType.distance && m.value == km)) {
        _triggerMilestone(MilestoneType.distance, km);
      }
    }

    // Time milestones (10min, 30min, 1hr, etc.)
    final timeMilestones = [600, 1800, 3600]; // seconds
    for (var seconds in timeMilestones) {
      if (time.inSeconds >= seconds && !_milestones.any((m) => m.type == MilestoneType.time && m.value == seconds.toDouble())) {
        _triggerMilestone(MilestoneType.time, seconds.toDouble());
      }
    }
  }

  /// Trigger milestone with AI-generated message
  Future<void> _triggerMilestone(MilestoneType type, double value) async {
    String message = '';
    if (type == MilestoneType.distance) {
      message = value >= 1
          ? 'Great job! You\'ve completed ${value.toStringAsFixed(0)} kilometers!'
          : 'Well done! Keep going!';
    } else if (type == MilestoneType.time) {
      final minutes = (value / 60).floor();
      message = 'Excellent! You\'ve been running for $minutes minutes!';
    }

    final milestone = Milestone(
      type: type,
      value: value,
      timestamp: DateTime.now(),
      message: message,
    );

    _milestones.add(milestone);

    // Speak milestone via TTS
    if (message.isNotEmpty) {
      await _ttsService.speak(message);
    }

    notifyListeners();
  }

  /// Generate AI insight for completed run
  Future<String> _generateRunInsight() async {
    if (_currentRun == null) return '';

    final prompt = '''Analyze this running session and provide a brief, encouraging insight:
Distance: ${_currentRun!.totalDistance.toStringAsFixed(2)}km
Time: ${_currentRun!.duration.inMinutes} minutes
Pace: ${_currentRun!.averagePace.toStringAsFixed(2)} min/km

Provide a short, encouraging summary (2-3 sentences) about the performance.''';

    return await _aiService.getAIResponse(prompt);
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import '../providers/running_provider.dart';
import '../models/running_models.dart';
import 'interview_analytics_screen.dart';

/// Interview Screen - Dynamic AI-driven conversation
/// No UI instructions, starts listening immediately, AI decides questions
class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _thinkingController;
  bool _hasStarted = false;
  RunningProvider? _provider; // Store provider reference to avoid accessing context in dispose

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for listening (pulsing circle)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    
    // Wave animation for speaking (sound waves)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    
    // Thinking animation for processing (rotating dots)
    _thinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Start interview after build phase completes (to avoid setState during build)
    // The first question is already pre-generated when Start button was tapped
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInterview();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider reference when dependencies change (safe to access context here)
    if (_provider == null) {
      _provider = Provider.of<RunningProvider>(context, listen: false);
    }
  }

  void _startInterview() {
    if (_hasStarted) return;
    _hasStarted = true;

    if (_provider == null) {
      _provider = Provider.of<RunningProvider>(context, listen: false);
    }
    _provider!.startInterview();
    
    // Listen for interview completion
    _provider!.addListener(_onInterviewStateChanged);
  }

  void _onInterviewStateChanged() async {
    if (!mounted || _provider == null) return;
    
    final state = _provider!.interviewState;
    
    // Handle interview completion
    if (state.status == InterviewStatus.complete) {
      
      // Remove listener before navigation to prevent errors
      _provider?.removeListener(_onInterviewStateChanged);
      
      // Get analytics and navigate
      try {
        final analytics = await _provider!.getInterviewAnalytics();
        if (mounted) {
          // Use pushReplacement to replace current screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => InterviewAnalyticsScreen(
                analytics: analytics ?? {},
              ),
            ),
          );
        }
      } catch (e) {
        print('❌ Error getting analytics: $e');
        // Still navigate even if analytics fail
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => InterviewAnalyticsScreen(
                analytics: {},
              ),
            ),
          );
        }
      }
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _thinkingController.dispose();
    // Use stored provider reference instead of accessing context
    _provider?.removeListener(_onInterviewStateChanged);
    _provider?.stopInterview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0A0A),
              const Color(0xFF1A1A2E),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<RunningProvider>(
            builder: (context, provider, _) {
              final state = provider.interviewState;
              
              return Stack(
                children: [
                  // Subtle background glow effect
                  _buildBackgroundGlow(state.status),
                  
                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated status indicator
                        if (state.status == InterviewStatus.listening)
                          _buildListeningIndicator()
                        else if (state.status == InterviewStatus.speaking)
                          _buildSpeakingIndicator()
                        else if (state.status == InterviewStatus.processing)
                          _buildProcessingIndicator()
                        else
                          _buildIdleIndicator(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow(InterviewStatus status) {
    Color glowColor;
    if (status == InterviewStatus.listening) {
      glowColor = Colors.pink;
    } else if (status == InterviewStatus.speaking) {
      glowColor = Colors.blue;
    } else if (status == InterviewStatus.processing) {
      glowColor = Colors.orange;
    } else {
      glowColor = Colors.grey;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            glowColor.withOpacity(0.05),
            glowColor.withOpacity(0.02),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = (_pulseController.value * 2 - 1).abs();
        final scale = 1.0 + (pulseValue * 0.25);
        final opacity = 0.4 + (pulseValue * 0.5);
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Multiple pulsing rings for depth
            ...List.generate(3, (index) {
              final delay = index * 0.3;
              final adjustedValue = ((_pulseController.value + delay) % 1.0);
              final ringPulse = (adjustedValue * 2 - 1).abs();
              final ringScale = 1.0 + (ringPulse * 0.3);
              final ringOpacity = 0.2 * (1 - ringPulse);
              
              return Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.pink.withOpacity(ringOpacity),
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
            // Main pulsing ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.pink.withOpacity(opacity * 0.15),
                  border: Border.all(
                    color: Colors.pink.withOpacity(opacity),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
            // Inner circle with microphone
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.pink.withOpacity(0.3),
                    Colors.pink.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.pink,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.mic,
                  color: Colors.pink,
                  size: 56,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeakingIndicator() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Multiple expanding sound wave rings
            ...List.generate(4, (index) {
              final delay = index * 0.25;
              final waveValue = ((_waveController.value + delay) % 1.0);
              final scale = 1.0 + (waveValue * 0.4);
              final opacity = 0.5 * (1 - waveValue);
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(opacity),
                      width: 2.5,
                    ),
                  ),
                ),
              );
            }),
            // Main circle with speaker icon
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.blue,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.volume_up,
                  color: Colors.blue,
                  size: 56,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProcessingIndicator() {
    return AnimatedBuilder(
      animation: _thinkingController,
      builder: (context, child) {
        final rotation = _thinkingController.value * 2 * math.pi;
        final pulse = (math.sin(_thinkingController.value * 2 * math.pi) + 1) / 2;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating outer rings
            ...List.generate(2, (index) {
              final ringRotation = rotation + (index * math.pi);
              return Transform.rotate(
                angle: ringRotation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
            // Pulsing center circle with brain icon
            Transform.scale(
              scale: 1.0 + (pulse * 0.1),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.orange.withOpacity(0.3),
                      Colors.orange.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.orange,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.psychology,
                    color: Colors.orange,
                    size: 52,
                  ),
                ),
              ),
            ),
            // Rotating dots around the circle
            ...List.generate(3, (index) {
              final dotAngle = (rotation + (index * 2 * math.pi / 3));
              final dotX = math.cos(dotAngle) * 60;
              final dotY = math.sin(dotAngle) * 60;
              return Positioned(
                left: 60 + dotX - 5,
                top: 60 + dotY - 5,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildIdleIndicator() {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.grey.withOpacity(0.2),
            Colors.grey.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.grey.withOpacity(0.5),
          width: 2.5,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.mic_none,
          color: Colors.grey,
          size: 52,
        ),
      ),
    );
  }
}

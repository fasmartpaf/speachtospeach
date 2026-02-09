import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/conversation_provider.dart';
import '../providers/running_provider.dart';
import '../models/app_state.dart';
import 'conversations_list_screen.dart';
import 'run_tracking_screen.dart';
import 'run_history_screen.dart';
import 'welcome_screen.dart';
import 'interview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Check authentication status
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userId = prefs.getString('user_id');

    if (!mounted) return;

    // If not logged in, redirect to welcome screen
    if (!isLoggedIn || userId == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(AppState state) {
    switch (state) {
      case AppState.idle:
        return Colors.blue;
      case AppState.listening:
        return Colors.green;
      case AppState.processing:
        return Colors.orange;
      case AppState.speaking:
        return Colors.purple;
      case AppState.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(AppState state) {
    switch (state) {
      case AppState.idle:
        return Icons.mic_none;
      case AppState.listening:
        return Icons.mic;
      case AppState.processing:
        return Icons.hourglass_empty;
      case AppState.speaking:
        return Icons.volume_up;
      case AppState.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<ConversationProvider>(
          builder: (context, provider, child) {
            final state = provider.state;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getStatusColor(state.currentState).withValues(alpha: 0.15),
                    _getStatusColor(state.currentState).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Top bar with conversation switcher
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Conversations list button
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 28),
                          color: Colors.grey[700],
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ConversationsListScreen(),
                              ),
                            );
                          },
                        ),
                        // Current conversation title (if available)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConversationsListScreen(),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                // Status indicator circle
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(state.currentState),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Conversation title (optional - can be hidden for voice-only)
                                if (provider.currentConversation != null)
                                  Text(
                                    provider.currentConversation!.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Continuous mode toggle
                        IconButton(
                          icon: Icon(
                            provider.continuousMode
                                ? Icons.mic
                                : Icons.mic_none,
                            size: 28,
                          ),
                          color: provider.continuousMode
                              ? Colors.green
                              : Colors.grey[700],
                          onPressed: () {
                            provider.toggleContinuousMode();
                            // If enabling continuous mode and idle, start listening
                            if (provider.continuousMode &&
                                state.currentState == AppState.idle) {
                              provider.startListening();
                            }
                          },
                        ),
                        // Run History button
                        IconButton(
                          icon: const Icon(Icons.history, size: 28),
                          color: Colors.purple[700],
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RunHistoryScreen(),
                              ),
                            );
                          },
                        ),
                        // Start Run button
                        IconButton(
                          icon: const Icon(Icons.directions_run, size: 28),
                          color: Colors.green[700],
                          onPressed: () async {
                            final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
                            final runningProvider = Provider.of<RunningProvider>(context, listen: false);
                            
                            // Ensure we have a conversation
                            if (conversationProvider.currentConversation == null) {
                              await conversationProvider.createNewConversation();
                            }
                            
                            final conversationId = conversationProvider.currentConversation!.id;
                            
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RunTrackingScreen(conversationId: conversationId),
                                ),
                              );
                            }
                          },
                        ),
                        // New conversation button
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 28),
                          color: Colors.blue,
                          onPressed: () async {
                            await provider.createNewConversation();
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                        // Start Interview button
                        IconButton(
                          icon: const Icon(Icons.record_voice_over, size: 28),
                          color: Colors.orange,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const InterviewScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Main content area - microphone button only
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          // Microphone button - large and prominent
                          GestureDetector(
                            onTap: () {
                              if (state.currentState == AppState.idle) {
                                provider.startListening();
                              } else if (state.currentState == AppState.listening) {
                                provider.stopListening();
                                // Disable continuous mode when manually stopped
                                if (provider.continuousMode) {
                                  provider.toggleContinuousMode();
                                }
                              } else if (state.currentState == AppState.speaking) {
                                provider.stopSpeaking();
                              } else if (state.currentState == AppState.error) {
                                provider.reset();
                                provider.startListening();
                              }
                            },
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    final isAnimated = state.currentState == AppState.listening ||
                                        state.currentState == AppState.processing ||
                                        state.currentState == AppState.speaking;
                                    
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Outer pulse ring (when listening/processing/speaking)
                                        if (isAnimated)
                                          Container(
                                            width: 200 * _pulseAnimation.value,
                                            height: 200 * _pulseAnimation.value,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _getStatusColor(state.currentState)
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                        // Main microphone button
                                        Transform.scale(
                                          scale: isAnimated ? _scaleAnimation.value : 1.0,
                                          child: Container(
                                            width: 180,
                                            height: 180,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(state.currentState),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _getStatusColor(state.currentState)
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 30,
                                                  spreadRadius: 10,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _getStatusIcon(state.currentState),
                                              size: 80,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                          const SizedBox(height: 40),

                          // Conversation message count indicator (visual only)
                          if (provider.currentConversation != null &&
                              provider.currentConversation!.messages.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${provider.currentConversation!.messages.length} messages',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Replay button (icon only, no text)
                          if (state.aiResponse != null && state.currentState == AppState.idle)
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.replay, size: 32, color: Colors.blue),
                              ),
                              onPressed: () {
                                provider.replayResponse();
                              },
                            ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Error indicator (icon only, no text)
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: GestureDetector(
                        onTap: () {
                          provider.reset();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

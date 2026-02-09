import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'interview_screen.dart';
import '../providers/running_provider.dart';

/// Start Screen - Shows after onboarding, before interview
/// User clicks "Start" button to begin talking to AI
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular icon with speaker
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A90E2), // Medium blue
                  border: Border.all(
                    color: const Color(0xFF6BA3E8), // Lighter blue outline
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 56,
                ),
              ),

              const SizedBox(height: 60),

              // Welcome text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Ready to start your running journey?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Start Button
              ElevatedButton(
                onPressed: () async {
                  // Pre-generate first question IMMEDIATELY when Start is tapped
                  final provider = Provider.of<RunningProvider>(context, listen: false);
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                  
                  try {
                    // Pre-generate first question (this calls the cloud)
                    await provider.preGenerateFirstQuestion();
                    
                    // Close loading dialog
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    
                    // Navigate to interview screen (question is already ready)
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const InterviewScreen(),
                        ),
                      );
                    }
                  } catch (e) {
                    // Close loading dialog
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    
                    // Show error and still navigate (will retry on interview screen)
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const InterviewScreen(),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

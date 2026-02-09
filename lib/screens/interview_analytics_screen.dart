import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/running_provider.dart';

class InterviewAnalyticsScreen extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const InterviewAnalyticsScreen({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      // Navigate back to start screen
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Interview Complete',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),

            // Analytics Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    if (analytics['summary'] != null)
                      _buildAnalyticsCard(
                        'Summary',
                        analytics['summary'],
                        Icons.summarize,
                        Colors.blue,
                      ),

                    const SizedBox(height: 20),

                    // Topics Card
                    if (analytics['topics'] != null && analytics['topics'].isNotEmpty)
                      _buildTopicsCard(
                        'Topics Discussed',
                        analytics['topics'],
                        Icons.topic,
                        Colors.purple,
                      ),

                    const SizedBox(height: 20),

                    // User Intent Card
                    if (analytics['userIntent'] != null)
                      _buildAnalyticsCard(
                        'User Intent',
                        analytics['userIntent'],
                        Icons.psychology,
                        Colors.orange,
                      ),

                    const SizedBox(height: 20),

                    // Conversation Tone Card
                    if (analytics['conversationTone'] != null)
                      _buildAnalyticsCard(
                        'Conversation Tone',
                        analytics['conversationTone'],
                        Icons.mood,
                        Colors.green,
                      ),

                    const SizedBox(height: 40),

                    // Complete Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate back to start screen
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsCard(
    String title,
    List<dynamic> topics,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topics.map((topic) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        topic.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

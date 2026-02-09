import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/running_provider.dart';
import '../models/running_models.dart';

class RunTrackingScreen extends StatefulWidget {
  final String conversationId;

  const RunTrackingScreen({
    super.key,
    required this.conversationId,
  });

  @override
  State<RunTrackingScreen> createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen> {
  Timer? _metricsTimer;

  @override
  void initState() {
    super.initState();
    _startRun();
    _startMetricsUpdate();
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  void _startRun() {
    final provider = Provider.of<RunningProvider>(context, listen: false);
    provider.startRun(widget.conversationId);
  }

  void _startMetricsUpdate() {
    // Update metrics every second
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<RunningProvider>(
          builder: (context, provider, child) {
            final metrics = provider.currentMetrics;
            final isRunning = provider.isRunning;
            final isPaused = provider.isPaused;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isRunning
                        ? Colors.green[400]!.withValues(alpha: 0.1)
                        : Colors.orange[400]!.withValues(alpha: 0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Status bar
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await provider.stopRun();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isRunning ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isPaused ? 'PAUSED' : 'RUNNING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Balance
                      ],
                    ),
                  ),

                  // Metrics Dashboard
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Distance (Large)
                          _buildMetricCard(
                            'Distance',
                            metrics.distanceDisplay,
                            Icons.straighten,
                            Colors.blue,
                          ),

                          const SizedBox(height: 30),

                          // Time and Pace (Side by side)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Time',
                                  metrics.timeDisplay,
                                  Icons.timer,
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildMetricCard(
                                  'Pace',
                                  '${metrics.paceDisplay}/km',
                                  Icons.speed,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Speed (if available)
                          if (metrics.currentSpeed != null)
                            _buildMetricCard(
                              'Speed',
                              '${metrics.currentSpeed!.toStringAsFixed(1)} km/h',
                              Icons.directions_run,
                              Colors.green,
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Control buttons
                  Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pause/Resume button
                        if (isRunning)
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (isPaused) {
                                await provider.resumeRun();
                              } else {
                                await provider.pauseRun();
                              }
                            },
                            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                            label: Text(isPaused ? 'Resume' : 'Pause'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          ),

                        // Stop button
                        ElevatedButton.icon(
                          onPressed: () async {
                            await provider.stopRun();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
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

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

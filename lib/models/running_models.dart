class UserProfile {
  final String id;
  final String? primaryGoal;
  final String? trainingEvent;
  final RaceResult? recentRaceResult;
  final List<String> availableDays; // e.g., ['Monday', 'Wednesday', 'Friday']
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.primaryGoal,
    this.trainingEvent,
    this.recentRaceResult,
    this.availableDays = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'primary_goal': primaryGoal,
      'training_event': trainingEvent,
      'recent_race_result': recentRaceResult?.toJson(),
      'available_days': availableDays,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      primaryGoal: json['primary_goal'],
      trainingEvent: json['training_event'],
      recentRaceResult: json['recent_race_result'] != null
          ? RaceResult.fromJson(json['recent_race_result'])
          : null,
      availableDays: List<String>.from(json['available_days'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class RaceResult {
  final double distance; // in kilometers
  final Duration time; // race time

  RaceResult({
    required this.distance,
    required this.time,
  });

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'time_seconds': time.inSeconds,
    };
  }

  factory RaceResult.fromJson(Map<String, dynamic> json) {
    return RaceResult(
      distance: json['distance']?.toDouble() ?? 0.0,
      time: Duration(seconds: json['time_seconds'] ?? 0),
    );
  }
}

class RunSession {
  final String id;
  final String conversationId; // Links to conversation tab
  final DateTime startTime;
  final DateTime? endTime;
  final List<LocationPoint> route;
  final double totalDistance; // in kilometers
  final Duration duration;
  final double averagePace; // minutes per kilometer
  final double? averageHeartRate;
  final List<Milestone> milestones;
  final String? aiInsight;
  final RunStatus status;

  RunSession({
    required this.id,
    required this.conversationId,
    required this.startTime,
    this.endTime,
    this.route = const [],
    this.totalDistance = 0.0,
    this.duration = Duration.zero,
    this.averagePace = 0.0,
    this.averageHeartRate,
    this.milestones = const [],
    this.aiInsight,
    this.status = RunStatus.notStarted,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'route': route.map((p) => p.toJson()).toList(),
      'total_distance': totalDistance,
      'duration_seconds': duration.inSeconds,
      'average_pace': averagePace,
      'average_heart_rate': averageHeartRate,
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'ai_insight': aiInsight,
      'status': status.toString().split('.').last,
    };
  }

  factory RunSession.fromJson(Map<String, dynamic> json) {
    return RunSession(
      id: json['id'],
      conversationId: json['conversation_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      route: (json['route'] as List?)
              ?.map((p) => LocationPoint.fromJson(p))
              .toList() ??
          [],
      totalDistance: json['total_distance']?.toDouble() ?? 0.0,
      duration: Duration(seconds: json['duration_seconds'] ?? 0),
      averagePace: json['average_pace']?.toDouble() ?? 0.0,
      averageHeartRate: json['average_heart_rate']?.toDouble(),
      milestones: (json['milestones'] as List?)
              ?.map((m) => Milestone.fromJson(m))
              .toList() ??
          [],
      aiInsight: json['ai_insight'],
      status: RunStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RunStatus.notStarted,
      ),
    );
  }
}

class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed; // km/h
  final double? altitude;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'altitude': altitude,
    };
  }

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      speed: json['speed']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
    );
  }
}

class Milestone {
  final MilestoneType type;
  final double value; // distance in km or time in seconds
  final DateTime timestamp;
  final String? message; // AI-generated milestone message

  Milestone({
    required this.type,
    required this.value,
    required this.timestamp,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      type: MilestoneType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MilestoneType.distance,
      ),
      value: json['value']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
    );
  }
}

enum MilestoneType {
  distance, // e.g., 1km, 5km
  time, // e.g., 10 minutes, 30 minutes
  pace, // e.g., personal best pace
}

enum RunStatus {
  notStarted,
  running,
  paused,
  completed,
}

class RunningMetrics {
  final double currentDistance; // km
  final Duration elapsedTime;
  final double currentPace; // min/km
  final double? currentSpeed; // km/h
  final double? currentHeartRate;
  final double? elevation;

  RunningMetrics({
    this.currentDistance = 0.0,
    this.elapsedTime = Duration.zero,
    this.currentPace = 0.0,
    this.currentSpeed,
    this.currentHeartRate,
    this.elevation,
  });

  String get paceDisplay {
    if (currentPace == 0) return '--:--';
    final minutes = currentPace.floor();
    final seconds = ((currentPace - minutes) * 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get distanceDisplay {
    if (currentDistance < 1) {
      return '${(currentDistance * 1000).toStringAsFixed(0)}m';
    }
    return '${currentDistance.toStringAsFixed(2)}km';
  }

  String get timeDisplay {
    final hours = elapsedTime.inHours;
    final minutes = elapsedTime.inMinutes.remainder(60);
    final seconds = elapsedTime.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

extension RunSessionExtension on RunSession {
  RunSession copyWith({
    String? id,
    String? conversationId,
    DateTime? startTime,
    DateTime? endTime,
    List<LocationPoint>? route,
    double? totalDistance,
    Duration? duration,
    double? averagePace,
    double? averageHeartRate,
    List<Milestone>? milestones,
    String? aiInsight,
    RunStatus? status,
  }) {
    return RunSession(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      route: route != null ? List.from(route) : List.from(this.route),
      totalDistance: totalDistance ?? this.totalDistance,
      duration: duration ?? this.duration,
      averagePace: averagePace ?? this.averagePace,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      milestones: milestones != null ? List.from(milestones) : List.from(this.milestones),
      aiInsight: aiInsight ?? this.aiInsight,
      status: status ?? this.status,
    );
  }
}

// Interview State Models
enum InterviewStatus {
  idle,
  speaking,
  listening,
  processing,
  complete,
}

class InterviewState {
  final InterviewStatus status;
  final String? currentMessage;
  final String? userAnswer;
  final int questionCount;

  InterviewState({
    this.status = InterviewStatus.idle,
    this.currentMessage,
    this.userAnswer,
    this.questionCount = 0,
  });

  InterviewState copyWith({
    InterviewStatus? status,
    String? currentMessage,
    String? userAnswer,
    int? questionCount,
  }) {
    return InterviewState(
      status: status ?? this.status,
      currentMessage: currentMessage ?? this.currentMessage,
      userAnswer: userAnswer ?? this.userAnswer,
      questionCount: questionCount ?? this.questionCount,
    );
  }
}

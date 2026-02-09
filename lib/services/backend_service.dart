import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/running_models.dart';

class BackendService {
  // Use localhost for iOS simulator, 10.0.2.2 for Android emulator
  // For physical devices, use your computer's IP address
  static String get _baseUrl {
    // You can add BACKEND_URL to .env if needed
    // For now, using localhost (works for iOS simulator)
    // For Android emulator, use: http://10.0.2.2:3000
    // For physical device, use your computer's IP: http://192.168.x.x:3000
    return 'http://localhost:3000';
  }

  /// Save user profile (onboarding data)
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/user/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save profile: ${response.body}');
      }
    } catch (e) {
      print('Error saving profile: $e');
      // Store locally as fallback
      await _saveProfileLocally(profile);
    }
  }

  /// Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/profile/$userId'),
      );

      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error getting profile: $e');
      // Try local storage
      return await _getProfileLocally(userId);
    }
    return null;
  }

  /// Save run session
  Future<void> saveRunSession(RunSession session) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/runs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(session.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save run: ${response.body}');
      }
    } catch (e) {
      print('Error saving run: $e');
      // Store locally as fallback
      await _saveRunLocally(session);
    }
  }

  /// Update run session (for live tracking)
  Future<void> updateRunSession(RunSession session) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/runs/${session.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(session.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update run: ${response.body}');
      }
    } catch (e) {
      print('Error updating run: $e');
    }
  }

  /// Get all run sessions for a user
  Future<List<RunSession>> getUserRunSessions(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/runs?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RunSession.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting runs: $e');
      // Try local storage
      return await _getRunsLocally(userId);
    }
    return [];
  }

  /// Get run session by ID
  Future<RunSession?> getRunSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/runs/$sessionId'),
      );

      if (response.statusCode == 200) {
        return RunSession.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error getting run: $e');
    }
    return null;
  }

  // Local storage fallback methods
  Future<void> _saveProfileLocally(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_${profile.id}', jsonEncode(profile.toJson()));
  }

  Future<UserProfile?> _getProfileLocally(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_profile_$userId');
    if (data != null) {
      return UserProfile.fromJson(jsonDecode(data));
    }
    return null;
  }

  Future<void> _saveRunLocally(RunSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final runs = await _getRunsLocally(session.conversationId);
    runs.insert(0, session);
    final runsJson = runs.map((r) => r.toJson()).toList();
    await prefs.setString('runs_${session.conversationId}', jsonEncode(runsJson));
  }

  Future<List<RunSession>> _getRunsLocally(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('runs_$userId');
    if (data != null) {
      final List<dynamic> runsJson = jsonDecode(data);
      return runsJson.map((json) => RunSession.fromJson(json)).toList();
    }
    return [];
  }

  /// Get onboarding analytics
  Future<Map<String, dynamic>?> getOnboardingAnalytics(Map<String, dynamic> answers) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/onboarding/analytics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'answers': answers}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getting onboarding analytics: $e');
    }
    return null;
  }
}

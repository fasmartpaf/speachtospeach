import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

/// OpenAI Whisper API service for high-quality speech recognition
class WhisperService {
  static const String _baseUrl = 'https://api.openai.com/v1';

  String get _apiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
    return key;
  }

  /// Transcribe audio file using OpenAI Whisper API
  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      final url = Uri.parse('$_baseUrl/audio/transcriptions');
      
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $_apiKey';
      
      // Add audio file
      final audioFile = File(audioFilePath);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'audio.m4a',
        ),
      );
      
      // Add model parameter
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'en'; // Can be auto-detected
      request.fields['response_format'] = 'text'; // Get plain text response
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return response.body.trim();
      } else {
        throw Exception('Whisper API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  /// Check if audio file exists and is valid
  bool isValidAudioFile(String filePath) {
    final file = File(filePath);
    return file.existsSync() && file.lengthSync() > 0;
  }
}

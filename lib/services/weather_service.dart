import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  String get _apiKey {
    final key = dotenv.env['WEATHER_API_KEY'];
    if (key == null || key.isEmpty || key == 'YOUR_WEATHER_API_KEY') {
      // Return empty string if not configured - weather queries will fail gracefully
      return '';
    }
    return key;
  }

  /// Get current weather by city name
  Future<Map<String, dynamic>?> getWeatherByCity(String cityName) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/weather?q=$cityName&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Weather API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Weather Service Error: $e');
      return null;
    }
  }

  /// Get current weather by coordinates
  Future<Map<String, dynamic>?> getWeatherByLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Weather API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Weather Service Error: $e');
      return null;
    }
  }

  /// Format weather data into a simple description
  String formatWeatherDescription(Map<String, dynamic> weatherData) {
    try {
      final main = weatherData['main'];
      final weather = weatherData['weather'][0];
      final temp = main['temp']?.toStringAsFixed(1) ?? 'N/A';
      final description = weather['description'] ?? 'unknown';
      final city = weatherData['name'] ?? 'your location';

      return 'The weather in $city is $description. The temperature is $temp degrees Celsius.';
    } catch (e) {
      return 'I had trouble getting the weather information. Please try again.';
    }
  }
}

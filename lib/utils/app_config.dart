class AppConfig {
  // API Keys - These should be set by the user
  // For production, these should be stored securely on a backend server
  static const String openAIApiKey = 'YOUR_OPENAI_API_KEY';
  static const String weatherApiKey = 'YOUR_WEATHER_API_KEY';
  
  // Default city for weather (can be changed based on user location)
  static const String defaultCity = 'Karachi';
}

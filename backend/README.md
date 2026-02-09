# Voice AI Assistant - Backend API

Node.js backend server for the Voice AI Assistant mobile application.

## Features

- ✅ Chat completion with conversation history
- ✅ Text-to-speech generation
- ✅ Conversation insights generation
- ✅ CORS enabled for mobile app
- ✅ Environment variable configuration

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and add your OpenAI API key:
   ```
   OPENAI_API_KEY=your_actual_api_key_here
   PORT=3000
   ```

3. **Start the server:**
   ```bash
   npm start
   ```
   
   Or for development with auto-reload:
   ```bash
   npm run dev
   ```

## API Endpoints

### Health Check
```
GET /health
```

### Chat Completion
```
POST /api/chat
Body: {
  "message": "User message",
  "conversationHistory": [Array of previous messages],
  "language": "en-US" or "ur-PK"
}
```

### Text-to-Speech
```
POST /api/tts
Body: {
  "text": "Text to convert to speech",
  "language": "en-US" or "ur-PK"
}
Returns: Audio file (MP3)
```

### Conversation Insights
```
POST /api/insights
Body: {
  "conversationHistory": [Array of conversation messages]
}
Returns: {
  "summary": "...",
  "topics": ["..."],
  "userIntent": "...",
  "conversationTone": "..."
}
```

## Running Locally

The server runs on `http://localhost:3000` by default.

For mobile app testing:
- Android Emulator: Use `http://10.0.2.2:3000`
- iOS Simulator: Use `http://localhost:3000`
- Physical Device: Use your computer's IP address (e.g., `http://192.168.1.100:3000`)

## Production Deployment

For production:
1. Use environment variables for API keys
2. Enable HTTPS
3. Add rate limiting
4. Add authentication
5. Use a process manager like PM2

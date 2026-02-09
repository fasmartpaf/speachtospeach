const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const OpenAI = require('openai');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Voice AI Backend is running' });
});

// Chat completion endpoint with conversation history
app.post('/api/chat', async (req, res) => {
  try {
    const { message, conversationHistory = [], language } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }

    // Detect language for tone adaptation
    const isUrdu = /[\u0600-\u06FF]/.test(message);

    // System prompt based on language - Running Trainer Personality
    const systemPrompt = isUrdu
      ? `آپ ایک دوستانہ رننگ ٹرینر ہیں جو اردو میں بات کر رہے ہیں۔
بہت قدرتی، گرم جوشی سے، اور حوصلہ افزائی کرنے والے انداز میں بات کریں۔
بہت سادہ، روزمرہ کی زبان استعمال کریں۔
صرف 1-2 جملے میں جواب دیں، بہت مختصر۔
کبھی بھی یہ نہ کہیں کہ آپ AI ہیں۔ ایک مددگار رننگ کوچ کی طرح بات کریں۔
رننگ کے بارے میں مشورہ دیں، حوصلہ افزائی کریں، اور دوستانہ رہیں۔
پرسکون اور مطمئن کرنے والے انداز میں بات کریں۔`
      : `You are a friendly running trainer and coach.
Speak very naturally, warmly, and encouragingly like a real running coach would.
Use very simple, everyday language.
Keep responses to just 1-2 sentences, very short.
Never mention you are an AI. Talk like a helpful running coach.
Provide running advice, encouragement, and motivation.
Be calm, reassuring, and natural.
Talk like a supportive running buddy or coach.`;

    const styleRules = `
CRITICAL RULES:
- Maximum 2 sentences
- Use daily conversation style
- No phrases like "As an AI", "I am an AI assistant", "Based on data"
- Vary your phrasing naturally
- Keep tone calm and neutral-friendly`;

    // Build messages array with history
    const messages = [
      { role: 'system', content: `${systemPrompt}\n\n${styleRules}` },
      ...conversationHistory,
      { role: 'user', content: message },
    ];

    // Call OpenAI API
    const completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: messages,
      max_tokens: 60,
      temperature: 0.9,
    });

    const aiResponse = completion.choices[0].message.content.trim();

    res.json({
      response: aiResponse,
      language: isUrdu ? 'ur-PK' : 'en-US',
    });
  } catch (error) {
    console.error('Chat API Error:', error);
    res.status(500).json({
      error: 'Failed to get AI response',
      message: error.message,
    });
  }
});

// Text-to-speech endpoint
app.post('/api/tts', async (req, res) => {
  try {
    const { text, language } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }

    // Select voice based on language
    const voice = language?.startsWith('ur') ? 'nova' : 'alloy';
    const speed = language?.startsWith('ur') ? 0.9 : 1.0;

    // Generate speech using OpenAI TTS
    const mp3 = await openai.audio.speech.create({
      model: 'tts-1',
      voice: voice,
      input: text,
      speed: speed,
    });

    // Convert response to buffer
    const buffer = Buffer.from(await mp3.arrayBuffer());

    // Send audio file
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Content-Length', buffer.length);
    res.send(buffer);
  } catch (error) {
    console.error('TTS API Error:', error);
    res.status(500).json({
      error: 'Failed to generate speech',
      message: error.message,
    });
  }
});

// In-memory storage for MVP (replace with database in production)
const users = {}; // Store user credentials
const userProfiles = {};
const runSessions = {};

// User authentication endpoints
app.post('/api/auth/signup', (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // Check if user already exists
    if (users[email]) {
      return res.status(409).json({ error: 'User already exists' });
    }

    // Create new user (in production, hash the password!)
    const userId = Date.now().toString();
    users[email] = {
      id: userId,
      email: email,
      password: password, // In production, hash this!
      createdAt: new Date().toISOString(),
    };

    res.json({ success: true, userId: userId });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

app.post('/api/auth/login', (req, res) => {
  try {
    const { email, password, phone } = req.body;
    
    // For MVP, we'll accept either email or phone
    let user = null;
    if (email) {
      user = users[email];
      if (user && user.password === password) {
        res.json({ success: true, userId: user.id });
      } else {
        res.status(401).json({ error: 'Invalid credentials' });
      }
    } else if (phone) {
      // For phone login, create user if doesn't exist (MVP)
      const userId = Date.now().toString();
      users[phone] = {
        id: userId,
        phone: phone,
        createdAt: new Date().toISOString(),
      };
      res.json({ success: true, userId: userId });
    } else {
      res.status(400).json({ error: 'Email or phone is required' });
    }
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// User Profile endpoints
app.post('/api/user/profile', (req, res) => {
  try {
    const profile = req.body;
    userProfiles[profile.id] = profile;
    res.json({ success: true, profile });
  } catch (error) {
    console.error('Save profile error:', error);
    res.status(500).json({ error: 'Failed to save profile' });
  }
});

app.get('/api/user/profile/:userId', (req, res) => {
  try {
    const { userId } = req.params;
    const profile = userProfiles[userId];
    if (profile) {
      res.json(profile);
    } else {
      res.status(404).json({ error: 'Profile not found' });
    }
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Failed to get profile' });
  }
});

// Run Sessions endpoints
app.post('/api/runs', (req, res) => {
  try {
    const session = req.body;
    runSessions[session.id] = session;
    
    // Store by user ID if available
    if (session.userId) {
      if (!runSessions[session.userId]) {
        runSessions[session.userId] = [];
      }
      runSessions[session.userId].push(session);
    }
    
    res.json({ success: true, session });
  } catch (error) {
    console.error('Save run error:', error);
    res.status(500).json({ error: 'Failed to save run' });
  }
});

app.put('/api/runs/:sessionId', (req, res) => {
  try {
    const { sessionId } = req.params;
    const session = req.body;
    
    if (runSessions[sessionId]) {
      runSessions[sessionId] = session;
      res.json({ success: true, session });
    } else {
      res.status(404).json({ error: 'Run session not found' });
    }
  } catch (error) {
    console.error('Update run error:', error);
    res.status(500).json({ error: 'Failed to update run' });
  }
});

app.get('/api/runs', (req, res) => {
  try {
    const { userId } = req.query;
    
    if (userId && runSessions[userId]) {
      // Return runs for specific user
      res.json(runSessions[userId]);
    } else {
      // Return all runs (for MVP)
      const allRuns = Object.values(runSessions).filter(
        item => item && item.id && item.conversationId
      );
      res.json(allRuns);
    }
  } catch (error) {
    console.error('Get runs error:', error);
    res.status(500).json({ error: 'Failed to get runs' });
  }
});

app.get('/api/runs/:sessionId', (req, res) => {
  try {
    const { sessionId } = req.params;
    const session = runSessions[sessionId];
    
    if (session) {
      res.json(session);
    } else {
      res.status(404).json({ error: 'Run session not found' });
    }
  } catch (error) {
    console.error('Get run error:', error);
    res.status(500).json({ error: 'Failed to get run' });
  }
});

// Generate conversation insights
app.post('/api/insights', async (req, res) => {
  try {
    const { conversationHistory } = req.body;

    if (!conversationHistory || conversationHistory.length === 0) {
      return res.status(400).json({ error: 'Conversation history is required' });
    }

    const insightPrompt = `Analyze this conversation and provide insights:
- Summary (2-3 sentences)
- Main topics discussed (list)
- User intent (general description)
- Conversation tone (casual/formal/polite)

Conversation:
${conversationHistory.map(m => `${m.role}: ${m.content}`).join('\n')}

Provide insights in JSON format:
{
  "summary": "...",
  "topics": ["..."],
  "userIntent": "...",
  "conversationTone": "..."
}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: insightPrompt }],
      max_tokens: 200,
      temperature: 0.7,
    });

    const insightsText = completion.choices[0].message.content.trim();
    
    // Try to parse JSON from response
    let insights;
    try {
      insights = JSON.parse(insightsText);
    } catch (e) {
      // If not JSON, create structured response
      insights = {
        summary: insightsText,
        topics: [],
        userIntent: 'General conversation',
        conversationTone: 'Casual',
      };
    }

    res.json(insights);
  } catch (error) {
    console.error('Insights API Error:', error);
    res.status(500).json({
      error: 'Failed to generate insights',
      message: error.message,
    });
  }
});

// Onboarding Analytics endpoint
app.post('/api/onboarding/analytics', async (req, res) => {
  try {
    const { answers } = req.body;

    if (!answers) {
      return res.status(400).json({ error: 'Answers are required' });
    }

    // Create a conversation history from answers
    const conversationHistory = [];
    const questions = [
      'What is your primary running goal right now?',
      'Is there a specific event you are training for?',
      'What is your most recent race result?',
      'On which days of the week can you run?',
    ];

    let index = 0;
    for (const [key, value] of Object.entries(answers)) {
      if (value != null && value.toString().isNotEmpty) {
        conversationHistory.push({
          role: 'user',
          content: `Question: ${questions[index] || key}\nAnswer: ${value}`,
        });
      }
      index++;
    }

    const insightPrompt = `Analyze this onboarding interview and provide insights:
- Summary (2-3 sentences about the user's running goals and preferences)
- Main topics discussed (list of key topics)
- User intent (what the user wants to achieve)
- Conversation tone (casual/formal/polite)

Interview Answers:
${JSON.stringify(answers, null, 2)}

Provide insights in JSON format:
{
  "summary": "...",
  "topics": ["..."],
  "userIntent": "...",
  "conversationTone": "..."
}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: insightPrompt }],
      max_tokens: 300,
      temperature: 0.7,
    });

    const insightsText = completion.choices[0].message.content.trim();
    
    // Try to parse JSON from response
    let insights;
    try {
      insights = JSON.parse(insightsText);
    } catch (e) {
      // If not JSON, create structured response
      insights = {
        summary: insightsText,
        topics: Object.keys(answers).filter(k => answers[k] != null),
        userIntent: 'Running training and goal setting',
        conversationTone: 'Casual',
      };
    }

    res.json(insights);
  } catch (error) {
    console.error('Analytics API Error:', error);
    res.status(500).json({
      error: 'Failed to generate analytics',
      message: error.message,
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Voice AI Backend running on http://localhost:${PORT}`);
  console.log(`📝 Health check: http://localhost:${PORT}/health`);
});

const express = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const rateLimit = require('express-rate-limit');

const router = express.Router();

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Chat rate limit: 60 messages per hour per user
const chatLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 60,
  keyGenerator: (req) => req.user.id,
  message: { error: 'Chat rate limit reached. Please wait before sending more messages.' }
});

// Injury keywords — server-side detection layer (PRD §11, Risk Register)
const INJURY_KEYWORDS = [
  'pain', 'hurt', 'injured', 'injury', 'strain', 'sprain', 'pulled',
  'torn', 'shoulder pain', 'knee pain', 'back pain', 'wrist pain',
  'sharp pain', 'can\'t lift', 'swelling', 'bruising'
];

const SWAP_KEYWORDS = [
  'swap', 'replace', 'change exercise', 'substitute', 'instead of',
  'alternative to', 'can i do', 'don\'t have'
];

const CHAT_SYSTEM_PROMPT = `You are a senior powerlifting coach AI assistant — knowledgeable, supportive, and evidence-based.

Your role:
- Answer questions about powerlifting technique, programming, nutrition basics, and recovery
- Help athletes understand their training program
- Suggest exercise modifications when asked
- Take injury reports VERY seriously — always recommend seeing a medical professional for real injuries
- Keep responses concise and practical
- NEVER prescribe specific medical diagnoses

If the user reports an injury:
1. Express concern and stop recommending heavy loading for that area
2. Suggest deloading or modifying the program
3. Always recommend seeing a sports medicine doctor or physio
4. Flag it as important context for future programming

If the user asks to swap an exercise:
1. Confirm the swap makes training sense
2. Suggest a biomechanically similar alternative
3. Confirm the change will be reflected in their next program

Always respond in English. Be concise — 2–4 sentences unless detail is needed.`;

// ─── POST /api/chat ───────────────────────────────────────────────────────────

router.post('/', chatLimiter, async (req, res, next) => {
  try {
    const { message, history, profile, current_program } = req.body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'message is required' });
    }

    if (message.length > 2000) {
      return res.status(400).json({ error: 'message too long (max 2000 chars)' });
    }

    const trimmedMessage = message.trim();
    const lowerMsg = trimmedMessage.toLowerCase();

    // Server-side keyword detection
    const hasInjury = INJURY_KEYWORDS.some(kw => lowerMsg.includes(kw));
    const hasSwap = SWAP_KEYWORDS.some(kw => lowerMsg.includes(kw));

    // Persist user message
    await supabase.from('chat_messages').insert({
      user_id: req.user.id,
      role: 'user',
      content: trimmedMessage,
      flagged_injury: hasInjury,
      flagged_exercise_swap: hasSwap
    });

    // Build conversation history (last 20 messages per PRD)
    const recentHistory = (Array.isArray(history) ? history : []).slice(-20);

    // Build context string
    let contextStr = '';
    if (profile) {
      contextStr += `\nATHLETE: ${profile.first_name}, ${profile.experience_level}, goal: ${profile.goal}, trains ${profile.training_days_per_week}x/week`;
    }
    if (current_program) {
      contextStr += `\nCURRENT PROGRAM: Week ${current_program.week_number}, ${current_program.block} block`;
    }
    if (hasInjury) {
      contextStr += '\n⚠️ INJURY KEYWORD DETECTED in this message — respond with appropriate caution.';
    }

    // Build messages array for Claude
    const messages = [
      ...recentHistory.map(h => ({
        role: h.role,
        content: h.content
      })),
      {
        role: 'user',
        content: contextStr ? `[Context:${contextStr}]\n\n${trimmedMessage}` : trimmedMessage
      }
    ];

    const response = await anthropic.messages.create({
      model: 'claude-opus-4-6',
      max_tokens: 1024,
      system: CHAT_SYSTEM_PROMPT,
      messages
    });

    const reply = response.content[0].text.trim();

    // Persist assistant message
    await supabase.from('chat_messages').insert({
      user_id: req.user.id,
      role: 'assistant',
      content: reply,
      flagged_injury: false,
      flagged_exercise_swap: false
    });

    res.json({ reply, flagged_injury: hasInjury, flagged_swap: hasSwap });
  } catch (err) {
    next(err);
  }
});

module.exports = router;

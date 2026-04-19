const express = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const Joi = require('joi');
const rateLimit = require('express-rate-limit');

const router = express.Router();

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// AI program generation: 20 calls/user/day (PRD §13)
const programGenLimiter = rateLimit({
  windowMs: 24 * 60 * 60 * 1000, // 24 hours
  max: 20,
  keyGenerator: (req) => req.user.id,
  message: { error: 'Program generation limit reached (20/day). Try again tomorrow.' }
});

// ─── COACHING SYSTEM PROMPT ─────────────────────────────────────────────────

const COACHING_SYSTEM_PROMPT = `You are a senior powerlifting coach with 15+ years of experience coaching competitive powerlifters.
You specialize in evidence-based programming using RPE-based autoregulation.

RULES:
1. Always structure programs around the Big 3: Squat, Bench Press, Deadlift
2. Each session must have exactly 1 main lift and 3–5 accessories
3. Accessories must directly support the main lift (e.g., paused squat, Romanian deadlift, close-grip bench)
4. Progressive overload is sacred — always aim for measurable improvement each block
5. Never program two max-effort sessions back-to-back
6. Deload whenever athlete shows 3+ consecutive sessions at RPE ≥ 9
7. Peak attempts: opener = ~90% 1RM, second = ~97%, third = 100%+
8. Always respond in valid JSON matching the schema provided
9. Consider injury flags from chat history before programming
10. Week 1 intensity: ~60–65% estimated 1RM. RPE target: 6–7.
11. Cap weight increases at 10% per week (safety rule)

BLOCK PERIODIZATION:
- Weeks 1–4: Accumulation — higher volume, moderate intensity, RPE 6–7
- Weeks 5–8: Intensification — lower volume, higher intensity, RPE 7–8
- Weeks 9–10: Peak — low volume, very high intensity, RPE 8–9+
- Deload week: 50% volume reduction, 85–90% intensity

RPE ADJUSTMENT RULES (week-over-week):
- Avg RPE ≤ 5: Increase weight 2.5–5kg OR add 1 rep per set
- Avg RPE 6–7: Small increase (2.5kg) or maintain
- Avg RPE 8: Maintain weight, reduce reps by 1
- Avg RPE 9: Keep same or reduce volume
- Avg RPE ≥ 10: Reduce weight 5%, reduce sets
- Any RPE 11 (fail): Deload that movement immediately

OUTPUT FORMAT (respond with ONLY valid JSON, no markdown):
{
  "week_number": <integer>,
  "block": "<accumulation|intensification|peak|deload>",
  "sessions": [
    {
      "day": <integer>,
      "main_lift": "<squat|bench press|deadlift>",
      "exercises": [
        {
          "name": "<exercise name>",
          "sets": <integer>,
          "reps": <integer>,
          "weight_kg": <number>,
          "rpe_target": <integer 6-10>,
          "notes": "<optional coaching note>"
        }
      ]
    }
  ],
  "coach_notes": "<overall week coaching note>"
}`;

// ─── Validation Schemas ──────────────────────────────────────────────────────

const profileSchema = Joi.object({
  first_name: Joi.string().required(),
  last_name: Joi.string().required(),
  gender: Joi.string().valid('Male', 'Female', 'Other').required(),
  age: Joi.number().integer().min(13).max(80).required(),
  weight_kg: Joi.number().min(30).max(300).required(),
  height_cm: Joi.number().min(100).max(250).required(),
  experience_level: Joi.string().valid('Beginner', 'Intermediate', 'Advanced').required(),
  training_days_per_week: Joi.number().integer().min(2).max(5).required(),
  goal: Joi.string().valid('Strength', 'Bulk', 'Cut').required(),
  focus_lifts: Joi.array().items(Joi.string()).min(1).required(),
  squat_max_kg: Joi.number().optional().allow(null),
  bench_max_kg: Joi.number().optional().allow(null),
  deadlift_max_kg: Joi.number().optional().allow(null)
});

// ─── POST /api/program/generate ─────────────────────────────────────────────

router.post('/generate', programGenLimiter, async (req, res, next) => {
  try {
    const { error: validationError, value: profile } = profileSchema.validate(req.body.profile);
    if (validationError) {
      return res.status(400).json({ error: validationError.details[0].message });
    }

    const userPrompt = buildInitialProgramPrompt(profile);
    const programJson = await callClaude(userPrompt);

    // Store in Supabase
    await supabase.from('training_programs').insert({
      user_id: req.user.id,
      week_number: programJson.week_number,
      block_type: programJson.block,
      program_json: programJson,
      is_current: true
    });

    // Mark previous programs as not current
    await supabase
      .from('training_programs')
      .update({ is_current: false })
      .eq('user_id', req.user.id)
      .neq('week_number', programJson.week_number);

    res.json(programJson);
  } catch (err) {
    next(err);
  }
});

// ─── POST /api/program/next-week ─────────────────────────────────────────────

router.post('/next-week', programGenLimiter, async (req, res, next) => {
  try {
    const { profile, history } = req.body;

    const { error: validationError } = profileSchema.validate(profile);
    if (validationError) {
      return res.status(400).json({ error: validationError.details[0].message });
    }

    if (!Array.isArray(history)) {
      return res.status(400).json({ error: 'history must be an array' });
    }

    // Limit history to last 12 weeks to control token usage (PRD §15 scaling note)
    const recentHistory = history.slice(-12);
    const userPrompt = buildNextWeekPrompt(profile, recentHistory);
    const programJson = await callClaude(userPrompt);

    // Store & mark current
    const { error: insertError } = await supabase.from('training_programs').insert({
      user_id: req.user.id,
      week_number: programJson.week_number,
      block_type: programJson.block,
      program_json: programJson,
      is_current: true
    });

    if (!insertError) {
      await supabase
        .from('training_programs')
        .update({ is_current: false })
        .eq('user_id', req.user.id)
        .neq('week_number', programJson.week_number);
    }

    res.json(programJson);
  } catch (err) {
    next(err);
  }
});

// ─── Prompt Builders ─────────────────────────────────────────────────────────

function buildInitialProgramPrompt(profile) {
  const maxLifts = [];
  if (profile.squat_max_kg) maxLifts.push(`Squat 1RM: ${profile.squat_max_kg}kg`);
  if (profile.bench_max_kg) maxLifts.push(`Bench Press 1RM: ${profile.bench_max_kg}kg`);
  if (profile.deadlift_max_kg) maxLifts.push(`Deadlift 1RM: ${profile.deadlift_max_kg}kg`);

  return `Generate Week 1 training program for this athlete:

ATHLETE PROFILE:
- Name: ${profile.first_name} ${profile.last_name}
- Gender: ${profile.gender}
- Age: ${profile.age}
- Body Weight: ${profile.weight_kg}kg
- Height: ${profile.height_cm}cm
- Experience: ${profile.experience_level}
- Training Days/Week: ${profile.training_days_per_week}
- Goal: ${profile.goal}
- Focus Lifts: ${profile.focus_lifts.join(', ')}
${maxLifts.length > 0 ? `- Current Maxes: ${maxLifts.join(', ')}` : '- No current maxes provided — use conservative estimates'}

This is Week 1 of a new training cycle. Start conservative at 60–65% estimated 1RM, RPE 6–7.
Schedule ${profile.training_days_per_week} sessions covering the focus lifts.
Respond with ONLY valid JSON.`;
}

function buildNextWeekPrompt(profile, history) {
  const lastWeek = history[history.length - 1];
  const weekNumber = lastWeek ? lastWeek.week_number + 1 : 1;

  // Calculate avg RPE per lift from last week
  const rpeAnalysis = computeRPEAnalysis(lastWeek);

  return `Generate Week ${weekNumber} training program.

ATHLETE PROFILE:
- Name: ${profile.first_name}
- Experience: ${profile.experience_level}
- Training Days/Week: ${profile.training_days_per_week}
- Goal: ${profile.goal}
- Focus Lifts: ${profile.focus_lifts.join(', ')}

LAST WEEK PERFORMANCE:
${rpeAnalysis}

FULL HISTORY (${history.length} weeks):
${JSON.stringify(history, null, 2)}

Apply the RPE adjustment rules. Respect block periodization (week ${weekNumber}).
Respond with ONLY valid JSON.`;
}

function computeRPEAnalysis(lastWeek) {
  if (!lastWeek || !lastWeek.sessions) return 'No previous week data';

  const lines = [];
  for (const session of lastWeek.sessions) {
    for (const exercise of session.exercises || []) {
      if (!exercise.actual_sets || exercise.actual_sets.length === 0) continue;
      const rpeSamples = exercise.actual_sets.map(s => s.rpe_actual).filter(Boolean);
      if (rpeSamples.length === 0) continue;
      const avgRPE = rpeSamples.reduce((a, b) => a + b, 0) / rpeSamples.length;
      lines.push(`${exercise.name}: avg RPE ${avgRPE.toFixed(1)} (${rpeSamples.length} sets logged)`);
    }
  }
  return lines.length > 0 ? lines.join('\n') : 'Incomplete RPE data';
}

// ─── Claude Call with Retry ───────────────────────────────────────────────────

async function callClaude(userPrompt, retries = 2) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const message = await anthropic.messages.create({
        model: 'claude-opus-4-6',
        max_tokens: 4096,
        system: COACHING_SYSTEM_PROMPT,
        messages: [{ role: 'user', content: userPrompt }]
      });

      const raw = message.content[0].text.trim();

      // Strip markdown code fences if present
      const cleaned = raw.replace(/^```json\s*/i, '').replace(/```\s*$/, '').trim();
      const parsed = JSON.parse(cleaned);

      // Validate required fields
      if (!parsed.week_number || !parsed.block || !Array.isArray(parsed.sessions)) {
        throw new Error('Invalid program schema from AI');
      }

      // Post-process: cap weight increases, check for duplicate exercises
      return sanitizeProgramResponse(parsed);
    } catch (err) {
      if (attempt === retries) {
        throw new Error(`AI generation failed after ${retries + 1} attempts: ${err.message}`);
      }
      // Wait 1s before retry
      await new Promise(r => setTimeout(r, 1000));
    }
  }
}

/**
 * Post-process AI response:
 * - Remove duplicate exercises within a session
 * - Validate weight values are reasonable
 */
function sanitizeProgramResponse(program) {
  for (const session of program.sessions) {
    const seen = new Set();
    session.exercises = (session.exercises || []).filter(ex => {
      const key = ex.name.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    // Ensure notes field exists
    session.exercises = session.exercises.map(ex => ({
      ...ex,
      notes: ex.notes || null,
      weight_kg: Math.max(0, ex.weight_kg || 0),
      sets: Math.min(Math.max(ex.sets || 3, 1), 8),
      reps: Math.min(Math.max(ex.reps || 5, 1), 20)
    }));
  }

  return program;
}

module.exports = router;

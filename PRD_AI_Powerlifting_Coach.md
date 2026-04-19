# PRD – AI Powerlifting Coach App
**Version:** 1.1 (MVP – iOS Native)  
**Date:** March 2026  
**Author:** Product & Architecture Spec  
**Target:** Claude Code – Full Implementation Brief  
**Platform:** iOS only (iPhone) — Android & Web deferred to v2

---

## 1. Executive Summary

An AI-powered powerlifting coaching **iOS native application** (iPhone) that generates personalized, progressive training programs based on the athlete's profile, goals, and weekly RPE feedback. The AI coach behaves as a senior powerlifting coach who plans periodized blocks, tapers, deloads, and peak attempts — all dynamically adjusted per user performance.

Built natively in **SwiftUI** with Apple's **Liquid Glass** design language (iOS 26+), delivering a premium, platform-native experience. Android and Web are explicitly deferred to v2 after MVP validation.

---

## 2. Tech Stack Recommendations

| Layer | Choice | Rationale |
|---|---|---|
| iOS UI Framework | **SwiftUI** | Native Apple framework, best-in-class performance and animations |
| Design Language | **Apple Liquid Glass (iOS 26+)** | Native glassmorphism — `ultraThinMaterial`, `.regularMaterial`, blur effects |
| Language | **Swift 6** | Latest Swift with strict concurrency |
| Backend | **Node.js + Express** | Lightweight API server; rapid development |
| Database | **PostgreSQL via Supabase** | Relational structure fits training data; auth + realtime out of the box |
| AI Provider | **Claude (Anthropic)** | Best structured JSON output, complex coaching reasoning, long context |
| Auth | **Sign in with Apple** (primary) + Supabase Auth | Apple Sign-In required for App Store; Supabase handles email/SMS OTP |
| Local Storage | **SwiftData** (iOS 17+) | Offline-first session logging, syncs to Supabase when online |
| Notifications | **UserNotifications framework** | Native iOS push notifications via APNs |
| Networking | **URLSession + async/await** | Native Swift networking, no third-party dependencies |
| Charts | **Swift Charts** (iOS 16+) | Native Apple charting, zero dependencies |
| Deployment | **Xcode + TestFlight → App Store** | Standard iOS distribution |
| Android (v2) | Deferred | React Native or Kotlin — after iOS MVP validation |
| Web (v2) | Deferred | React + Next.js — after iOS MVP validation |

---

## 3. AI Provider Decision: Claude (Anthropic)

**Why Claude over GPT-4:**
- Superior structured JSON output for workout programs
- Better at following strict coaching logic rules in system prompts
- Stronger reasoning for periodization and progressive overload calculations
- Context window sufficient for full training history in prompt

**Integration:** All AI calls go through a secure backend proxy. The API key is **never** exposed to the client.

---

## 4. Goals & Non-Goals

### Goals (MVP)
- User onboarding with detailed athlete profile questionnaire
- AI-generated weekly training programs with correct powerlifting periodization
- RPE-based feedback loop after each session
- Dynamic program adjustment week over week
- Block periodization: accumulation → intensification → peak → deload
- Interactive chat with the AI coach
- Progress tracking with graphs
- Workout reminders (push notifications)
- UI language: English only (Hebrew deferred to v2)

### Non-Goals (MVP – defer to v2)
- Nutrition / calorie tracking
- Social sharing of progress
- Video form analysis
- Group/team features
- Wearable integrations

---

## 5. User Personas

**Primary:** Male/female, age 18–40, intermediate powerlifter, trains 3–5x/week, goal is strength progression on squat/bench/deadlift.

**Secondary:** Beginner who wants structured guidance but no personal coach budget.

---

## 6. Authentication & Onboarding

### 6.1 Auth Methods
- **Sign in with Apple** (primary — required by App Store guidelines when any social login exists)
- Email + password
- SMS OTP (phone number via Supabase)
- Google OAuth (via Supabase, presented in webview)

**Note:** Microsoft OAuth deferred to v2. Apple Sign-In must be offered as an option whenever third-party login exists (App Store rule).

### 6.2 First-Time User Flow
1. User opens app → sees splash screen with "Sign In / Sign Up"
2. Selects auth method → completes auth
3. Redirected to **Athlete Profile Questionnaire** (animated, card-by-card)
4. After questionnaire → AI generates first weekly training program
5. User lands on **Home / Dashboard**

### 6.3 Returning User Flow
1. Opens app → auto-login via session token
2. Lands directly on current week's training dashboard

---

## 7. Athlete Profile Questionnaire

Presented as **animated swipeable cards** (one question per screen). Progress bar at top.

| # | Field | Type | Options / Validation |
|---|---|---|---|
| 1 | First Name | Text | Required |
| 2 | Last Name | Text | Required |
| 3 | Gender | Single select | Male / Female / Other |
| 4 | Age | Number | 13–80 |
| 5 | Body Weight (kg) | Number | 30–300 |
| 6 | Height (cm) | Number | 100–250 |
| 7 | Experience Level | Single select | Beginner / Intermediate / Advanced |
| 8 | Training Days/Week | Single select | 2 / 3 / 4 / 5 |
| 9 | Goal | Single select | Cut / Bulk / Strength (Neutral) |
| 10 | Focus Lifts | Multi-select | Squat / Bench Press / Deadlift |

**UX Notes (SwiftUI implementation):**
- Each card slides in with `.spring()` animation using `withAnimation`
- Selected option highlights with `.ultraThinMaterial` glass glow + blue border
- "Next" button uses `.buttonStyle(.borderedProminent)` — disabled until answer provided
- Back navigation via `NavigationStack` with `.navigationTransition(.slide)`
- Final card: summary `List` with `.listStyle(.insetGrouped)` before submission
- All text left-to-right (LTR), English only

---

## 8. Training Program Logic (Core AI Coaching Engine)

### 8.1 Program Structure

Each training week consists of N sessions (based on days/week chosen). Each session contains:
- **1 Main Lift** (Squat, Bench, or Deadlift)
- **3–5 Accessory Exercises** that support the main lift

**Main lift rotation example (3 days/week):**
- Day 1: Squat
- Day 2: Bench Press
- Day 3: Deadlift
(Adjusted based on user's focus lifts)

### 8.2 Initial Program Generation

When generating the first program, Claude receives a system prompt with:
- Full athlete profile
- Coaching rules (see Section 8.6)
- Request for Week 1 program in structured JSON

**Week 1 parameters:**
- Intensity: ~60–65% of estimated 1RM (conservative start)
- Sets: 3–4
- Reps: 5–8 (depending on lift and level)
- RPE target: ~6–7 (athlete should feel it but not struggle)

### 8.3 RPE Feedback System

After each exercise in a session, the user rates their RPE on a scale of **1–11**:

| RPE | Meaning |
|---|---|
| 1–3 | Very easy, no effort |
| 4–5 | Light, could do many more reps |
| 6–7 | Moderate, a few reps in reserve |
| 8–9 | Hard, 1–2 reps left |
| 10 | Maximum effort, 0 reps left |
| 11 | Failed the rep |

The RPE is logged per set, per exercise, per session.

### 8.4 Week-over-Week Program Adjustment

At end of each week, when user taps "Generate Next Week", the AI receives:
- Previous week's program (exercises, sets, reps, weights)
- RPE ratings for every set
- Athlete's training history (all previous weeks)

**Adjustment logic (Claude system prompt rules):**

| Avg RPE | Action |
|---|---|
| ≤ 5 | Increase weight by 2.5–5kg OR add 1 rep per set |
| 6–7 | Small weight increase (2.5kg) or maintain |
| 8 | Maintain weight, reduce reps by 1 |
| 9 | Keep same or reduce volume |
| ≥ 10 | Reduce weight by 5%, reduce sets |
| 11 (fail) | Deload the movement immediately |

### 8.5 Block Periodization

The AI operates in **mesocycle blocks** (typically 4–6 weeks):

**Block 1 – Accumulation (Weeks 1–4):**
- Higher volume, moderate intensity
- Building work capacity
- RPE 6–7 targets

**Block 2 – Intensification (Weeks 5–8):**
- Lower volume, higher intensity
- RPE 7–8 targets
- Technique refinement

**Block 3 – Peak / Competition Prep (Weeks 9–10):**
- Low volume, very high intensity
- RPE 8–9+
- Singles and near-maximal attempts

**Deload Week (before peak attempts):**
- 50% volume reduction
- 85–90% of normal intensity
- Active recovery focus

**Peak Week:**
- AI presents 3 attempts per main lift (opener / second / third)
- Calculated based on training history and RPE trends
- Classic powerlifting attempt selection logic

### 8.6 Claude System Prompt – Coaching Rules

The backend sends this context with every program generation call:

```
You are a senior powerlifting coach with 15+ years of experience coaching competitive powerlifters.
You specialize in evidence-based programming using RPE-based autoregulation.

RULES:
1. Always structure programs around the Big 3: Squat, Bench, Deadlift
2. Each session must have exactly 1 main lift and 3–5 accessories
3. Accessories must directly support the main lift (e.g., paused squat, Romanian deadlift, close-grip bench)
4. Progressive overload is sacred — always aim for measurable improvement each block
5. Never program two max-effort sessions back-to-back
6. Deload whenever athlete shows 3+ consecutive sessions at RPE ≥ 9
7. Peak attempts: opener = ~90% 1RM, second = ~97%, third = 100%+
8. Always respond in valid JSON matching the schema provided
9. Consider injury flags from chat history before programming
```

### 8.7 Program Output JSON Schema

```json
{
  "week_number": 1,
  "block": "accumulation",
  "sessions": [
    {
      "day": 1,
      "main_lift": "squat",
      "exercises": [
        {
          "name": "Back Squat",
          "sets": 4,
          "reps": 5,
          "weight_kg": 80,
          "rpe_target": 7,
          "notes": "Focus on depth and tempo"
        },
        {
          "name": "Romanian Deadlift",
          "sets": 3,
          "reps": 8,
          "weight_kg": 60,
          "rpe_target": 6,
          "notes": "Accessory for posterior chain"
        }
      ]
    }
  ],
  "coach_notes": "Week 1 – conservative start to assess baseline. Focus on technique."
}
```

---

## 9. Session Execution Flow

1. User opens today's training session
2. Sees list of exercises with sets/reps/weight
3. For each exercise:
   - Taps "Start Set"
   - Logs actual weight used (pre-filled with programmed weight)
   - Logs actual reps completed
   - Rates RPE (1–11 slider)
   - Repeats for each set
4. Completes all exercises → taps "Complete Workout"
5. Session marked complete, timestamp saved
6. Next session in the week becomes unlocked/available

**Session States:**
- `locked` – future sessions (not yet accessible)
- `available` – current session ready to start
- `in_progress` – started but not completed
- `completed` – all exercises logged with RPE

---

## 10. Screens & User Flows

### Screen 1: Splash / Auth
- App logo with Liquid Glass effect
- "Sign In" / "Sign Up" buttons
- Auth method selection

### Screen 2: Onboarding Questionnaire
- Animated card carousel
- Progress indicator (1/10, 2/10...)
- Summary confirmation screen

### Screen 3: Home Dashboard
- Current week overview (e.g., "Week 3 – Accumulation Block")
- 3–5 session cards (each showing main lift + status)
- Next session highlighted / CTA button
- Quick stats: streak, total sessions, current block

### Screen 4: Session View
- Exercise list accordion
- Per-exercise: set logger (weight × reps × RPE)
- Rest timer between sets
- "Complete Workout" button

### Screen 5: Progress & History
- Line graphs: squat/bench/deadlift estimated 1RM over time
- Weekly volume chart
- RPE trend chart
- Session history log

### Screen 6: AI Coach Chat
- iMessage-style chat interface
- User can ask anything about their program, exercises, pain points
- AI responds in English
- Special commands: "Swap exercise X", "I injured my shoulder"
- AI can modify next week's program based on chat context

### Screen 7: Profile & Settings
- Edit profile (weight updates, goals)
- Notification preferences
- Language: English (Hebrew support deferred to v2)
- Subscription status (future)
- Sign out

### Screen 8: End of Week / New Program Generation
- Summary of completed week (volume, avg RPE per lift)
- "Generate Next Week's Program" CTA button
- Loading state while AI generates
- New program preview with confirmation

---

## 11. Solution Architecture

```
┌─────────────────────────────────────────────┐
│              iOS APP (SwiftUI)               │
│   iPhone – iOS 17+ – SwiftData offline      │
└───────────────┬─────────────────────────────┘
                │ HTTPS (URLSession + async/await)
┌───────────────▼─────────────────────────────┐
│           BACKEND (Node.js + Express)        │
│                                             │
│  ┌──────────────┐  ┌───────────────────┐   │
│  │  Auth Module  │  │  Program Module   │   │
│  │ (Supabase)   │  │ (AI orchestrator) │   │
│  └──────────────┘  └────────┬──────────┘   │
│                              │              │
│  ┌──────────────┐  ┌────────▼──────────┐   │
│  │ Session Sync │  │  Claude API       │   │
│  │ Module       │  │  Proxy            │   │
│  └──────────────┘  └───────────────────┘   │
│                                             │
│  ┌──────────────┐  ┌───────────────────┐   │
│  │ Chat Module  │  │ APNs Push         │   │
│  │ (AI chat)    │  │ Notification      │   │
│  └──────────────┘  └───────────────────┘   │
└───────────────┬─────────────────────────────┘
                │
┌───────────────▼─────────────────────────────┐
│              SUPABASE                        │
│  PostgreSQL DB | Auth | Storage | Realtime  │
└─────────────────────────────────────────────┘

LOCAL (on device):
┌─────────────────────────────────────────────┐
│  SwiftData (offline-first)                  │
│  Sessions, SetLogs, cached programs         │
│  Syncs to Supabase when online              │
└─────────────────────────────────────────────┘
```

### Module Breakdown

**Auth Module**
- Handles all auth methods via Supabase Auth
- JWT session management
- User creation trigger → onboarding flag

**Program Module (AI Orchestrator)**
- Receives athlete profile + history
- Builds Claude prompt with coaching rules
- Parses JSON response and validates schema
- Stores program in DB
- Handles retry on malformed AI response

**Session Logging Module**
- SwiftData `@Model` classes for offline-first persistence on device
- RPE logging per set stored locally, synced to Supabase when online
- Session state machine (locked → available → in_progress → completed)
- Conflict resolution: device wins for session data (user is the source of truth)
- Triggers "all sessions complete" event for week-end flow

**Chat Module**
- Maintains conversation history per user
- Sends last N messages + user profile to Claude
- Detects injury keywords → flags for program adjustment
- Detects exercise swap requests → triggers program patch

**Notification Module**
- Native iOS push notifications via `UserNotifications` framework + APNs
- User sets preferred training days and reminder time in Settings
- Local notifications as fallback when offline
- Streak reminders after 2+ days of inactivity

---

## 12. Database Schema

### users
```sql
id UUID PRIMARY KEY
email TEXT
phone TEXT
created_at TIMESTAMP
onboarding_complete BOOLEAN DEFAULT false
preferred_language TEXT DEFAULT 'en'
```

### athlete_profiles
```sql
id UUID PRIMARY KEY
user_id UUID REFERENCES users(id)
first_name TEXT
last_name TEXT
gender TEXT
age INTEGER
weight_kg DECIMAL
height_cm DECIMAL
experience_level TEXT -- beginner / intermediate / advanced
training_days_per_week INTEGER
goal TEXT -- cutting / bulking / strength
focus_lifts TEXT[] -- ['squat', 'bench', 'deadlift']
created_at TIMESTAMP
updated_at TIMESTAMP
```

### training_programs
```sql
id UUID PRIMARY KEY
user_id UUID REFERENCES users(id)
week_number INTEGER
block_type TEXT -- accumulation / intensification / peak / deload
program_json JSONB
generated_at TIMESTAMP
is_current BOOLEAN
```

### training_sessions
```sql
id UUID PRIMARY KEY
program_id UUID REFERENCES training_programs(id)
user_id UUID REFERENCES users(id)
day_number INTEGER
status TEXT -- locked / available / in_progress / completed
started_at TIMESTAMP
completed_at TIMESTAMP
```

### session_exercises
```sql
id UUID PRIMARY KEY
session_id UUID REFERENCES training_sessions(id)
exercise_name TEXT
programmed_sets INTEGER
programmed_reps INTEGER
programmed_weight_kg DECIMAL
rpe_target INTEGER
```

### set_logs
```sql
id UUID PRIMARY KEY
exercise_id UUID REFERENCES session_exercises(id)
set_number INTEGER
actual_weight_kg DECIMAL
actual_reps INTEGER
rpe_actual INTEGER
logged_at TIMESTAMP
```

### chat_messages
```sql
id UUID PRIMARY KEY
user_id UUID REFERENCES users(id)
role TEXT -- user / assistant
content TEXT
created_at TIMESTAMP
flagged_injury BOOLEAN DEFAULT false
flagged_exercise_swap BOOLEAN DEFAULT false
```

---

## 13. Security Requirements

- API key for Claude is stored server-side only (environment variable), never in client
- All API endpoints require valid JWT (Supabase Auth)
- Row Level Security (RLS) on all Supabase tables — users can only read/write their own data
- HTTPS enforced everywhere
- Phone numbers stored hashed
- No PII in logs
- Rate limiting on AI endpoints: max 20 program generation calls per user per day
- Input validation and sanitization on all user inputs
- GDPR-compatible: user can request data deletion

---

## 14. Risk Register

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| Claude returns malformed JSON | High | Medium | Retry with explicit schema reminder; fallback to previous program |
| User reports injury via chat but AI misses it | High | Medium | Keyword detection layer before sending to Claude; flag in DB |
| Incorrect weight recommendations cause injury | Critical | Low | Always add disclaimer; cap weight increases at 10% per week |
| AI generates duplicate exercises in one session | Medium | Medium | Post-processing validation of exercise list |
| App used by minors (age < 16) | High | Low | Age gate at onboarding; ToS confirmation |
| Supabase outage | Medium | Low | SwiftData offline-first — user can complete session without connectivity |
| AI costs explode with scale | Medium | High | Cache program JSON; only call AI for program generation and chat |
| User skips RPE logging | Low | High | Make RPE required before "complete session" unlocks |
| App Store rejection | High | Low | Follow HIG strictly; Privacy manifest required; Sign in with Apple required |
| iOS version fragmentation | Low | Low | Minimum iOS 17 stated clearly; SwiftData requires it |
| SwiftData sync conflicts | Medium | Medium | Last-write-wins with timestamp; device is source of truth for session data |

---

## 15. Missing Requirements / Hidden Assumptions (PRD Critique)

### Missing Requirements
1. **1RM Input** – Should users input their current max lifts during onboarding? Without this, Week 1 weight recommendations are pure guesses. **Recommendation:** Add optional 1RM fields to questionnaire.
2. **Equipment availability** – Home gym vs commercial gym matters for accessory selection. Add to profile.
3. **Previous injuries** – No injury history field in onboarding. Coach needs this before prescribing.
4. **Rest period between sets** – Not specified. Should be shown with a built-in rest timer (native iOS timer).
5. **Offline mode** – Handled by SwiftData, but what happens if user generates a new program without internet? Must show clear error state.
6. **Program modification by user** – Can users manually edit a programmed weight/exercise? Need clear SwiftUI edit flow.
7. **What happens if user misses a week?** – Does the program auto-pause? Reset? Continue?
8. **iPad support** – Not explicitly excluded. Should the app run on iPad? Recommend adaptive layout but iPhone-first.
9. **Dark mode only vs adaptive** – Liquid Glass looks best on dark. Confirm app supports light mode or is dark-only.

### Hidden Assumptions
- Assumes user trains consistently. No logic for inconsistent training history.
- Assumes user's gym has all standard barbells and plates (including 1.25kg increments for microloading).
- Assumes RPE is understood by user. Beginners often cannot self-assess RPE accurately. **Add RPE tutorial on first session.**

### Scaling Risks
- Each "generate next week's program" call sends full training history to Claude. At week 40, prompt size is very large. **Solution:** Summarize history beyond 12 weeks.
- Chat history grows unbounded. **Solution:** Rolling window of last 20 messages.
- If 10,000 users each generate a program on Sunday, Claude API costs spike. **Solution:** Queue with rate limiting.

---

## 16. MVP Feature Scope – iOS (1–2 Months)

### Must Have (MVP)
- [ ] iOS app (Xcode project, SwiftUI, minimum iOS 17)
- [ ] Auth: Sign in with Apple + Email + SMS OTP
- [ ] Onboarding questionnaire (SwiftUI animated cards)
- [ ] AI program generation (Week 1) via Claude API backend
- [ ] Session execution screen + RPE logging (SwiftData offline-first)
- [ ] End-of-week → generate next week's program
- [ ] Block periodization logic (accumulation → peak after 10 weeks)
- [ ] AI coach chat (basic, Hebrew + English)
- [ ] Progress graphs using Swift Charts
- [ ] English-only UI (clean SF Pro, LTR layout)
- [ ] App Store submission (TestFlight beta first)

### Defer to v1.1 (post-MVP iOS)
- [ ] Workout reminders (UserNotifications + APNs)
- [ ] Google OAuth
- [ ] Deload auto-trigger
- [ ] Injury keyword detection in chat
- [ ] HealthKit integration (bodyweight sync)
- [ ] Widgets (workout today widget)

### Defer to v2 (Android + Web + Hebrew)
- [ ] Android app (React Native or Kotlin)
- [ ] Web app (Next.js)
- [ ] Hebrew localization + RTL layout
- [ ] Social sharing
- [ ] Nutrition tracking
- [ ] Microsoft OAuth

---

## 17. Apple Liquid Glass Design System (SwiftUI Native)

### Core Visual Language
Use **native SwiftUI materials** — do NOT fake glassmorphism with custom shaders. Apple's built-in materials render correctly across all display types (OLED, ProMotion, Dark Mode).

```swift
// Background
.background(.ultraThinMaterial)          // frosted glass cards
.background(.regularMaterial)            // sidebars, sheets
.background(.thickMaterial)              // modals

// Custom dark gradient background (behind glass layers)
LinearGradient(
    colors: [Color(hex: "0A0A0F"), Color(hex: "1A1A2E")],
    startPoint: .top, endPoint: .bottom
)
```

### Colors
```swift
// Accent
Color.accentColor = Color(hex: "4F7EFF")   // Electric blue — CTAs, progress
Color(hex: "9B59B6")                        // Purple — AI/coach elements

// Text
Color.primary                               // System white in dark mode
Color.secondary                             // 60% opacity system color
```

### Typography
```swift
// English only — SF Pro (system default, no custom fonts needed)
Font.system(.title, design: .rounded)       // Headers
Font.system(.body)                          // Body
Font.system(.caption)                       // Labels

// All layout is LTR (left-to-right)
// Hebrew localization deferred to v2
```

### Key SwiftUI Components
- **Cards:** `RoundedRectangle` + `.ultraThinMaterial` + `.shadow(radius: 8)`
- **Buttons:** `.buttonStyle(.borderedProminent)` with accent color
- **Lists:** `.listStyle(.insetGrouped)` for settings and session lists
- **Sheets:** `.presentationDetents([.medium, .large])` for chat
- **Navigation:** `NavigationStack` with `.navigationTransition(.slide)`
- **Animations:** `.spring(response: 0.5, dampingFraction: 0.8)` for card transitions

### Minimum iOS Version
**iOS 17** — required for SwiftData. Liquid Glass materials available iOS 13+.

---

## 18. Implementation Notes for Claude Code

### iOS App (Xcode Project Structure)
```
PowerliftingCoach/
├── App/
│   └── PowerliftingCoachApp.swift      // @main, SwiftData container setup
├── Features/
│   ├── Auth/                           // Sign in with Apple, email, SMS
│   ├── Onboarding/                     // Questionnaire card carousel
│   ├── Dashboard/                      // Home screen, weekly overview
│   ├── Session/                        // Active workout, RPE logging
│   ├── Progress/                       // Swift Charts graphs
│   └── Chat/                           // AI coach chat
├── Models/                             // SwiftData @Model classes
├── Services/
│   ├── AIService.swift                 // Claude API calls via URLSession
│   ├── SupabaseService.swift           // Auth + DB sync
│   └── NotificationService.swift      // UserNotifications
└── Resources/
    └── en.lproj/Localizable.strings    // English only (Hebrew deferred to v2)
```

### Build Order
1. **Xcode project setup** — SwiftData container, minimum iOS 17, bundle ID
2. **Auth flow** — Sign in with Apple (AuthenticationServices) + Supabase email/SMS
3. **SwiftData models** — User, AthleteProfile, TrainingProgram, Session, SetLog, ChatMessage
4. **Onboarding questionnaire** — SwiftUI card carousel with spring animations
5. **Backend API** — Node.js on Railway/Render: `/generate-program`, `/chat` endpoints
6. **Session logger** — SwiftData offline-first, background sync to Supabase
7. **Progress charts** — Swift Charts with 1RM estimates over time
8. **AI coach chat** — ScrollView + TextField sheet with `.presentationDetents`
9. **TestFlight** — internal testing before App Store submission

### App Store Requirements
- Privacy manifest (PrivacyInfo.xcprivacy) — required for data collection disclosure
- Sign in with Apple must be offered if any OAuth login exists
- Age rating: 4+ (no mature content) — add 13+ age gate in onboarding
- English-only app — no localization required for initial submission

### Environment Variables (Backend .env)
```
ANTHROPIC_API_KEY=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
```

### iOS App Secrets (Xcode / Info.plist / Keychain)
```
// Supabase anon key — store in Info.plist (not a secret, client-safe)
SUPABASE_URL
SUPABASE_ANON_KEY

// Apple Sign-In — configured via Xcode Signing & Capabilities
// No key needed in code, handled by AuthenticationServices framework
```

---

*End of PRD v1.1 – iOS Native*  
*Next version (v2.0) will cover Android + Web expansion*

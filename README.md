# PL.AI – AI Powerlifting Coach 🏋️

An intelligent iOS powerlifting coaching app powered by Claude AI. PL.AI generates personalized, progressive training programs based on your profile, goals, and weekly RPE feedback — just like having a senior powerlifting coach in your pocket.

---

## Features

- **AI-Generated Programs** — Claude builds your weekly training plan based on your profile and goals
- **RPE-Based Progression** — Rate every set after training; the AI adjusts next week's program automatically
- **Block Periodization** — Accumulation → Intensification → Peak → Deload cycles, just like elite programming
- **Peak & PR Attempts** — After 10 weeks, the AI prepares you for a max attempt with proper tapering
- **AI Coach Chat** — Ask anything about your program, swap exercises, or report injuries
- **Progress Tracking** — Estimated 1RM graphs and volume trends over time
- **Offline-First** — Log your workout even without signal; syncs automatically when back online
- **Apple Liquid Glass UI** — Native SwiftUI with iOS 26 material design

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS App | SwiftUI + Swift 6 + SwiftData |
| Backend | Node.js + Express |
| Database | PostgreSQL via Supabase |
| Auth | Sign in with Apple + Email + SMS OTP |
| AI | Claude (Anthropic) |
| Design | Apple Liquid Glass (ultraThinMaterial) |

---

## Project Structure

```
PL_AI/
├── PowerliftingCoach/          # iOS Xcode project
│   └── PowerliftingCoach/
│       ├── App/                # Entry point, RootView
│       ├── Features/
│       │   ├── Auth/           # Sign in with Apple, Email, Phone
│       │   ├── Onboarding/     # Animated questionnaire cards
│       │   ├── Dashboard/      # Weekly training overview
│       │   ├── Session/        # Active workout + RPE logging
│       │   ├── Progress/       # Swift Charts graphs
│       │   ├── Chat/           # AI coach chat
│       │   ├── EndOfWeek/      # Generate next week's program
│       │   └── Profile/        # User settings
│       ├── Models/             # SwiftData @Model classes
│       ├── Services/           # AIService, AuthManager, SupabaseService
│       └── DesignSystem/       # Colors, materials, components
├── backend/                    # Node.js API server
│   ├── routes/
│   │   ├── program.js          # /api/program/generate, /api/program/next-week
│   │   └── chat.js             # /api/chat
│   ├── middleware/
│   │   └── auth.js             # JWT validation
│   └── server.js
├── supabase/
│   ├── schema.sql              # All tables
│   ├── rls.sql                 # Row Level Security policies
│   └── seed.sql                # Dev seed data
└── SETUP.md                    # Full setup guide
```

---

## Getting Started

See [SETUP.md](./SETUP.md) for the full setup guide including:
- Supabase project setup
- Backend configuration
- Xcode project setup
- Apple Sign-In configuration
- Environment variables

---

## Environment Variables

### Backend (`backend/.env`)
```
ANTHROPIC_API_KEY=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
PORT=3000
NODE_ENV=development
```

### iOS (`Secrets.xcconfig` — never commit this file)
```
SUPABASE_URL=
SUPABASE_ANON_KEY=
BACKEND_URL=
```

---

## How the AI Works

1. **Onboarding** — User answers 10 questions about experience, goals, and focus lifts
2. **Week 1** — Claude generates a conservative program at ~60-65% intensity
3. **After each session** — User rates RPE (1-11) for every set
4. **End of week** — Claude analyzes RPE data and generates an optimized next week
5. **Block progression** — Every 10 weeks: accumulation → peak → deload → PR attempt

The AI coach follows strict powerlifting programming principles:
- Progressive overload on every main lift
- Accessories chosen to support the main movement
- Auto-regulation based on RPE feedback
- Injury-aware programming via chat

---

## Roadmap

### v1.0 (Current — iOS MVP)
- [x] Auth (Apple Sign-In + Email + SMS)
- [x] Onboarding questionnaire
- [x] AI program generation
- [x] Session logging + RPE tracking
- [x] Week-over-week progression
- [x] AI coach chat
- [x] Progress graphs

### v1.1
- [ ] Push notifications (workout reminders)
- [ ] HealthKit integration
- [ ] Deload auto-trigger
- [ ] Home screen widget

### v2.0
- [ ] Android app
- [ ] Web app
- [ ] Hebrew localization
- [ ] Nutrition tracking
- [ ] Social sharing

---

## License

Private project — all rights reserved.

---

*Built with Claude AI + SwiftUI + lots of coffee ☕*

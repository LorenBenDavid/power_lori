# PL.AI – Setup Guide

## Prerequisites
- Xcode 16+ (for iOS 17+, Swift 6, SwiftData)
- Node.js 20+
- A Supabase account (free tier works)
- An Anthropic API key

---

## 1. Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. In **SQL Editor**, run in order:
   - `supabase/schema.sql`
   - `supabase/rls.sql`
3. In **Authentication → Providers**, enable:
   - Email (with confirm email = OFF for dev)
   - Phone (Twilio or Supabase built-in SMS)
   - Apple (requires Apple Developer account)
4. Copy your **Project URL** and **anon key** from Settings → API

---

## 2. Backend Setup

```bash
cd backend
cp .env.example .env
# Edit .env with your keys
npm install
npm run dev       # starts on localhost:3000
```

Deploy to Railway or Render:
- Railway: `railway init && railway up`
- Render: Connect GitHub repo, set environment variables

---

## 3. iOS App Setup

### Create Xcode Project
1. Open Xcode → New Project → iOS App
2. **Product Name:** `PowerliftingCoach`
3. **Bundle ID:** `com.yourcompany.PowerliftingCoach`
4. **Interface:** SwiftUI
5. **Language:** Swift
6. **Minimum Deployment:** iOS 17.0
7. **Storage:** SwiftData ✓

### Add Source Files
Copy all files from `PowerliftingCoach/` into your Xcode project, maintaining the folder structure.

### Configure xcconfig
```bash
cp PowerliftingCoach/Resources/xcconfig/Debug.xcconfig \
   PowerliftingCoach/Resources/xcconfig/Secrets.xcconfig
# Edit Secrets.xcconfig with your Supabase URL, anon key, and backend URL
```

In Xcode → Project → Info → Configurations, set Debug to use `Secrets.xcconfig`.

### Add Capabilities (Xcode → Target → Signing & Capabilities)
- ✅ Sign in with Apple
- ✅ Push Notifications
- ✅ Keychain Sharing

### Info.plist
Ensure `Info.plist` is set as the target's info file. The SUPABASE_URL, SUPABASE_ANON_KEY, and BACKEND_URL keys will be populated from xcconfig.

---

## 4. Apple Sign-In Configuration

1. In Apple Developer Portal → Certificates, IDs & Profiles
2. Select your App ID → Capabilities → Sign In with Apple ✓
3. In Xcode → Signing & Capabilities → Add "Sign in with Apple"
4. In Supabase → Authentication → Providers → Apple:
   - Add your Team ID, Key ID, and private key

---

## 5. Environment Variables Summary

### Backend (.env)
```
ANTHROPIC_API_KEY=       # from console.anthropic.com
SUPABASE_URL=            # https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=  # from Supabase → Settings → API (secret!)
PORT=3000
```

### iOS (xcconfig / Info.plist)
```
SUPABASE_URL=            # same as above
SUPABASE_ANON_KEY=       # from Supabase → Settings → API (public, safe for client)
BACKEND_URL=             # http://localhost:3000 (dev) or https://your-backend.railway.app (prod)
```

---

## 6. Architecture Notes

```
iOS App (SwiftUI)
  └── SwiftData (offline-first local storage)
  └── AuthManager (session state machine)
  └── SyncService (NWPathMonitor → sync on reconnect)
  └── AIService (calls backend, never Claude directly)

Backend (Node.js + Express)
  └── JWT auth middleware (validates Supabase tokens)
  └── /api/program/generate → Claude → validate → store → return
  └── /api/program/next-week → same + RPE history analysis
  └── /api/chat → keyword detection → Claude → store

Supabase
  └── Auth (Apple, Email, SMS OTP)
  └── PostgreSQL + RLS (users own their data)
  └── Service Role used by backend only
```

---

## 7. TestFlight Submission Checklist

- [ ] Bundle ID matches Apple Developer Portal
- [ ] Sign in with Apple capability enabled
- [ ] Privacy manifest (PrivacyInfo.xcprivacy) included
- [ ] App age rating: 4+ (training/fitness)
- [ ] No crash on fresh install (new user flow tested)
- [ ] Offline mode tested (airplane mode during session)
- [ ] App Store screenshots (6.7" iPhone required)

# Chore Tracker

A native SwiftUI family chores app focused on a simple household workflow.

## Current prototype

### Authentication
- Email + 6-digit one-time code
- Codes are delivered through Resend
- Resend API key stays on the server, never in the iOS app
- Verified sessions receive a signed auth token stored in the iOS Keychain
- Backend lives in `backend/`

### Parent
- Home is the main control center
- Add chores directly from Home
- Assigned or claimable chores
- Any emoji can be used for a chore
- Dollar rewards instead of points
- See total money owed and what is owed to each child
- Mark a child's owed balance paid
- Approve completed chores
- Edit or delete active chores
- Recurring schedules stay hidden until their next available date
- Calendar-based family history

### Child
- See assigned chores
- See money currently owed
- Claim open family chores
- Calendar history for completed chores

## Run the iOS app

This repo uses XcodeGen.

```bash
brew install xcodegen
xcodegen generate
open ChoreTracker.xcodeproj
```

Run on iOS 17+.

## Run email authentication locally

```bash
cd backend
cp .env.example .env
npm install
```

Fill in your Resend API key, verified sender, and JWT secret in `.env`, then:

```bash
set -a
source .env
set +a
npm start
```

The iOS Simulator uses `http://127.0.0.1:3000` in DEBUG builds.

Before release, set the production API URL in `AuthConfiguration` inside `ChoreTracker/PhoneAuthService.swift` and serve the API over HTTPS.

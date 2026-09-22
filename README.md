# Chore Tracker

A native SwiftUI family chores app focused on a simple household workflow.

## Features

### Authentication
- Email + 6-digit one-time code
- Codes are delivered through Resend
- Resend API key stays on the server, never in the iOS app
- Verified sessions receive a signed auth token stored in the iOS Keychain
- Restored sessions are checked with the server before use
- Household data is isolated per signed-in account on the device
- Account deletion is available in Profile
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
- Weekly and monthly payment history for every child

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

Release builds use `https://auth.newlifemedia.co` over HTTPS. See `docs/RELEASE_CHECKLIST.md` before submitting a build.

## Product scope

Chore Tracker 1.0 is an offline-first, single-device household manager. A parent can create managed child profiles and switch between family members on that device. Separate signed-in accounts have isolated local household data; cross-device household sharing is not included in 1.0.

# Auth backend

Small Node API for Chore Tracker email OTP authentication.

## What it does

- Generates 6-digit one-time codes
- Sends them through Resend
- Codes expire after 10 minutes
- Limits code requests and verification attempts
- Stores only a keyed hash of the OTP
- Returns a signed 30-day auth token after successful verification

## Setup

```bash
cd backend
cp .env.example .env
npm install
```

Set:

- `RESEND_API_KEY`: your Resend API key
- `RESEND_FROM`: a sender on a domain you verified in Resend
- `JWT_SECRET`: a long random secret
- `PORT`: defaults to 3000

Then:

```bash
set -a
source .env
set +a
npm start
```

For local iOS Simulator development the app points to `http://127.0.0.1:3000`.

Before production, change `AuthConfiguration.apiBaseURL` in the iOS app to your HTTPS VPS API domain.

## Production note

The current OTP store is in memory, which is appropriate for one small VPS process. Move OTPs/rate limits to Redis or Postgres before running multiple API instances.

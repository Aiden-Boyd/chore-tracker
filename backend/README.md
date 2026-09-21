# New Life Media Auth

This backend now uses Better Auth for Chore Tracker authentication and is structured to become the shared identity service for New Life Media apps.

## Current authentication flow

- Email OTP through Better Auth's Email OTP plugin
- Resend delivers the 6-digit code
- Better Auth stores users, sessions, OTP verification records, expiry, and attempt state
- Better Auth's Bearer plugin returns a session token for the native iOS app
- iOS stores that session token in Keychain
- Unknown email addresses are automatically registered when their OTP is successfully verified

The Better Auth HTTP routes are mounted at:

```
/api/auth/*
```

The iOS app uses:

```
POST /api/auth/email-otp/send-verification-otp
POST /api/auth/sign-in/email-otp
```

## Local setup

```bash
cd backend
cp .env.example .env
npm install
```

Generate a Better Auth secret:

```bash
openssl rand -base64 32
```

Put it in `.env` as `BETTER_AUTH_SECRET`.

For local development you can leave `DATABASE_URL` blank. The server will use `auth.sqlite`.

Create/update the Better Auth schema:

```bash
npm run migrate
```

Then run:

```bash
npm start
```

Check it:

```bash
curl http://127.0.0.1:3000/health
```

The response should identify the auth implementation as Better Auth.

## PostgreSQL / production

Set:

```env
BETTER_AUTH_URL=https://auth.newlifemedia.co
DATABASE_URL=postgres://...
DATABASE_SSL=true
```

Then run `npm run migrate` against that database before starting the production service.

Better Auth supports PostgreSQL directly, so the same auth configuration can move from local SQLite to production Postgres without changing the iOS API contract.

## Resend

Set a verified sender, for example:

```env
RESEND_FROM="New Life Media <accounts@newlifemedia.co>"
```

Never place the Resend API key, Better Auth secret, or database credentials in the iOS app or Git repository.

## Migration note

The old custom JWT authentication has been removed. Existing development sessions from that implementation are intentionally not treated as Better Auth sessions. Sign in again after migrating.

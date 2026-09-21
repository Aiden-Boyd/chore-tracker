# New Life Media Shared Account & Authentication Architecture

This document defines a reusable authentication system for all New Life Media apps.

The goal is simple:

> A user should create one New Life Media account and use that same account across every app, while each app still has its own permissions, data, and sessions.

The current Chore Tracker email-code login is the starting point. The production version should become a central identity service rather than being copied independently into each app.

---

## 1. Core idea

Create one central authentication service for all apps.

Recommended production domain:

```
https://auth.newlifemedia.co
```

Every app talks to this service for:

- account creation
- email verification
- sign-in
- session refresh
- sign-out
- account profile
- account deletion
- future passkeys
- future Sign in with Apple
- future recovery methods

Each app keeps its own application data separately.

Example:

```
New Life Media Account
        |
        +-- Chore Tracker
        |
        +-- Vivero
        |
        +-- Social App
        |
        +-- Future apps
```

The authentication service owns identity.

Each individual app owns its own product data.

---

# 2. Important rule: one identity, separate app access

Do not create separate user records for the same person in every app.

Instead, every account gets a permanent global user ID.

Example:

```
user_id = usr_01K7N8...
email = aiden@example.com
```

That `user_id` never changes even if the user changes their email address later.

Apps should reference the global user ID.

Example Chore Tracker membership record:

```json
{
  "userId": "usr_01K7N8...",
  "householdId": "hh_123",
  "role": "parent"
}
```

Vivero could reference that same person:

```json
{
  "userId": "usr_01K7N8...",
  "viveroProfileId": "vp_456"
}
```

The apps know it is the same person without sharing all of their private app data.

---

# 3. What should be global vs app-specific

## Global account data

The central authentication service can own:

- global user ID
- verified email address
- display name
- account creation date
- account status
- authentication methods
- passkeys
- Sign in with Apple linkage
- security/session information
- terms/privacy acceptance versions

Keep this profile intentionally small.

## App-specific data

Each app should own things such as:

### Chore Tracker
- households
- parent/child roles
- chores
- rewards
- payment history
- chore history

### Vivero
- wellness settings
- workouts
- groups
- friends
- sleep preferences
- activity data

### Social app
- friendships
- posts
- hangouts
- messages

Do not put all of this into the shared auth database.

Authentication should identify the user, not become a giant database for every product.

---

# 4. Recommended login flow

For now, use passwordless email verification.

## New account

```
Open app
    ↓
Enter email
    ↓
POST /v1/auth/email/code
    ↓
Resend emails 6-digit code
    ↓
User enters code
    ↓
POST /v1/auth/email/verify
    ↓
Auth server verifies code
    ↓
Account created/found
    ↓
App receives session
    ↓
App-specific onboarding
```

If the email already belongs to an account, verification simply signs the user in.

There should not be separate "sign up" and "log in" screens unless there is a strong UX reason.

---

# 5. Do not let each app send Resend email itself

The iOS app must never contain:

- `RESEND_API_KEY`
- database credentials
- JWT signing keys
- OTP secrets

Instead:

```
iPhone App
    ↓ HTTPS
auth.newlifemedia.co
    ↓
Resend
```

The central auth server is the only component that knows the Resend API key.

This also means every future app gets email auth without needing its own Resend integration.

---

# 6. Recommended API

Use versioned endpoints from day one.

Base:

```
https://auth.newlifemedia.co/v1
```

## Request email code

```
POST /v1/auth/email/code
```

Request:

```json
{
  "email": "user@example.com",
  "clientId": "chore-tracker-ios"
}
```

Response:

```json
{
  "ok": true
}
```

Always return a generic response where practical so attackers cannot easily discover registered email addresses.

---

## Verify email code

```
POST /v1/auth/email/verify
```

Request:

```json
{
  "email": "user@example.com",
  "code": "483921",
  "clientId": "chore-tracker-ios"
}
```

Response:

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "expiresIn": 900,
  "user": {
    "id": "usr_...",
    "email": "user@example.com",
    "displayName": "Aiden"
  }
}
```

---

## Refresh session

```
POST /v1/auth/refresh
```

Request:

```json
{
  "refreshToken": "..."
}
```

Returns a new short-lived access token.

---

## Current account

```
GET /v1/account
Authorization: Bearer ACCESS_TOKEN
```

Response:

```json
{
  "id": "usr_...",
  "email": "user@example.com",
  "displayName": "Aiden"
}
```

---

## Update account

```
PATCH /v1/account
```

Could update:

- display name
- avatar reference
- later, preferred email

Sensitive changes should require re-verification.

---

## Sign out current session

```
POST /v1/auth/logout
```

Invalidate the current refresh token/session.

---

## Sign out everywhere

```
POST /v1/auth/logout-all
```

Revokes all sessions belonging to the user.

---

## Delete account

```
DELETE /v1/account
```

Deletion should be carefully designed because several apps may depend on the same shared identity.

Do not let one product silently delete the user's entire New Life Media account without clearly communicating that it affects all connected apps.

A better product design may include:

- "Delete my Chore Tracker data"
- separately: "Delete my New Life Media account"

---

# 7. Use access tokens + refresh tokens

Do not give the app one JWT that remains valid for 30 days.

Recommended:

### Access token
Short lifetime:

```
15 minutes
```

Used for API requests.

### Refresh token
Long lifetime:

```
30-90 days
```

Used only to obtain another access token.

Refresh tokens should be revocable and stored server-side as a hashed value.

On iOS, store refresh tokens in Keychain.

---

# 8. Token contents

A shared access token might contain:

```json
{
  "sub": "usr_123",
  "sid": "ses_456",
  "aud": "chore-tracker-api",
  "iss": "https://auth.newlifemedia.co",
  "iat": 1780000000,
  "exp": 1780000900
}
```

Avoid putting lots of personal information in JWTs.

Do not put:

- chore data
- wellness data
- family information
- private profile information

inside auth tokens.

---

# 9. App/client registration

Every app should have its own registered client.

Example:

| App | Client ID |
| --- | --- |
| Chore Tracker iOS | `chore-tracker-ios` |
| Vivero iOS | `vivero-ios` |
| Social iOS | `social-ios` |
| Web dashboard | `new-life-web` |

Store clients in the auth database.

Example:

```
auth_clients
------------
id
name
platform
bundle_id
enabled
created_at
```

This lets the auth service know which application requested a login.

---

# 10. Suggested database schema

Postgres is a good fit.

## users

```sql
users
-----
id UUID / ULID PRIMARY KEY
email CITEXT UNIQUE NOT NULL
email_verified_at TIMESTAMP
display_name TEXT
status TEXT
created_at TIMESTAMP
updated_at TIMESTAMP
```

Do not use email as the database primary key.

---

## sessions

```sql
sessions
--------
id
user_id
client_id
refresh_token_hash
device_name
created_at
last_used_at
expires_at
revoked_at
```

This enables:

- list signed-in devices
- revoke one device
- sign out everywhere
- detect unusual session activity later

---

## email_codes

```sql
email_codes
-----------
id
email
code_hash
client_id
expires_at
attempt_count
created_at
used_at
```

Codes should normally expire after about 10 minutes.

Never store the raw OTP code.

---

## auth_clients

```sql
auth_clients
------------
id
name
platform
bundle_id
created_at
disabled_at
```

---

## identities

Add this table before supporting multiple sign-in methods.

```sql
identities
----------
id
user_id
provider
provider_subject
created_at
```

Providers might eventually be:

- email
- apple
- passkey
- Google

This allows several login methods to lead to one global account.

---

# 11. Shared accounts do not mean shared app permissions

A user being authenticated by New Life Media does not automatically make them a parent in Chore Tracker.

Authentication answers:

> Who is this person?

The app answers:

> What is this person allowed to do here?

For Chore Tracker:

```
user_id
    ↓
household_membership
    ↓
role = parent / child
```

Never store Chore Tracker's parent/child role as the user's global account role.

A user could be:

- a parent in Household A
- a child/member in another shared group
- a normal user in Vivero

Permissions belong to application resources.

---

# 12. Household onboarding

After shared account authentication, Chore Tracker should check:

```
Does this user have a household membership?
```

If no:

```
Welcome
   ↓
Create household
OR
Join household
```

Parent creation flow:

```
Create household
   ↓
Household name
   ↓
Parent becomes owner/admin
   ↓
Generate invitation
```

Child flow:

```
Join household
   ↓
Invite link/code
   ↓
Parent approves if required
   ↓
Child membership created
```

Do not ask someone to globally identify themselves as "Parent" or "Child" before they join a household.

That is a Chore Tracker membership property, not an identity property.

---

# 13. Invitations

Recommended invite format:

```
https://chore.newlifemedia.co/join/abc123
```

or an easy short code:

```
FAMILY-7K3Q
```

The invitation should point to:

- household
- intended membership type if needed
- expiration date
- usage limits

Do not embed private household information directly in the invitation token.

---

# 14. Cross-app sign-in experience

There are two levels of shared-account behavior.

## Level 1 — shared credentials

A user can enter the same email in every New Life Media app.

This is already valuable.

They receive an OTP when needed, and the central server recognizes the existing account.

## Level 2 — real SSO

Eventually, make:

```
auth.newlifemedia.co
```

an OAuth 2.0 / OpenID Connect identity provider.

Then an app can open:

```
Sign in with New Life Media
```

through `ASWebAuthenticationSession`.

If the user already has an auth session in Safari/system authentication, another app can sign in with very little friction.

This is the best long-term architecture.

Do not try to manually copy one app's Keychain token into every other app as the main SSO system.

---

# 15. iOS shared Keychain

Because New Life Media controls the apps, Apple Keychain Access Groups can technically share credentials between apps signed by the same developer team.

This can be useful for convenience.

However:

**do not make shared Keychain the source of truth for cross-app authentication.**

Reasons:

- Android/web cannot use it
- reinstall/device behavior becomes complicated
- it couples apps tightly together
- OAuth/OIDC is more standard and scalable

Use the central auth server as truth.

Shared Keychain can later be an optimization.

---

# 16. Swift package recommendation

Once the API stabilizes, move reusable iOS auth code into its own Swift package.

Suggested repository:

```
New-Life-Media/nlm-auth-ios
```

Package:

```
NLMAuth
```

The package should contain:

```
NLMAuth/
├── AuthClient.swift
├── AuthSession.swift
├── AuthUser.swift
├── KeychainStore.swift
├── EmailOTP.swift
├── TokenRefresh.swift
└── NLMAuthConfiguration.swift
```

Then each app adds the package and does something similar to:

```swift
let auth = NLMAuthClient(
    clientID: "chore-tracker-ios",
    baseURL: URL(string: "https://auth.newlifemedia.co")!
)
```

App code should not know anything about Resend.

It should only know:

```swift
try await auth.requestEmailCode(email)
let session = try await auth.verifyEmailCode(email, code: code)
```

---

# 17. Example reusable Swift API

Target API:

```swift
public protocol NLMAuthProviding {
    var currentUser: AuthUser? { get }

    func requestCode(email: String) async throws
    func verifyCode(email: String, code: String) async throws -> AuthSession
    func refreshSession() async throws
    func signOut() async throws
}
```

User:

```swift
public struct AuthUser: Codable, Identifiable {
    public let id: String
    public let email: String
    public let displayName: String?
}
```

Session:

```swift
public struct AuthSession: Codable {
    public let accessToken: String
    public let accessTokenExpiresAt: Date
}
```

Keep the refresh token internal to the package and Keychain.

An application should generally not need direct access to it.

---

# 18. Backend repository recommendation

Do not permanently keep the shared auth server inside the Chore Tracker repository.

The current backend is useful as a prototype.

Once another application uses it, extract it.

Recommended repo:

```
New-Life-Media/auth
```

Possible structure:

```
auth/
├── src/
│   ├── routes/
│   │   ├── email-code.ts
│   │   ├── verify-code.ts
│   │   ├── refresh.ts
│   │   ├── logout.ts
│   │   └── account.ts
│   ├── services/
│   │   ├── email.ts
│   │   ├── sessions.ts
│   │   └── tokens.ts
│   ├── db/
│   └── server.ts
├── migrations/
├── package.json
└── Dockerfile
```

---

# 19. VPS deployment

Recommended:

```
auth.newlifemedia.co
        ↓
Cloudflare
        ↓
Coolify
        ↓
NLM Auth container
        ↓
Postgres
        ↓
Resend
```

Environment variables:

```
DATABASE_URL=
RESEND_API_KEY=
RESEND_FROM=
ACCESS_TOKEN_PRIVATE_KEY=
ACCESS_TOKEN_PUBLIC_KEY=
OTP_HASH_SECRET=
APP_BASE_URL=https://auth.newlifemedia.co
```

Prefer asymmetric signing for the mature service, such as EdDSA/ES256/RS256, so app APIs can validate access tokens using a public key without possessing the private signing key.

---

# 20. Resend configuration

Use a dedicated sender such as:

```
accounts@newlifemedia.co
```

or:

```
login@newlifemedia.co
```

Example:

```
New Life Media <accounts@newlifemedia.co>
```

Subject:

```
Your New Life Media sign-in code
```

Do not brand the shared OTP email only as "Chore Tracker" once accounts are shared.

Instead include the requesting app inside the message:

```
Your New Life Media verification code is:

483921

Requested by: Chore Tracker
```

That reinforces that the identity belongs to New Life Media rather than one app.

---

# 21. OTP security rules

Minimum rules:

- cryptographically random six-digit OTP
- expire in about 10 minutes
- one-time use
- hash before storage
- limit attempts per code
- limit code sends per email
- limit sends per IP
- invalidate old code when a new code is generated
- never log the raw code in production
- generic responses where user enumeration is a concern

Consider CAPTCHA / abuse protection if automated traffic becomes a problem.

---

# 22. Session security

The server should support:

- rotating refresh tokens
- hashed refresh tokens in database
- per-device/session revocation
- short access-token expiration
- HTTPS only
- token audience checks
- token issuer checks
- client IDs
- rate limiting
- audit/security logs

For sensitive actions, require recent authentication.

Examples:

- change email
- delete global account
- export global account information
- revoke all sessions

---

# 23. Device tracking

Each session can optionally store:

```
device_name = "Aiden's iPhone"
platform = "iOS"
app = "Chore Tracker"
last_used_at
created_at
```

This makes it possible to build:

```
Account
└── Signed-in devices
    ├── iPhone — Chore Tracker
    ├── MacBook — Vivero
    └── iPad — Social
```

Users can revoke individual sessions.

---

# 24. Future passkeys

Email OTP is a good bootstrap method.

Long-term preferred flow:

```
First login:
Email OTP
   ↓
Account created
   ↓
Offer "Set up Face ID sign-in"
   ↓
Create passkey
```

Future logins:

```
Open app
   ↓
Face ID
   ↓
Signed in
```

Email remains available as recovery/bootstrap.

The central identity architecture allows passkeys to work across all products without redesigning each app.

---

# 25. Sign in with Apple

You can later attach Sign in with Apple to the same account.

Example:

```
Existing account:
aiden@example.com
        +
Apple identity
        ↓
same global user_id
```

Account linking must be handled carefully.

Do not automatically combine accounts merely because two providers claim similar profile information.

Require proof of control of the existing account before linking identities.

---

# 26. Account creation across apps

Suppose a person first joins Vivero.

Auth database:

```
usr_123
email = person@example.com
```

Later they install Chore Tracker.

They enter:

```
person@example.com
```

After verification, the auth system returns:

```
usr_123
```

Chore Tracker then checks its own database.

There may be no Chore Tracker record yet.

It creates only the app-specific profile/membership needed for that product.

It must not create another global user.

---

# 27. App API authentication

An app backend should trust the central identity service.

Example:

```
Chore Tracker iOS
      ↓
Authorization: Bearer token
      ↓
Chore Tracker API
      ↓
validate NLM Auth signature
      ↓
sub = usr_123
      ↓
load household memberships for usr_123
```

The Chore Tracker API should not independently ask Resend whether the user is authenticated.

It validates the signed access token.

---

# 28. Recommended service boundaries

A mature setup might be:

```
auth.newlifemedia.co
api.chore.newlifemedia.co
api.vivero.newlifemedia.co
api.social.newlifemedia.co
```

All APIs trust tokens issued by:

```
auth.newlifemedia.co
```

This lets services evolve independently.

---

# 29. Account profile UI

Every app can provide a shared Account page containing:

- name
- email
- authentication methods
- signed-in devices
- sign out
- security settings

App-specific settings remain elsewhere.

Example:

```
Profile

Aiden
aiden@example.com

ACCOUNT
Security
Signed-in devices
Sign out

CHORE TRACKER
Household
Notifications
Money settings
```

---

# 30. Reusable onboarding rule

Authentication and product onboarding should be separate.

### Authentication

```
Email
→ Verify
→ New Life Media account
```

### Chore Tracker onboarding

```
Create household
or
Join household
```

### Vivero onboarding

```
Choose wellness features
→ permissions
→ friends/groups
```

Do not force every application to reuse one giant onboarding flow.

Reuse identity only.

---

# 31. Naming recommendation

User-facing name:

**New Life Media Account**

Possible UI:

```
Continue with your New Life Media account
```

or simply:

```
Sign in
```

Avoid exposing backend/technical branding such as:

- Resend Account
- NLM JWT
- Auth Service

Resend is infrastructure, not the user's identity provider.

---

# 32. Migration plan from current Chore Tracker auth

## Phase 1 — current prototype

Current:

```
Chore Tracker iOS
      ↓
backend/
      ↓
Resend
```

Use this to validate email OTP.

## Phase 2 — extract shared auth

Create:

```
New-Life-Media/auth
```

Move OTP/session/account functionality there.

Deploy:

```
auth.newlifemedia.co
```

Update Chore Tracker to use that URL.

## Phase 3 — persistent database

Replace in-memory OTP storage.

Add Postgres tables:

- users
- identities
- sessions
- auth_clients
- email_codes

## Phase 4 — reusable iOS SDK

Create:

```
New-Life-Media/nlm-auth-ios
```

Move:

- EmailAuthService
- KeychainStore
- token refresh
- account model

into the Swift package.

## Phase 5 — use it in every app

Each app supplies only:

```
clientID
API URL
app-specific onboarding
```

## Phase 6 — SSO/passkeys

Add:

- OAuth/OIDC authorization flow
- passkeys
- Sign in with Apple
- system/browser SSO

---

# 33. What not to do

Avoid these designs:

### One auth database per app

This creates duplicate accounts and makes future SSO painful.

### Sharing the Resend API key with apps

Never ship server secrets in a mobile app.

### Email as the permanent user ID

Emails can change.

### One giant global user record containing all application data

This destroys service boundaries and privacy separation.

### 30-day bearer JWT with no revocation

Use short access tokens + refresh sessions.

### Letting each app invent its own token format

All New Life Media apps should trust the same central issuer.

### Treating "parent" or "child" as a global identity role

That role belongs to a household membership.

---

# 34. Practical v1 architecture

For your current scale, do not over-engineer it.

A strong first production version is:

```
Node/TypeScript auth API
Postgres
Resend
HTTPS
JWT access tokens
random refresh tokens
iOS Keychain
Coolify deployment
Cloudflare DNS/proxy
```

That is enough to support many apps and a meaningful number of users.

You do not need Kubernetes or a large microservice system.

---

# 35. Checklist for adding authentication to a new app

When making a new New Life Media app:

1. Register a new `client_id`.
2. Add the shared `NLMAuth` Swift package.
3. Configure:
   - `clientID`
   - auth server URL
4. Show shared sign-in UI.
5. Receive global `user_id`.
6. Create/load that application's profile for the user.
7. Use NLM access tokens when calling the app's API.
8. Store refresh credentials through the shared auth package.
9. Add sign-out/account settings.
10. Keep app permissions/data separate from authentication.

The new app should not need:

- another Resend account
- another OTP implementation
- another user/password database
- another session system

---

# 36. End-state architecture

```
                          ┌─────────────────────────┐
                          │ New Life Media Account  │
                          │ auth.newlifemedia.co    │
                          └────────────┬────────────┘
                                       │
                       ┌───────────────┼───────────────┐
                       │               │               │
                       ▼               ▼               ▼
                 Chore Tracker       Vivero        Social App
                       │               │               │
                       ▼               ▼               ▼
                 Chore API        Vivero API       Social API
                       │               │               │
                       └──── app-specific data only ───┘

Auth service:
- identity
- email verification
- sessions
- passkeys
- SSO

Apps:
- business logic
- permissions
- product data
```

---

# 37. Recommended next implementation work

Before another app consumes this auth system:

1. extract `backend/` into a dedicated auth repository
2. add Postgres
3. add persistent users
4. add refresh-token sessions
5. give Chore Tracker a registered client ID
6. move the Resend sender branding to New Life Media
7. deploy the service at `auth.newlifemedia.co`
8. add household onboarding after authentication
9. create the reusable Swift auth package
10. integrate the next app using that package

At that point, the shared account system becomes infrastructure you can reuse rather than code you keep copying.


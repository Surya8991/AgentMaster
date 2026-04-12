# Authentication Deep Dive - Top 20 Tools

## Auth Libraries (Self-hosted)

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **Auth.js (NextAuth)** | Auth Library | Free | Next.js OAuth, session management | authjs.dev |
| 2 | **Lucia** | Auth Library | Free | Lightweight session-based auth | lucia-auth.com |
| 3 | **Passport.js** | Auth Middleware | Free | Express.js, 500+ strategies | passportjs.org |
| 4 | **Arctic** | OAuth Library | Free | Minimal OAuth 2.0 client | arctic.js.org |

## Auth Services (Managed)

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 5 | **Clerk** | Auth Service | Free tier / Paid | Drop-in UI, user management | clerk.com |
| 6 | **Auth0** | Auth Platform | Free tier / Paid | Enterprise SSO, RBAC | auth0.com |
| 7 | **Supabase Auth** | BaaS Auth | Free tier / Paid | Postgres-backed auth, social login | supabase.com |
| 8 | **Firebase Auth** | BaaS Auth | Free tier / Paid | Google/social login, phone auth | firebase.google.com |
| 9 | **Kinde** | Auth Service | Free tier / Paid | Feature flags + auth combined | kinde.com |
| 10 | **WorkOS** | Enterprise Auth | Free tier / Paid | SSO, SCIM, enterprise-ready | workos.com |

## Self-hosted Auth Servers

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 11 | **Keycloak** | Auth Server | Free | Enterprise IAM, SSO, LDAP | keycloak.org |
| 12 | **Ory** | Auth Infrastructure | Free (OSS) / Paid | Identity, permissions, OAuth2 | ory.sh |
| 13 | **Logto** | Auth Platform | Free (self-host) / Paid | Modern CIAM, beautiful UI | logto.io |

## Token & Session

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 14 | **JWT (jsonwebtoken)** | Token Library | Free | Stateless auth tokens | github.com/auth0/node-jsonwebtoken |
| 15 | **jose** | JWT Library | Free | Edge-compatible JWT (no Node deps) | github.com/panva/jose |
| 16 | **iron-session** | Session Library | Free | Encrypted cookie sessions | github.com/vvo/iron-session |

## Passwordless & Passkeys

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 17 | **WebAuthn** | Standard | Free | Passkeys, biometric login | webauthn.io |
| 18 | **SimpleWebAuthn** | Library | Free | Easy passkey implementation | simplewebauthn.dev |

## MFA & Security

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 19 | **OTPAuth** | TOTP Library | Free | Generate/verify 2FA codes | github.com/nickelc/otpauth |
| 20 | **Twilio Verify** | SMS/Email OTP | Pay per use | Phone/email verification | twilio.com |

## When to Use What

| Project Type | Recommended Stack |
|-------------|-------------------|
| Next.js SaaS (quick) | Clerk or Auth.js + Prisma |
| Next.js SaaS (budget) | Supabase Auth or Lucia |
| Enterprise SSO | WorkOS or Auth0 or Keycloak |
| Mobile App | Firebase Auth or Supabase Auth |
| API-only Auth | JWT (jose) + iron-session |
| Passwordless/Passkeys | SimpleWebAuthn + Auth.js |
| Self-hosted | Keycloak or Logto |

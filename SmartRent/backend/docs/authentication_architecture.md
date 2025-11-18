## Authentication Architecture

### 1. Schema Alignment
- Add a 1:1 bridge between `public.profiles` and `auth.users` by declaring `profiles.id uuid primary key references auth.users (id) on delete cascade`.
- Treat `auth.users` as the source of truth for email, password hash, MFA configuration, and `profiles` as the domain layer for name, wallet, avatar, etc. Keep `profiles.email` only if you cache it; otherwise remove it and join to `auth.users`.
- Add helper columns in `profiles` as needed for product features (e.g. `last_login_at timestamptz`, `auth_provider text default 'email'`, `is_onboarded boolean default false`). They are optional but simplify backend logic.
- Create indexes for `profiles.wallet_address` and any other lookup keys that power auth/authorization decisions.
- Consider a lightweight audit table (`public.login_activity`) if you need login history that is independent of Supabase Auth logs.

### 2. Authentication Flows (Supabase Email/Password)
**Signup sequence**
1. Client submits `{ email, password, fullName }` to backend `POST /auth/signup`.
2. Backend validates password policy, then calls `supabase.auth.signUp({ email, password, options: { data: { full_name } } })`.
3. Supabase sends confirmation email; backend upserts `profiles` with `id = user.id`, `full_name`, optional `email`.
4. Backend responds with pending status and instructions to confirm email.

**Login sequence**
1. Client calls backend `POST /auth/login` with `{ email, password }`.
2. Backend calls `supabase.auth.signInWithPassword`.
3. On success, backend sets refresh token (HttpOnly cookie or secure storage token) and returns access token + profile payload.
4. Backend updates `profiles.last_login_at` asynchronously.

**Session refresh**
- Use `supabase.auth.exchangeCodeForSession` (mobile deep links) or REST `/token?grant_type=refresh_token` to rotate tokens. Backend ensures refresh token validity and updates storage atomically.

**Logout**
- Backend invalidates refresh token via `supabase.auth.signOut({ scope: 'global' })`, deletes session cookie/storage entry, and audits the event.

**Password reset**
1. Client hits `POST /auth/password/reset` with email.
2. Backend triggers `supabase.auth.resetPasswordForEmail(email, { redirectTo })`.
3. User follows link; client collects new password and calls backend `POST /auth/password/reset/confirm` which invokes `supabase.auth.updateUser({ password })`.

**Email verification guard**
- Backend middleware denies protected routes when `user.email_confirmed_at` is null. Frontend shows “verify email” banner until Supabase session includes confirmation timestamp.

**Optional magic link / OTP**
- Endpoint `POST /auth/magic-link` calls `supabase.auth.signInWithOtp({ email, options })`.
- Client handles either emailed one-time link or numeric OTP.
- On success, treat returned session exactly like password sign-in (tokens + profile sync). Useful for passwordless login or recovery scenarios.

### 3. Backend Integration
**REST contracts**
- `POST /auth/signup`
  - Request: `{ "email": "...", "password": "...", "full_name": "...", "referral_code": "..."? }`
  - Response: `{ "user_id": "uuid", "requires_email_verification": true }`
  - Side effects: Supabase sign-up, profile upsert, enqueue welcome/onboarding jobs.
- `POST /auth/login`
  - Request: `{ "email": "...", "password": "..." }`
  - Response: `{ "access_token": "...", "expires_in": 3600, "refresh_token": "...", "token_type": "bearer", "profile": { ... } }`
  - Sets refresh token cookie on web (`Set-Cookie: refresh_token=...; HttpOnly; Secure; SameSite=Lax`).
- `POST /auth/magic-link`
  - Request: `{ "email": "...", "redirect_to": "app://callback" }`
  - Response: `{ "status": "sent" }`
- `POST /auth/logout`
  - Requires valid session; revokes refresh token, clears cookie/secure storage.
- `POST /auth/password/reset` & `POST /auth/password/reset/confirm`
  - Wrap reset flows; confirm endpoint accepts `{ "token": "...", "new_password": "..." }`.

**Session middleware**
- Fetch GoTrue JWKS (`https://<project>.supabase.co/auth/v1/jwks`) and cache keys.
- Validate Supabase-issued JWTs on each request, extract `sub` (user id), `exp`, `email`, `role`.
- Hydrate request context with `user_id` and lazily load `profiles` row for downstream authorization.
- Enforce email verification and account status (e.g., `profiles.is_active`).

**Token storage guidance**
- Web: store access token in memory (e.g., React state) and refresh token in HttpOnly cookie.
- Mobile: keep refresh token in secure enclave/Keychain/Keystore, rotate tokens before expiry.
- Backend-to-backend service calls: use service role key in server environment, never ship to clients.

**Error handling**
- Normalize Supabase errors (e.g., invalid credentials, rate limits) into API error format.
- Instrument structured logs for auth events (success, failure, lockout) for observability.

### 4. Profile Sync & Hooks
- **Supabase trigger for mirror columns**
  ```sql
  create or replace function public.sync_profile_email()
  returns trigger as $$
  begin
    update public.profiles
      set email = new.email,
          updated_at = now()
    where id = new.id;
    return new;
  end;
  $$ language plpgsql security definer;

  create trigger on_auth_user_updated
    after update of email on auth.users
    for each row
    when (old.email is distinct from new.email)
    execute function public.sync_profile_email();
  ```
- **Signup webhook/edge function**
  - Configure Supabase Auth “Hook on User Created” to call an Edge Function (or backend endpoint) that upserts into `public.profiles` with the new `user.id`, storing `full_name`, `avatar_url`, and defaults for onboarding flags.
  - Edge function retries idempotently; use `insert ... on conflict (id) do update`.
- **Runtime profile sync**
  - Backend `PATCH /profiles/me` updates local profile fields only; never write directly to `auth.users` except for email/password changes routed via Supabase.
  - When wallet is linked, verify signature (`personal_sign` challenge) before persisting `wallet_address`; consider storing verification timestamp.
- **Last-login tracking**
  - After successful login/refresh, enqueue a background job to `update public.profiles set last_login_at = now() where id = :user_id`.
  - Optionally record event in `public.login_activity` with device metadata for security analytics.

### 5. Security & Testing
- **Password rules**: enforce minimum length 10, mix of character classes, deny known breached passwords (use HaveIBeenPwned API before calling Supabase). Enable Supabase Auth password strength validation for consistency.
- **Rate limiting**: apply IP and account-based limits (e.g., 10 login attempts/5 min) via FastAPI dependency backed by Redis. Block IP temporarily after repeated failures; surface generic error messages to avoid user enumeration.
- **Transport security**: require HTTPS across environments, set `Strict-Transport-Security`, `X-Content-Type-Options`, and `Content-Security-Policy` headers. Refresh token cookies must be `Secure`, `HttpOnly`, `SameSite=Lax`.
- **Account verification**: require confirmed email before unlocking asset management actions; leverage Supabase MFA once enabled. Provide admin tooling to force password reset or deactivate accounts by toggling `profiles.is_active`.
- **Auditing & monitoring**: push Supabase Auth logs to Logflare/Datadog, alert on anomalies (sudden spike in failures, logins from new geos). Store summarized events in `public.login_activity` if created.
- **Testing plan**
  - *Unit*: mock Supabase client to test validation and error translation in auth routes.
  - *Integration*: run Supabase local stack; exercise signup, email-confirmed login, refresh rotation, password reset, and magic link flows end-to-end.
  - *E2E*: use Playwright/Flutter integration tests to validate UI flows, cookie handling, and guarded route redirects.
  - *Security*: add regression tests for lockout logic, ensure tokens rejected after logout, and simulate replay attacks using expired tokens.


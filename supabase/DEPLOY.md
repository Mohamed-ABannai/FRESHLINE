# Supabase deployment (OTP email + reset codes)

Freshline sends verification/reset codes via Supabase **Edge Functions**:

- `send-auth-otp` (dispatches the 6-digit code)
- `verify-auth-otp` (verifies the 6-digit code)

If you see an in-app error like “Missing `send-auth-otp`”, the function is not deployed to your Supabase project.

## Prerequisites

- Install Supabase CLI
- Authenticate: `supabase login`

## Deploy (recommended)

From the repo root:

```powershell
.\tool\deploy_supabase_edge_functions.ps1
```

If auto-detection fails, pass the project ref:

```powershell
.\tool\deploy_supabase_edge_functions.ps1 -ProjectRef <your-project-ref>
```

## Configure email delivery (Resend)

Set these secrets (used by `send-auth-otp`):

- `RESEND_API_KEY`
- `AUTH_EMAIL_FROM` (e.g. `Freshline <no-reply@yourdomain.com>`)
- Optional: `AUTH_EMAIL_REPLY_TO`

Note: The Edge Functions use `SUPABASE_ANON_KEY` (auto-provided by Supabase) to call the OTP RPCs.

You can set them via the deploy script:

```powershell
.\tool\deploy_supabase_edge_functions.ps1 -ResendApiKey "..." -AuthEmailFrom "Freshline <no-reply@...>"
```

Or manually:

```powershell
supabase secrets set RESEND_API_KEY=... AUTH_EMAIL_FROM="Freshline <no-reply@...>"
```

## Database schema

Run `supabase/freshline_schema.sql` in the Supabase SQL editor (once per project).

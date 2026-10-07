const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const allowedPurposes = new Set([
  "email_verification",
  "two_factor_setup",
  "two_factor_sign_in",
  "password_reset",
]);

function jsonResponse(
  body: Record<string, unknown>,
  init: ResponseInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });
}

function otpCode(): string {
  const buffer = new Uint32Array(1);
  crypto.getRandomValues(buffer);
  return (buffer[0] % 1_000_000).toString().padStart(6, "0");
}

function emailCopy(purpose: string, name: string, code: string) {
  switch (purpose) {
    case "email_verification":
      return {
        subject: "FreshLine email verification code",
        heading: "Verify your email",
        body:
          `Hi ${name}, use this 6-digit code to verify the email on your FreshLine account.`,
        bodyAr:
          `مرحباً ${name}، استخدم هذا الرمز المكوّن من 6 أرقام للتحقق من البريد الإلكتروني في حساب فريش لاين الخاص بك.`,
      };
    case "two_factor_setup":
      return {
        subject: "FreshLine email 2FA code",
        heading: "Enable email two-factor authentication",
        body:
          `Hi ${name}, use this 6-digit code to enable email two-factor authentication on your FreshLine account.`,
        bodyAr:
          `مرحباً ${name}، استخدم هذا الرمز المكوّن من 6 أرقام لتفعيل التحقق بخطوتين عبر البريد الإلكتروني في حساب فريش لاين الخاص بك.`,
      };
    case "password_reset":
      return {
        subject: "FreshLine password reset code",
        heading: "Reset your password",
        body:
          `Hi ${name}, use this 6-digit code to reset your FreshLine password.`,
        bodyAr:
          `مرحباً ${name}، استخدم هذا الرمز المكوّن من 6 أرقام لإعادة تعيين كلمة مرور فريش لاين الخاصة بك.`,
      };
    case "two_factor_sign_in":
    default:
      return {
        subject: "FreshLine sign-in verification code",
        heading: "Verify your sign in",
        body:
          `Hi ${name}, use this 6-digit code to finish signing in to FreshLine.`,
        bodyAr:
          `مرحباً ${name}، استخدم هذا الرمز المكوّن من 6 أرقام لإكمال تسجيل الدخول إلى فريش لاين.`,
      };
  }
}

function smsCopy(purpose: string, name: string, code: string) {
  switch (purpose) {
    case "email_verification":
      return {
        body: `FreshLine: Hi ${name}, your verification code is ${code}. It expires in 10 minutes.`,
        bodyAr:
          `فريش لاين: مرحباً ${name}، رمز التحقق هو ${code}. تنتهي صلاحيته خلال 10 دقائق.`,
      };
    case "two_factor_setup":
      return {
        body:
          `FreshLine: Hi ${name}, your 2FA setup code is ${code}. It expires in 10 minutes.`,
        bodyAr:
          `فريش لاين: مرحباً ${name}، رمز إعداد التحقق بخطوتين هو ${code}. تنتهي صلاحيته خلال 10 دقائق.`,
      };
    case "password_reset":
      return {
        body:
          `FreshLine: Hi ${name}, your password reset code is ${code}. It expires in 10 minutes.`,
        bodyAr:
          `فريش لاين: مرحباً ${name}، رمز إعادة تعيين كلمة المرور هو ${code}. تنتهي صلاحيته خلال 10 دقائق.`,
      };
    case "two_factor_sign_in":
    default:
      return {
        body:
          `FreshLine: Hi ${name}, your sign-in code is ${code}. It expires in 10 minutes.`,
        bodyAr:
          `فريش لاين: مرحباً ${name}، رمز تسجيل الدخول هو ${code}. تنتهي صلاحيته خلال 10 دقائق.`,
      };
  }
}

function isMissingRpcFunctionError(
  rawError: string,
  functionName: string,
): boolean {
  const normalizedError = rawError.trim().toLowerCase();
  const normalizedFunctionName = functionName.trim().toLowerCase();
  if (!normalizedError || !normalizedFunctionName) {
    return false;
  }
  return normalizedError.includes(
    `could not find the function public.${normalizedFunctionName}`,
  ) ||
    (normalizedError.includes(normalizedFunctionName) &&
      normalizedError.includes("schema cache")) ||
    normalizedError.includes("no function matches the given name");
}

function normalizeRpcErrorText(rawErrorText: string): string {
  const raw = (rawErrorText ?? "").trim();
  if (!raw) return "";
  try {
    const decoded = JSON.parse(raw);
    if (decoded && typeof decoded === "object") {
      const message = String((decoded as { message?: unknown }).message ?? "")
        .trim();
      if (message) return message;
    }
  } catch (_) {
    // ignore and return raw below
  }
  return raw;
}

function isOtpRateLimitError(rawErrorText: string): boolean {
  const normalized = normalizeRpcErrorText(rawErrorText).trim().toLowerCase();
  if (!normalized) return false;
  return normalized.includes("too many otp requests") ||
    (normalized.includes("too many") && normalized.includes("otp"));
}

async function createAuthEmailOtpRecord({
  supabaseUrl,
  apiKey,
  email,
  purpose,
  code,
  profileId,
}: {
  supabaseUrl: string;
  apiKey: string;
  email: string;
  purpose: string;
  code: string;
  profileId: string;
}): Promise<{ ok: true } | { ok: false; errorText: string }> {
  const attempts: Array<Record<string, unknown>> = [
    {
      p_email: email,
      p_purpose: purpose,
      p_code: code,
      p_profile_id: profileId,
      p_expires_in_minutes: 10,
    },
    {
      p_email: email,
      p_purpose: purpose,
      p_code: code,
      p_expires_in_minutes: 10,
    },
    {
      p_email: email,
      p_purpose: purpose,
      p_code: code,
    },
  ];

  let lastErrorText = "";
  for (let index = 0; index < attempts.length; index += 1) {
    const createOtpResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/create_auth_email_otp`,
      {
        method: "POST",
        headers: {
          apikey: apiKey,
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(attempts[index]),
      },
    );

    if (createOtpResponse.ok) {
      return { ok: true };
    }

    lastErrorText = (await createOtpResponse.text()).trim();
    if (
      !isMissingRpcFunctionError(lastErrorText, "create_auth_email_otp") ||
      index == attempts.length - 1
    ) {
      return { ok: false, errorText: lastErrorText };
    }
  }

  return { ok: false, errorText: lastErrorText };
}

async function createAuthPhoneOtpRecord({
  supabaseUrl,
  apiKey,
  phone,
  purpose,
  code,
  profileId,
}: {
  supabaseUrl: string;
  apiKey: string;
  phone: string;
  purpose: string;
  code: string;
  profileId: string;
}): Promise<{ ok: true } | { ok: false; errorText: string }> {
  const attempts: Array<Record<string, unknown>> = [
    {
      p_phone: phone,
      p_purpose: purpose,
      p_code: code,
      p_profile_id: profileId,
      p_expires_in_minutes: 10,
    },
    {
      p_phone: phone,
      p_purpose: purpose,
      p_code: code,
      p_expires_in_minutes: 10,
    },
    {
      p_phone: phone,
      p_purpose: purpose,
      p_code: code,
    },
  ];

  let lastErrorText = "";
  for (let index = 0; index < attempts.length; index += 1) {
    const response = await fetch(
      `${supabaseUrl}/rest/v1/rpc/create_auth_phone_otp`,
      {
        method: "POST",
        headers: {
          apikey: apiKey,
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(attempts[index]),
      },
    );

    if (response.ok) {
      return { ok: true };
    }

    lastErrorText = (await response.text()).trim();
    if (
      !isMissingRpcFunctionError(lastErrorText, "create_auth_phone_otp") ||
      index === attempts.length - 1
    ) {
      return { ok: false, errorText: lastErrorText };
    }
  }

  return { ok: false, errorText: lastErrorText };
}

async function sendTwilioSms({
  accountSid,
  authToken,
  to,
  from,
  messagingServiceSid,
  body,
}: {
  accountSid: string;
  authToken: string;
  to: string;
  from?: string;
  messagingServiceSid?: string;
  body: string;
}): Promise<{ ok: true } | { ok: false; errorText: string }> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`;
  const params = new URLSearchParams();
  params.set("To", to);
  params.set("Body", body);

  const normalizedMessagingServiceSid = (messagingServiceSid ?? "").trim();
  const normalizedFrom = (from ?? "").trim();
  if (normalizedMessagingServiceSid) {
    params.set("MessagingServiceSid", normalizedMessagingServiceSid);
  } else if (normalizedFrom) {
    params.set("From", normalizedFrom);
  } else {
    return {
      ok: false,
      errorText: "Missing TWILIO_FROM_NUMBER or TWILIO_MESSAGING_SERVICE_SID.",
    };
  }

  const authHeader = `Basic ${btoa(`${accountSid}:${authToken}`)}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: authHeader,
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
    },
    body: params.toString(),
  });

  if (response.ok) {
    return { ok: true };
  }

  const errorText = (await response.text()).trim();
  return { ok: false, errorText: errorText || "Twilio SMS delivery failed." };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      { error: "Method not allowed." },
      { status: 405 },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const authEmailFrom = Deno.env.get("AUTH_EMAIL_FROM") ?? "";
  const authEmailReplyTo = Deno.env.get("AUTH_EMAIL_REPLY_TO") ?? "";
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID") ?? "";
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
  const twilioFromNumber = Deno.env.get("TWILIO_FROM_NUMBER") ?? "";
  const twilioMessagingServiceSid =
    Deno.env.get("TWILIO_MESSAGING_SERVICE_SID") ?? "";

  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(
      { error: "Supabase service configuration is missing." },
      { status: 500 },
    );
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse(
      { error: "Request body must be valid JSON." },
      { status: 400 },
    );
  }

  const email = String(payload.email ?? "").trim().toLowerCase();
  const phone = String(payload.phone ?? "").trim();
  const purpose = String(payload.purpose ?? "").trim().toLowerCase();
  const profileId = String(payload.profileId ?? "").trim();

  if ((!email && !phone) || !allowedPurposes.has(purpose)) {
    return jsonResponse(
      { error: "A valid email or phone and OTP purpose are required." },
      { status: 400 },
    );
  }

  if (!profileId) {
    return jsonResponse(
      { error: "A matching profile id is required for OTP delivery." },
      { status: 400 },
    );
  }

  const profileResponse = await fetch(
    `${supabaseUrl}/rest/v1/profiles?select=id,full_name,username,email,phone&id=eq.${encodeURIComponent(profileId)}&limit=1`,
    {
      headers: {
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
      },
    },
  );

  if (!profileResponse.ok) {
    return jsonResponse(
      { error: "FreshLine could not load the target profile for OTP delivery." },
      { status: 500 },
    );
  }

  const profiles = await profileResponse.json();
  const profile = Array.isArray(profiles) ? profiles[0] : null;
  const profileEmail = String(profile?.email ?? "").trim().toLowerCase();
  const profilePhone = String(profile?.phone ?? "").trim();

  const isEmailRequest = Boolean(email);
  const isPhoneRequest = !isEmailRequest && Boolean(phone);

  if (!profile) {
    return jsonResponse(
      { error: "FreshLine could not match the OTP request to the account." },
      { status: 400 },
    );
  }

  if (isEmailRequest && profileEmail !== email) {
    return jsonResponse(
      { error: "FreshLine could not match the OTP request to the account email." },
      { status: 400 },
    );
  }

  if (isPhoneRequest && profilePhone !== phone) {
    return jsonResponse(
      { error: "FreshLine could not match the OTP request to the account phone." },
      { status: 400 },
    );
  }

  const code = otpCode();
  const createOtpResult = isPhoneRequest
    ? await createAuthPhoneOtpRecord({
      supabaseUrl,
      apiKey: supabaseAnonKey,
      phone,
      purpose,
      code,
      profileId,
    })
    : await createAuthEmailOtpRecord({
      supabaseUrl,
      apiKey: supabaseAnonKey,
      email,
      purpose,
      code,
      profileId,
    });

  if (!createOtpResult.ok) {
    const normalizedErrorText = normalizeRpcErrorText(createOtpResult.errorText);
    if (isOtpRateLimitError(createOtpResult.errorText)) {
      return jsonResponse(
        {
          error:
            "OTP_RATE_LIMIT",
        },
        { status: 429 },
      );
    }
    if (
      isMissingRpcFunctionError(createOtpResult.errorText, "create_auth_email_otp") ||
      isMissingRpcFunctionError(createOtpResult.errorText, "create_auth_phone_otp")
    ) {
      return jsonResponse(
        {
          error: "OTP_BACKEND_NOT_SETUP",
          detail: normalizedErrorText || "Missing OTP SQL functions.",
        },
        { status: 503 },
      );
    }
    return jsonResponse(
      {
        error:
          normalizedErrorText ||
          "FreshLine could not create the verification code.",
      },
      { status: 500 },
    );
  }

  const name = String(
    profile.full_name ?? payload.fullName ?? profile.username ?? "FreshLine User",
  ).trim() || "FreshLine User";
  const copy = emailCopy(purpose, name, code);

  const text = [
    copy.heading,
    "",
    copy.body,
    "",
    `Code: ${code}`,
    "This code expires in 10 minutes.",
    "",
    copy.bodyAr,
    "",
    `الرمز: ${code}`,
    "تنتهي صلاحية هذا الرمز خلال 10 دقائق.",
  ].join("\n");

  const htmlTitle = purpose === "password_reset"
    ? "Reset Your Password - Freshline"
    : "Email Verification - Freshline";

  const htmlHeading = purpose === "password_reset"
    ? "Reset Your Password 🔐"
    : "Verify Your Email 🔐";

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${htmlTitle}</title>
</head>
<body style="margin:0; padding:0; font-family: Arial, sans-serif; background-color:#f4f6f8;">
  <table align="center" width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0;">
    <tr>
      <td align="center">
        <table width="500" cellpadding="0" cellspacing="0" style="background:#ffffff; border-radius:10px; padding:30px; box-shadow:0 4px 10px rgba(0,0,0,0.05);">
          <tr>
            <td align="center" style="padding-bottom:20px;">
              <img src="https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/LOGO-new%20one.png"
                   alt="Freshline Logo"
                   style="max-width:150px;">
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-bottom:10px;">
              <h2 style="margin:0; color:#2c3e50;">${htmlHeading}</h2>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-bottom:20px;">
              <p style="margin:0; color:#7f8c8d; font-size:14px;">
                ${copy.body}
              </p>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 0;">
              <div style="display:inline-block; background:#f1f3f5; border-radius:8px; padding:16px 28px; font-size:30px; font-weight:bold; letter-spacing:6px; color:#2c3e50;">
                ${code}
              </div>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-top:10px;">
              <p style="font-size:12px; color:#95a5a6;">
                This code expires in 10 minutes. Do not share it with anyone.
              </p>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-top:10px;">
              <p dir="rtl" style="font-size:12px; color:#95a5a6; text-align:right;">
                ${copy.bodyAr}
              </p>
              <p dir="rtl" style="font-size:12px; color:#95a5a6; text-align:right;">
                لا تشارك هذا الرمز مع أي شخص. تنتهي صلاحيته خلال 10 دقائق.
              </p>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-top:20px;">
              <p style="font-size:12px; color:#95a5a6;">
                If you didn’t request this, you can safely ignore this email.
              </p>
            </td>
          </tr>
        </table>
        <table width="500" cellpadding="0" cellspacing="0" style="padding-top:15px;">
          <tr>
            <td align="center" style="font-size:12px; color:#bdc3c7;">
              © 2026 Freshline. All rights reserved.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();

  if (isPhoneRequest) {
    const sms = smsCopy(purpose, name, code);
    if (!twilioAccountSid || !twilioAuthToken) {
      return jsonResponse(
        {
          previewCode: code,
          warning:
            "SMS delivery is not configured. Set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in Supabase Edge Function secrets.",
        },
        { status: 200 },
      );
    }

    if (!twilioFromNumber && !twilioMessagingServiceSid) {
      return jsonResponse(
        {
          previewCode: code,
          warning:
            "SMS delivery is not configured. Set TWILIO_FROM_NUMBER or TWILIO_MESSAGING_SERVICE_SID in Supabase Edge Function secrets.",
        },
        { status: 200 },
      );
    }

    const smsBody = `${sms.body}\n${sms.bodyAr}`;
    const smsResult = await sendTwilioSms({
      accountSid: twilioAccountSid,
      authToken: twilioAuthToken,
      to: phone,
      from: twilioFromNumber || undefined,
      messagingServiceSid: twilioMessagingServiceSid || undefined,
      body: smsBody,
    });

    if (!smsResult.ok) {
      return jsonResponse(
        { error: smsResult.errorText || "FreshLine could not deliver the OTP SMS." },
        { status: 500 },
      );
    }

    return jsonResponse({ success: true });
  }

  if (!resendApiKey || !authEmailFrom) {
    return jsonResponse(
      {
        previewCode: code,
        warning:
          "Auth email delivery is not configured. Set RESEND_API_KEY and AUTH_EMAIL_FROM in Supabase Edge Function secrets.",
      },
      { status: 200 },
    );
  }

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: authEmailFrom,
      to: [email],
      subject: copy.subject,
      html,
      text,
      ...(authEmailReplyTo ? { reply_to: authEmailReplyTo } : {}),
    }),
  });

  if (!resendResponse.ok) {
    const resendBody = await resendResponse.text();
    return jsonResponse(
      {
        error:
          resendBody.trim() || "FreshLine could not deliver the OTP email.",
      },
      { status: 500 },
    );
  }

  return jsonResponse({ success: true });
});

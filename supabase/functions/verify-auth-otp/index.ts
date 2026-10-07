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

async function verifyAuthEmailOtpRecord({
  supabaseUrl,
  serviceRoleKey,
  email,
  purpose,
  code,
  profileId,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  email: string;
  purpose: string;
  code: string;
  profileId?: string;
}): Promise<
  { ok: true; verified: boolean } | { ok: false; errorText: string }
> {
  const normalizedProfileId = (profileId ?? "").trim();

  const attempts: Array<Record<string, unknown>> = [
    {
      p_email: email,
      p_purpose: purpose,
      p_code: code,
      ...(normalizedProfileId ? { p_profile_id: normalizedProfileId } : {}),
    },
    {
      p_email: email,
      p_purpose: purpose,
      p_code: code,
    },
  ];

  let lastErrorText = "";
  for (let index = 0; index < attempts.length; index += 1) {
    const response = await fetch(
      `${supabaseUrl}/rest/v1/rpc/verify_auth_email_otp`,
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(attempts[index]),
      },
    );

    if (response.ok) {
      const raw = (await response.text()).trim();
      if (!raw) {
        return { ok: true, verified: false };
      }
      try {
        // PostgREST may return a bare boolean for RPC calls.
        const decoded = JSON.parse(raw);
        if (typeof decoded === "boolean") {
          return { ok: true, verified: decoded };
        }
        return { ok: true, verified: Boolean(decoded) };
      } catch (_) {
        // If we cannot parse, treat it as failure (safe default).
        return { ok: true, verified: false };
      }
    }

    lastErrorText = (await response.text()).trim();
    if (
      !isMissingRpcFunctionError(lastErrorText, "verify_auth_email_otp") ||
      index == attempts.length - 1
    ) {
      return { ok: false, errorText: lastErrorText };
    }
  }

  return { ok: false, errorText: lastErrorText };
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
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
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

  const email = String(payload.email ?? payload.p_email ?? "")
    .trim()
    .toLowerCase();
  const purpose = String(payload.purpose ?? payload.p_purpose ?? "")
    .trim()
    .toLowerCase();
  const code = String(payload.code ?? payload.p_code ?? "").trim();
  const profileId = String(payload.profileId ?? payload.p_profile_id ?? "")
    .trim();

  if (!email || !allowedPurposes.has(purpose) || !/^[0-9]{6}$/.test(code)) {
    return jsonResponse(
      { error: "A valid email, purpose, and 6-digit code are required." },
      { status: 400 },
    );
  }

  const verifyResult = await verifyAuthEmailOtpRecord({
    supabaseUrl,
    serviceRoleKey,
    email,
    purpose,
    code,
    profileId: profileId || undefined,
  });

  if (!verifyResult.ok) {
    if (
      isMissingRpcFunctionError(verifyResult.errorText, "verify_auth_email_otp")
    ) {
      return jsonResponse(
        {
          error: "OTP_BACKEND_NOT_SETUP",
          detail: verifyResult.errorText || "Missing OTP SQL functions.",
        },
        { status: 503 },
      );
    }
    return jsonResponse(
      {
        error:
          verifyResult.errorText ||
          "FreshLine could not verify the code.",
      },
      { status: 500 },
    );
  }

  return jsonResponse({
    verify_auth_email_otp: verifyResult.verified,
    verified: verifyResult.verified,
  });
});


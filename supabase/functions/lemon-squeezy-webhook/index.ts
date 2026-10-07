// supabase/functions/lemon-squeezy-webhook/index.ts
// Auto-upgrade: when a customer pays Lemon Squeezy, flip their tier in Supabase
// and send a receipt via Resend. Runs for EVERY payer, forever, no manual SQL.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LS_SECRET = Deno.env.get("LS_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = Deno.env.get("EMAIL_FROM_ADDRESS") ?? "Velora <onboarding@resend.dev>";
const APP_URL = Deno.env.get("APP_URL") ?? "https://velora-8c3e8.web.app";

// ★ Your real Lemon Squeezy Product IDs → plan they unlock ★
const PRODUCT_TO_TIER: Record<string, string> = {
  "1417986": "pro", // Velora Pro ($49/mo)
};

const ACTIVE = new Set(["active", "trialing", "past_due"]);
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type,x-signature",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};

async function verifySig(raw: string, sig: string): Promise<boolean> {
  if (!LS_SECRET || !sig) return false;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(LS_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, enc.encode(raw));
  const hex = Array.from(new Uint8Array(mac)).map(b => b.toString(16).padStart(2, "0")).join("");
  return hex === sig;
}

// Robust extraction: scan the whole payload for product_id / email wherever they live,
// so schema changes in Lemon Squeezy never silently break the upgrade.
function collectProductIds(node: unknown, out: Set<string>) {
  if (Array.isArray(node)) { for (const v of node) collectProductIds(v, out); return; }
  if (node && typeof node === "object") {
    for (const [k, v] of Object.entries(node as Record<string, unknown>)) {
      if ((k === "product_id") && (typeof v === "string" || typeof v === "number")) out.add(String(v));
      collectProductIds(v, out);
    }
  }
}
function findEmail(node: unknown): string | null {
  if (Array.isArray(node)) { for (const v of node) { const e = findEmail(v); if (e) return e; } return null; }
  if (node && typeof node === "object") {
    const o = node as Record<string, unknown>;
    for (const k of ["user_email", "email"]) {
      const v = o[k];
      if (typeof v === "string" && v.includes("@")) return v;
    }
    for (const v of Object.values(o)) { const e = findEmail(v); if (e) return e; }
  }
  return null;
}

async function sendReceipt(email: string, tier: string, amount: string) {
  if (!RESEND_API_KEY || !email) return;
  const label = tier === "pro_plus" ? "Pro Plus" : "Pro";
  const html = `<!DOCTYPE html><html><body style="margin:0;background:#F9FAFB;font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#1F2937;">
  <div style="max-width:600px;margin:0 auto;padding:24px 16px;">
    <div style="text-align:center;padding:24px 0;">
      <span style="display:inline-block;padding:10px 18px;background:linear-gradient(135deg,#8B5CF6,#EC4899);border-radius:12px;color:#fff;font-weight:700;font-size:20px;">✨ Velora</span>
    </div>
    <div style="background:#fff;border-radius:16px;padding:32px 28px;border:1px solid #E5E7EB;">
      <div style="text-align:center;margin-bottom:16px;">
        <span style="display:inline-block;width:64px;height:64px;background:linear-gradient(135deg,#10B981,#059669);border-radius:50%;line-height:64px;color:#fff;font-size:32px;">✓</span>
      </div>
      <h1 style="text-align:center;margin:0 0 8px;font-size:24px;color:#0F172A;">Payment received</h1>
      <p style="text-align:center;color:#6B7280;margin:0 0 24px;">Thank you for upgrading to Velora ${label}</p>
      <div style="background:#F9FAFB;border-radius:12px;padding:20px;margin-bottom:20px;">
        <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #E5E7EB;"><span style="color:#6B7280;">Plan</span><strong>${label}</strong></div>
        <div style="display:flex;justify-content:space-between;padding:8px 0;"><span style="color:#6B7280;">Amount</span><strong style="color:#8B5CF6;">${amount}</strong></div>
      </div>
      <p style="font-size:15px;line-height:1.6;">All ${label} features are now unlocked — full stockout reports, financial blueprint, quick wins, and strategic timelines.</p>
      <div style="text-align:center;margin:28px 0 8px;">
        <a href="${APP_URL}" style="display:inline-block;padding:14px 32px;background:#8B5CF6;color:#fff;text-decoration:none;border-radius:10px;font-weight:600;">Open your dashboard →</a>
      </div>
    </div>
    <p style="text-align:center;font-size:11px;color:#9CA3AF;margin-top:24px;">Sent by Velora · <a href="${APP_URL}" style="color:#9CA3AF;">Manage preferences</a></p>
  </div></body></html>`;
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to: [email], subject: `✅ Receipt — Velora ${label}`, html }),
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const raw = await req.text();
    const sig = req.headers.get("X-Signature") ?? "";
    if (!(await verifySig(raw, sig))) {
      console.warn("⚠️ Bad signature — rejected");
      return new Response("invalid signature", { status: 400, headers: CORS });
    }
    const event = JSON.parse(raw);
    const type: string = (event.meta?.event_name as string) ?? "";
    const status: string = (event.data?.attributes?.status as string) ?? "";
    const email = findEmail(event) ?? "";
    const ids = new Set<string>();
    collectProductIds(event, ids);

    let tier: string | null = null;
    let isUpgrade = false;

    if (/expired|cancelled|canceled|paused/i.test(type)) {
      tier = "free";
    } else if (/created|updated/i.test(type)) {
      if (ACTIVE.has(status)) {
        const mapped = [...ids].map(id => PRODUCT_TO_TIER[id]).find(Boolean);
        if (mapped) { tier = mapped; isUpgrade = true; }
      } else {
        tier = "free";
      }
    }

    console.log(`📨 event=${type} status=${status} email=${email} ids=[${[...ids].join(",")}] -> tier=${tier}`);

    if (tier && email) {
      const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      const { data: old } = await sb.from("users").select("tier").eq("email", email).maybeSingle();
      await sb.from("users").update({ tier }).eq("email", email);
      console.log(`✅ tier ${email}: ${old?.tier} -> ${tier}`);
      if (isUpgrade && old?.tier !== tier) {
        await sendReceipt(email, tier, tier === "pro_plus" ? "$99.00" : "$49.00");
      }
    }
    return new Response("ok", { headers: CORS });
  } catch (e) {
    console.error("❌ webhook error:", e);
    return new Response("handled", { status: 200, headers: CORS }); // never make LS retry-loop
  }
});
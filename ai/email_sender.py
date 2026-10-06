"""
Velora Email Service — powered by Resend.

Sends transactional + value-driven emails to Velora users.
Free tier on Resend: 3000 emails/month.

Setup:
    1. Get API key from https://resend.com/api-keys
    2. Add to .env: RESEND_API_KEY=re_xxxxx
    3. (Optional) Verify your domain in Resend and set:
       EMAIL_FROM_ADDRESS=hello@yourdomain.com
"""

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import List, Optional

from dotenv import load_dotenv

# ─────────────────────────────────────────────────────────────
# 🔧 ENV LOADING — searches multiple locations for .env
# ─────────────────────────────────────────────────────────────
ROOT_DIR = Path(__file__).resolve().parent.parent

# Try .env in multiple likely locations (project root, scrapers/, ai/)
_ENV_CANDIDATES = [
    ROOT_DIR / ".env",
    ROOT_DIR / "scrapers" / ".env",
    ROOT_DIR / "ai" / ".env",
]
_loaded_env: Optional[Path] = None
for _env in _ENV_CANDIDATES:
    if _env.exists():
        load_dotenv(_env)
        _loaded_env = _env
        break

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────
# 🎨 BRAND CONFIG — matches Velora's design language
# ─────────────────────────────────────────────────────────────
BRAND = {
    "name": "Velora",
    "tagline": "Strategic AI Advisor",
    "primary": "#8B5CF6",       # Purple
    "primary_dark": "#6D28D9",
    "accent": "#EC4899",        # Pink
    "dark": "#0F172A",
    "text": "#1F2937",
    "muted": "#6B7280",
    "light_bg": "#F9FAFB",
    "card_bg": "#FFFFFF",
    "border": "#E5E7EB",
    "success": "#10B981",
    "warning": "#F59E0B",
    "danger": "#EF4444",
    "url": os.getenv("APP_URL", "https://velora-8c3e8.web.app"),
}


# ─────────────────────────────────────────────────────────────
# 🔧 HTML SCAFFOLD — shared by every email
# ─────────────────────────────────────────────────────────────
def _wrap(body_html: str, preview: str = "") -> str:
    """Wraps email body in the standard Velora shell."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{BRAND['name']}</title>
</head>
<body style="margin:0;padding:0;background-color:{BRAND['light_bg']};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:{BRAND['text']};">
  <div style="max-width:600px;margin:0 auto;padding:24px 16px;">

    <!-- Header -->
    <div style="text-align:center;padding:24px 0;">
      <div style="display:inline-block;padding:10px 18px;background:linear-gradient(135deg,{BRAND['primary']},{BRAND['accent']});border-radius:12px;">
        <span style="color:#fff;font-weight:700;font-size:20px;letter-spacing:-0.5px;">✨ {BRAND['name']}</span>
      </div>
      <p style="color:{BRAND['muted']};font-size:13px;margin:10px 0 0;">{BRAND['tagline']}</p>
    </div>

    <!-- Body -->
    <div style="background:{BRAND['card_bg']};border-radius:16px;padding:32px 28px;box-shadow:0 1px 3px rgba(0,0,0,0.05);border:1px solid {BRAND['border']};">
      {body_html}
    </div>

    <!-- Footer -->
    <div style="text-align:center;padding:24px 16px 0;font-size:12px;color:{BRAND['muted']};">
      <p style="margin:0 0 8px;">
        Sent by <a href="{BRAND['url']}" style="color:{BRAND['primary']};text-decoration:none;">{BRAND['name']}</a>
      </p>
      <p style="margin:0 0 16px;">
        {preview}
      </p>
      <p style="margin:0;font-size:11px;color:#9CA3AF;">
        You're receiving this because you signed up for {BRAND['name']}.<br>
        <a href="{BRAND['url']}/settings" style="color:#9CA3AF;text-decoration:underline;">Manage preferences</a>
        &nbsp;•&nbsp;
        <a href="{BRAND['url']}/unsubscribe" style="color:#9CA3AF;text-decoration:underline;">Unsubscribe</a>
      </p>
    </div>

  </div>
</body>
</html>"""


def _cta(label: str, url: str) -> str:
    """Reusable call-to-action button."""
    return f"""
      <div style="text-align:center;margin:28px 0 8px;">
        <a href="{url}" style="display:inline-block;padding:14px 32px;background:{BRAND['primary']};color:#fff;text-decoration:none;border-radius:10px;font-weight:600;font-size:15px;">
          {label}
        </a>
      </div>"""


def _tier_badge(tier: str) -> str:
    """Small colored badge showing user tier."""
    tier = (tier or "free").lower()
    colors = {
        "pro": BRAND["primary"],
        "pro_plus": BRAND["accent"],
        "enterprise": BRAND["dark"],
    }
    color = colors.get(tier, BRAND["muted"])
    label = "Pro+" if tier == "pro_plus" else tier.capitalize()
    return f'<span style="display:inline-block;padding:2px 8px;background:{color};color:#fff;border-radius:6px;font-size:11px;font-weight:700;letter-spacing:0.5px;">{label}</span>'


# ─────────────────────────────────────────────────────────────
# 📬 EMAIL SERVICE
# ─────────────────────────────────────────────────────────────
class EmailService:
    """Central Resend wrapper for all Velora transactional emails."""

    def __init__(
        self,
        api_key: Optional[str] = None,
        from_address: Optional[str] = None,
    ):
        self.api_key = api_key or os.getenv("RESEND_API_KEY")
        self.from_address = from_address or os.getenv(
            "EMAIL_FROM_ADDRESS", "Velora <onboarding@resend.dev>"
        )

        if not self.api_key:
            logger.warning("⚠️  RESEND_API_KEY not set — emails will be skipped.")

    # ---------- internal ----------
    def _send(self, to: str, subject: str, html: str, preview: str = "") -> bool:
        if not self.api_key:
            logger.info(f"Email skipped (no API key): {subject} → {to}")
            return False
        try:
            import resend  # imported here so the module still works without the package
            resend.api_key = self.api_key
            payload = {
                "from": self.from_address,
                "to": to,
                "subject": subject,
                "html": html,
            }
            # Resend supports `preview` as a custom header for inbox preview text
            if preview:
                payload["headers"] = {"X-Entity-Ref-ID": preview}
            resend.Emails.send(payload)
            logger.info(f"✅ Email sent: {subject} → {to}")
            return True
        except Exception as e:
            logger.error(f"❌ Email failed: {subject} → {to}: {e}")
            return False

    # ---------- 1. Welcome ----------
    def send_welcome(self, email: str, name: str = "", tier: str = "free") -> bool:
        greeting = f"Hi {name}," if name else "Welcome aboard!"
        body = f"""
          <h1 style="margin:0 0 16px;color:{BRAND['dark']};font-size:26px;">{greeting} 👋</h1>
          <p style="font-size:15px;line-height:1.6;color:{BRAND['text']};">
            Your account is ready. You now have an AI advisor watching your competitors
            24/7 — so you never miss a pricing move or a stockout again.
          </p>

          <div style="margin:24px 0;padding:20px;background:{BRAND['light_bg']};border-radius:12px;border-left:4px solid {BRAND['primary']};">
            <p style="margin:0 0 8px;font-weight:700;color:{BRAND['dark']};">Your current plan: {_tier_badge(tier)}</p>
            <p style="margin:0;color:{BRAND['muted']};font-size:14px;">
              Add your first competitor in the dashboard to start receiving insights.
            </p>
          </div>

          {_cta("Open your dashboard →", BRAND['url'])}
        """
        html = _wrap(body, preview="Your AI advisor is ready.")
        return self._send(email, "Welcome to Velora 👋", html)

    # ---------- 2. Receipt (after Lemon Squeezy webhook) ----------
    def send_receipt(
        self,
        email: str,
        tier: str,
        amount: str,
        invoice_url: str = "",
    ) -> bool:
        body = f"""
          <div style="text-align:center;margin-bottom:20px;">
            <div style="display:inline-block;width:64px;height:64px;background:linear-gradient(135deg,{BRAND['success']},#059669);border-radius:50%;line-height:64px;">
              <span style="font-size:32px;">✓</span>
            </div>
          </div>

          <h1 style="text-align:center;margin:0 0 8px;color:{BRAND['dark']};font-size:24px;">Payment received</h1>
          <p style="text-align:center;color:{BRAND['muted']};margin:0 0 24px;">
            Thank you for upgrading to {tier.capitalize()}
          </p>

          <div style="background:{BRAND['light_bg']};border-radius:12px;padding:20px;margin-bottom:20px;">
            <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid {BRAND['border']};">
              <span style="color:{BRAND['muted']};">Plan</span>
              <strong>{_tier_badge(tier)}</strong>
            </div>
            <div style="display:flex;justify-content:space-between;padding:8px 0;">
              <span style="color:{BRAND['muted']};">Amount</span>
              <strong style="color:{BRAND['primary']};">{amount}</strong>
            </div>
          </div>

          <p style="color:{BRAND['text']};font-size:15px;line-height:1.6;">
            All Pro features are now unlocked in your dashboard — including stockout
            alerts, the financial blueprint, and the 7-day quick wins playbook.
          </p>

          {_cta("Start using Pro features →", BRAND['url'] + '/insights')}
          {f'<p style="text-align:center;"><a href="{invoice_url}" style="color:{BRAND["muted"]};font-size:13px;">View invoice</a></p>' if invoice_url else ""}
        """
        html = _wrap(body, preview=f"Your Velora {tier.capitalize()} receipt")
        return self._send(email, f"✅ Receipt — Velora {tier.capitalize()}", html)

    # ---------- 3. Stockout Alert (HIGH VALUE) ----------
    def send_stockout_alert(
        self,
        email: str,
        competitor_name: str,
        products: List[dict],
        tier: str = "free",
    ) -> bool:
        count = len(products)
        rows = ""
        for p in products[:5]:  # cap at 5 to keep email readable
            rows += f"""
              <tr>
                <td style="padding:10px 12px;border-bottom:1px solid {BRAND['border']};">{p.get('name','')}</td>
                <td style="padding:10px 12px;border-bottom:1px solid {BRAND['border']};text-align:right;">{p.get('price','')}</td>
              </tr>
            """
        is_free = tier.lower() == "free"
        upsell = (
            f'<p style="margin:16px 0 0;padding:14px;background:#FEF3C7;border-radius:8px;color:#92400E;font-size:13px;">'
            f'<strong>🔒 Pro users see {count} stockouts.</strong> You see the top 5. '
            f'<a href="{BRAND["url"]}/billing" style="color:#92400E;font-weight:700;">Upgrade →</a></p>'
            if is_free and count > 5
            else ""
        )

        body = f"""
          <div style="display:inline-block;padding:6px 12px;background:#FEE2E2;color:{BRAND['danger']};border-radius:20px;font-size:12px;font-weight:700;letter-spacing:0.5px;margin-bottom:16px;">
            🚨 STOCKOUT DETECTED
          </div>

          <h1 style="margin:0 0 8px;color:{BRAND['dark']};font-size:24px;">
            {competitor_name} ran out of stock
          </h1>
          <p style="color:{BRAND['muted']};margin:0 0 20px;font-size:15px;">
            <strong style="color:{BRAND['danger']};">{count} products</strong> are currently unavailable — a window to capture their customers.
          </p>

          <table style="width:100%;border-collapse:collapse;background:{BRAND['light_bg']};border-radius:8px;overflow:hidden;margin-bottom:8px;">
            <thead>
              <tr style="background:{BRAND['primary']};color:#fff;">
                <th style="padding:10px 12px;text-align:left;font-size:13px;">Product</th>
                <th style="padding:10px 12px;text-align:right;font-size:13px;">Last price</th>
              </tr>
            </thead>
            <tbody>{rows}</tbody>
          </table>

          {upsell}

          {_cta("See full analysis →", BRAND['url'] + '/insights')}
        """
        html = _wrap(body, preview=f"{count} products out of stock at {competitor_name}")
        return self._send(
            email,
            f"🚨 {competitor_name} ran out of {count} products",
            html,
        )

    # ---------- 4. Insights Digest (the one you had, improved) ----------
    def send_insights_digest(
        self,
        email: str,
        insights: List[dict],
        competitor_name: str,
        tier: str = "free",
    ) -> bool:
        if not insights:
            logger.info("No insights to send")
            return False

        severity_color = {
            "critical": BRAND["danger"],
            "high": BRAND["warning"],
            "medium": "#3B82F6",
            "low": BRAND["success"],
        }
        severity_emoji = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}

        cards = ""
        for ins in insights[:6]:  # cap at 6 for readability
            sev = ins.get("severity", "medium")
            color = severity_color.get(sev, BRAND["primary"])
            emoji = severity_emoji.get(sev, "🟡")
            rec = ins.get("ai_recommendation") or ""
            rec_block = (
                f'<p style="color:{BRAND["primary"]};font-weight:600;margin:10px 0 0;font-size:13px;">💡 {rec}</p>'
                if rec
                else ""
            )
            cards += f"""
              <div style="padding:16px;border-radius:10px;margin-bottom:12px;background:{BRAND['light_bg']};border-left:4px solid {color};">
                <h3 style="margin:0 0 6px;color:{BRAND['dark']};font-size:15px;">
                  {emoji} {ins.get('title','Update')}
                </h3>
                <p style="color:{BRAND['muted']};margin:0;font-size:14px;line-height:1.5;">
                  {ins.get('summary','')}
                </p>
                {rec_block}
              </div>
            """

        body = f"""
          <h1 style="margin:0 0 8px;color:{BRAND['dark']};font-size:24px;">
            {len(insights)} strategic moves from {competitor_name}
          </h1>
          <p style="color:{BRAND['muted']};margin:0 0 24px;font-size:15px;">
            Here are today's insights your AI advisor flagged.
          </p>
          {cards}
          {_cta("Open full dashboard →", BRAND['url'] + '/insights')}
        """
        html = _wrap(body, preview=f"{len(insights)} insights from {competitor_name}")
        return self._send(
            email,
            f"📊 {len(insights)} insights from {competitor_name}",
            html,
        )

    # ---------- 5. Weekly Summary ----------
    def send_weekly_summary(self, email: str, stats: dict, tier: str = "free") -> bool:
        stats = stats or {}
        body = f"""
          <h1 style="margin:0 0 8px;color:{BRAND['dark']};font-size:24px;">Your week in review 📈</h1>
          <p style="color:{BRAND['muted']};margin:0 0 24px;font-size:15px;">
            Here's what your AI advisor caught this week.
          </p>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:20px;">
            <div style="padding:16px;background:{BRAND['light_bg']};border-radius:10px;text-align:center;">
              <div style="font-size:28px;font-weight:700;color:{BRAND['primary']};">{stats.get('insights', 0)}</div>
              <div style="color:{BRAND['muted']};font-size:12px;text-transform:uppercase;letter-spacing:0.5px;">Insights</div>
            </div>
            <div style="padding:16px;background:{BRAND['light_bg']};border-radius:10px;text-align:center;">
              <div style="font-size:28px;font-weight:700;color:{BRAND['danger']};">{stats.get('stockouts', 0)}</div>
              <div style="color:{BRAND['muted']};font-size:12px;text-transform:uppercase;letter-spacing:0.5px;">Stockouts</div>
            </div>
            <div style="padding:16px;background:{BRAND['light_bg']};border-radius:10px;text-align:center;">
              <div style="font-size:28px;font-weight:700;color:{BRAND['warning']};">{stats.get('price_changes', 0)}</div>
              <div style="color:{BRAND['muted']};font-size:12px;text-transform:uppercase;letter-spacing:0.5px;">Price changes</div>
            </div>
            <div style="padding:16px;background:{BRAND['light_bg']};border-radius:10px;text-align:center;">
              <div style="font-size:28px;font-weight:700;color:{BRAND['success']};">{stats.get('competitors', 0)}</div>
              <div style="color:{BRAND['muted']};font-size:12px;text-transform:uppercase;letter-spacing:0.5px;">Competitors</div>
            </div>
          </div>

          <div style="padding:16px;background:linear-gradient(135deg,{BRAND['primary']},{BRAND['accent']});border-radius:12px;color:#fff;">
            <p style="margin:0;font-weight:600;">💎 Pro tip of the week</p>
            <p style="margin:8px 0 0;font-size:14px;opacity:0.95;">
              {stats.get('tip', 'Monitor competitor stockouts closely — they are your highest-conversion opportunities.')}
            </p>
          </div>

          {_cta("Open your dashboard →", BRAND['url'] + '/dashboard')}
        """
        html = _wrap(body, preview="Your weekly competitive intelligence")
        return self._send(email, "📈 Your week in review", html)

    # ---------- 6. Payment Failed ----------
    def send_payment_failed(self, email: str, tier: str = "pro") -> bool:
        body = f"""
          <div style="text-align:center;margin-bottom:20px;">
            <div style="display:inline-block;width:64px;height:64px;background:#FEE2E2;border-radius:50%;line-height:64px;">
              <span style="font-size:32px;">⚠️</span>
            </div>
          </div>
          <h1 style="text-align:center;margin:0 0 8px;color:{BRAND['dark']};font-size:24px;">Payment failed</h1>
          <p style="text-align:center;color:{BRAND['muted']};margin:0 0 24px;">
            We couldn't charge your card for Velora {tier.capitalize()}.
          </p>
          <p style="color:{BRAND['text']};font-size:15px;line-height:1.6;">
            To keep your Pro features active, please update your payment method in the
            next 3 days. Your insights and alerts will pause until then.
          </p>
          {_cta("Update payment →", BRAND['url'] + '/billing')}
        """
        html = _wrap(body, preview="Action needed — update your payment method")
        return self._send(email, "⚠️ Payment failed — action needed", html)


# ─────────────────────────────────────────────────────────────
# 🔄 BACKWARD-COMPATIBILITY WRAPPER (keeps your old calls working)
# ─────────────────────────────────────────────────────────────
def send_insight_email(user_email: str, insights: list, competitor_name: str) -> bool:
    """Legacy wrapper — delegates to EmailService.send_insights_digest."""
    return EmailService().send_insights_digest(user_email, insights, competitor_name)


# ─────────────────────────────────────────────────────────────
# 🧪 Quick smoke test (run: python ai/email_sender.py)
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    if _loaded_env:
        print(f"📂 Loaded .env from: {_loaded_env}")
    else:
        print("⚠️  No .env file found in any candidate location!")
    svc = EmailService()
    print("\n🧪 Sending test emails to your inbox...\n")
    test = os.getenv("TEST_EMAIL", "")
    if not test:
        print("⚠️  Set TEST_EMAIL in your .env file to run smoke tests.")
        print(f"   (Found .env at: {_loaded_env if _loaded_env else 'none'})")
    else:
        print(f"📧 Sending to: {test}\n")
        svc.send_welcome(test, name="Test User", tier="free")
        svc.send_stockout_alert(
            test,
            competitor_name="ExampleShop",
            products=[
                {"name": "Premium Shirt", "price": "$49"},
                {"name": "Basic Tee", "price": "$19"},
            ],
            tier="free",
        )
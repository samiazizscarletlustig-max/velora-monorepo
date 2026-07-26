import os
import logging
from pathlib import Path
from dotenv import load_dotenv

ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / '.env')

logger = logging.getLogger(__name__)

def send_insight_email(user_email: str, insights: list, competitor_name: str) -> bool:
    """
    Sends AI insights to user via Resend.
    Free tier: 3000 emails/month
    """
    api_key = os.getenv("RESEND_API_KEY")
    if not api_key:
        logger.warning("No RESEND_API_KEY found")
        return False

    if not insights:
        logger.info("No insights to send")
        return False

    try:
        import resend
        resend.api_key = api_key

        # بناء محتوى الإيميل
        insights_html = ""
        for ins in insights:
            severity_emoji = {
                "critical": "🔴",
                "high": "🟠",
                "medium": "🟡",
                "low": "🟢"
            }.get(ins.get("severity", "medium"), "🟡")

            insights_html += f"""
            <div style="background: #f8f9fa; padding: 16px; border-radius: 8px; margin-bottom: 12px; border-left: 4px solid #6366f1;">
                <h3 style="margin: 0 0 8px 0; color: #1f2937;">
                    {severity_emoji} {ins.get('title', 'تحديث جديد')}
                </h3>
                <p style="color: #4b5563; margin: 0 0 8px 0;">
                    {ins.get('summary', '')}
                </p>
                <p style="color: #6366f1; font-weight: bold; margin: 0;">
                    💡 {ins.get('ai_recommendation', '')}
                </p>
            </div>
            """

        html_content = f"""
        <!DOCTYPE html>
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 24px;">
                <h1 style="color: #6366f1; margin: 0;">🔮 Velora</h1>
                <p style="color: #6b7280;">Strategic AI Advisor</p>
            </div>

            <h2 style="color: #1f2937;">
                🚨 تحديثات جديدة من {competitor_name}
            </h2>
            <p style="color: #4b5563;">
                اكتشفنا <strong>{len(insights)} تغييرات استراتيجية</strong> اليوم!
            </p>

            {insights_html}

            <div style="text-align: center; margin-top: 24px; padding: 16px; background: #eef2ff; border-radius: 8px;">
                <p style="color: #4338ca; margin: 0;">
                    افتح <strong>Velora Dashboard</strong> لرؤية جميع التفاصيل والرسوم البيانية.
                </p>
            </div>

            <p style="color: #9ca3af; font-size: 12px; text-align: center; margin-top: 24px;">
                هذا الإيميل مرسل تلقائياً من نظام Velora AI.
            </p>
        </body>
        </html>
        """

        response = resend.Emails.send({
            "from": "Velora <onboarding@resend.dev>",
            "to": user_email,
            "subject": f"🚨 {len(insights)} تحديثات استراتيجية من {competitor_name}",
            "html": html_content
        })

        logger.info(f"✅ Email sent successfully to {user_email}!")
        return True

    except Exception as e:
        logger.error(f"Email error: {e}")
        return False
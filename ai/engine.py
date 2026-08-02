import os
import json
import logging
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai  # ✅ تم تصحيح الاستيراد ليتوافق مع requirements.txt
from typing import List, Literal

# قراءة .env من جذر المشروع (velora_monorepo)
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / '.env')

logger = logging.getLogger(__name__)

def generate_strategic_insights(competitor_name: str, delta_products: list) -> list:
    """
    Generates strategic insights using Gemini via the stable google-generativeai library.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        logger.warning("⚠️ No GEMINI_API_KEY found in root .env")
        return []

    try:
        # تهيئة المكتبة بالمفتاح
        genai.configure(api_key=api_key)
        
        # اختيار النموذج (gemini-1.5-flash أكثر استقراراً ومجانياً حالياً)
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        sample_titles = [p.get('title', 'Unknown Product') for p in delta_products[:10]]
        
        prompt = f"""
        You are Velora's Strategic AI Advisor for e-commerce businesses.
        
        Competitor "{competitor_name}" made {len(delta_products)} changes today.
        Sample of changed products: {sample_titles}

        Generate exactly 3 high-impact, actionable strategic insights for a rival store owner.
        Be specific, data-driven, and practical. Avoid generic advice.
        
        IMPORTANT: Return ONLY a valid JSON array of objects. Do not include markdown formatting or explanations.
        Each object must have: type, title, summary, ai_recommendation, severity.
        """

        logger.info("🧠 Generating insights with Gemini...")
        
        response = model.generate_content(prompt)
        
        # تنظيف الرد لاستخراج JSON فقط
        text = response.text
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()

        insights = json.loads(text)
        
        # التأكد من أن النتيجة قائمة
        if isinstance(insights, dict) and "insights" in insights:
            insights = insights["insights"]
            
        logger.info(f"✅ Generated {len(insights)} strategic insights!")
        return insights
        
    except json.JSONDecodeError as e:
        logger.error(f"❌ Failed to parse AI response as JSON: {e}")
        logger.error(f"Raw response: {response.text if 'response' in locals() else 'N/A'}")
        return []
    except Exception as e:
        logger.error(f"AI Engine Error: {e}")
        return []
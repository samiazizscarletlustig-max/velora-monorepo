import os
import json
import logging
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai  # ✅ تم التصحيح ليتوافق مع requirements.txt
from typing import List, Literal

# إعداد نظام التسجيل
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# تحديد جذر المشروع لتحميل .env بشكل صحيح
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / '.env')

def generate_strategic_insights(competitor_name: str, delta_products: list) -> list:
    """
    Generates strategic insights using Gemini via the stable google-generativeai library.
    Compatible with GitHub Actions environment.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        logger.warning("️ No GEMINI_API_KEY found in environment variables.")
        return []

    try:
        # تهيئة المكتبة بالمفتاح
        genai.configure(api_key=api_key)
        
        # استخدام نموذج مستقر ومجاني (gemini-1.5-flash)
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        # أخذ عينة من المنتجات للتحليل (أول 10 منتجات فقط لتوفير التوكنات)
        sample_titles = [p.get('title', 'Unknown Product') for p in delta_products[:10]]
        
        prompt = f"""
        You are Velora's Strategic AI Advisor for e-commerce businesses.
        
        Competitor "{competitor_name}" made {len(delta_products)} changes today.
        Sample of changed products: {sample_titles}

        Generate exactly 3 high-impact, actionable strategic insights for a rival store owner.
        Be specific, data-driven, and practical. Avoid generic advice.
        
        IMPORTANT: Return ONLY a valid JSON array of objects. Do not include markdown formatting like ```json or explanations.
        Each object must have these exact keys: type, title, summary, ai_recommendation, severity.
        Valid types: "price_drop", "new_collection", "stock_clearance", "marketing_shift".
        Valid severities: "low", "medium", "high", "critical".
        """

        logger.info(" Generating insights with Gemini...")
        
        response = model.generate_content(prompt)
        
        # تنظيف الرد لاستخراج JSON الصافي (GitHub Actions sometimes adds extra chars)
        text = response.text.strip()
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()

        # تحويل النص إلى كائن بايثون
        insights = json.loads(text)
        
        # التأكد من أن النتيجة قائمة (أحياناً يرد Gemini بكائن يحتوي على مفتاح insights)
        if isinstance(insights, dict) and "insights" in insights:
            insights = insights["insights"]
            
        logger.info(f"✅ Successfully generated {len(insights)} strategic insights!")
        return insights
        
    except json.JSONDecodeError as e:
        logger.error(f"❌ Failed to parse AI response as JSON: {e}")
        # طباعة الرد الخام للمساعدة في التشخيص إذا فشل التحليل
        raw_text = response.text if 'response' in locals() else "No response received"
        logger.error(f"Raw AI Response: {raw_text[:500]}...") 
        return []
    except Exception as e:
        logger.error(f"AI Engine Critical Error: {e}")
        return []
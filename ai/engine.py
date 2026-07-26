import os
import json
import logging
from pathlib import Path
from dotenv import load_dotenv
from google import genai
from google.genai import types
from pydantic import BaseModel
from typing import List, Literal

# قراءة .env من جذر المشروع (velora_monorepo)
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / '.env')

logger = logging.getLogger(__name__)

# 🔧 Pydantic Schema لضمان JSON صحيح 100%
class Insight(BaseModel):
    type: Literal["price_drop", "new_collection", "stock_clearance", "marketing_shift"]
    title: str
    summary: str
    ai_recommendation: str
    severity: Literal["low", "medium", "high", "critical"]

class InsightsResponse(BaseModel):
    insights: List[Insight]

def generate_strategic_insights(competitor_name: str, delta_products: list) -> list:
    """
    Generates strategic insights using Gemini 2.5 Flash (Free Tier).
    Uses the new official google-genai library.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        logger.warning("⚠️ No GEMINI_API_KEY found in root .env")
        return []

    # 🎯 استخدام المكتبة الجديدة الرسمية
    client = genai.Client(api_key=api_key)

    sample_titles = [p['title'] for p in delta_products[:15]]
    
    prompt = f"""
    You are Velora's Strategic AI Advisor for e-commerce businesses.
    
    Competitor "{competitor_name}" made {len(delta_products)} changes today.
    Sample of changed products: {sample_titles}

    Generate exactly 3 high-impact, actionable strategic insights for a rival store owner.
    Be specific, data-driven, and practical. Avoid generic advice.
    """

    try:
        logger.info("🧠 Generating insights with Gemini 2.5 Flash (Free)...")
        
        # 🎯 Structured Output مع المكتبة الجديدة
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=InsightsResponse
            )
        )
        
        parsed = json.loads(response.text)
        insights = parsed.get("insights", parsed) if isinstance(parsed, dict) else parsed
        
        logger.info(f"✅ Generated {len(insights)} strategic insights!")
        return insights
        
    except Exception as e:
        logger.error(f"AI Engine Error: {e}")
        return []
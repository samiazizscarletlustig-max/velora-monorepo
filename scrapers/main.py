import os
import sys
import logging
from pathlib import Path
from datetime import datetime, timezone

# 🔧 CTO FIX: تحديد جذر المشروع (velora_monorepo) تلقائياً
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))  # إضافة الجذر لـ sys.path لاستيراد ai.engine

from dotenv import load_dotenv
from supabase import create_client, Client

# 🔧 CTO FIX: تحميل .env من جذر المشروع وليس من مجلد scrapers
load_dotenv(ROOT_DIR / '.env')

# استيراد الدوال من الملفات الأخرى في المجلدات الفرعية
from platforms.shopify_scraper import scrape_shopify
from core.delta_analyzer import DeltaAnalyzer
from ai.engine import generate_strategic_insights  # 🔧 استيراد محرك الذكاء الاصطناعي

# إعداد نظام الـ Logging لمتابعة ما يحدث في الـ Terminal
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    # 1. تحميل متغيرات البيئة (تم تحميلها مسبقاً من الجذر)
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    test_competitor_url = os.getenv("COMPETITOR_URL", "https://www.gymshark.com")

    # 🔧 تشخيص: للتأكد من أن البرنامج يقرأ ملف .env بنجاح
    print(f"🔍 DEBUG - SUPABASE_URL: {supabase_url}")
    print(f"🔍 DEBUG - SUPABASE_KEY: {supabase_key[:15]}..." if supabase_key else "🔍 DEBUG - SUPABASE_KEY: None (الملف غير مقروء!)")

    if not supabase_url or not supabase_key:
        logger.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment variables.")
        logger.error(f"تأكد من وجود ملف .env في: {ROOT_DIR / '.env'}")
        sys.exit(1)

    # السماح بتمرير الرابط كـ Argument أو استخدام المتغير من .env
    target_url = sys.argv[1] if len(sys.argv) > 1 else test_competitor_url

    logger.info(f"🚀 Starting Scraper Engine for: {target_url}")

    # 2. تهيئة عميل Supabase
    try:
        supabase: Client = create_client(supabase_url, supabase_key)
    except Exception as e:
        logger.error(f"❌ فشل الاتصال بـ Supabase: {e}")
        sys.exit(1)

    # 3. جلب بيانات المنافس من قاعدة البيانات
    try:
        comp_res = supabase.table("competitors").select("id, name").eq("website_url", target_url).execute()
        if comp_res.data:
            competitor_id = comp_res.data[0]["id"]
            competitor_name = comp_res.data[0]['name']
            logger.info(f"✅ Found existing competitor: {competitor_name} ({competitor_id})")
        else:
            logger.error(f"❌ Competitor with website_url '{target_url}' not found in DB. Please ensure it is added first.")
            sys.exit(1)
    except Exception as e:
        logger.error(f"Error querying competitors: {e}")
        sys.exit(1)

    # 4. بدء عملية الـ Scraping
    logger.info("🕷️ Initiating Shopify Scraper...")
    scraped_data = scrape_shopify(target_url)
    
    if not scraped_data:
        logger.warning("No data scraped. Exiting.")
        sys.exit(0)

    # 5. تحليل الفروقات (Delta Analysis)
    analyzer = DeltaAnalyzer(supabase)
    delta_products = analyzer.get_delta(competitor_id, scraped_data)

    if not delta_products:
        logger.info("✅ Scrape complete. No new updates or price changes detected. Zero delta.")
        sys.exit(0)

    # 6. إدراج البيانات الجديدة/المحدثة في Supabase
    logger.info(f"📦 Pushing {len(delta_products)} delta updates to Supabase...")
    
    # استخدام التوقيت الحالي كـ timestamp للتحديث
    current_time = datetime.now(timezone.utc).isoformat()
    for p in delta_products:
        p["last_updated_at"] = current_time

    try:
        # استخدام Upsert لمنع التكرار بناءً على competitor_id و product_url
        upsert_res = supabase.table("products").upsert(
            delta_products, 
            on_conflict="competitor_id,product_url"
        ).execute()
        
        upserted_count = len(upsert_res.data) if upsert_res.data else len(delta_products)
        logger.info(f"✅ Successfully upserted {upserted_count} products.")
        
        updated_records = upsert_res.data if upsert_res.data else delta_products
        
        # إدراج سجلات الأسعار في جدول price_history
        if updated_records:
            price_history_records = []
            for record in updated_records:
                if "id" in record:
                    price_history_records.append({
                        "product_id": record["id"],
                        "price": record["current_price"]
                    })
            
            if price_history_records:
                supabase.table("price_history").insert(price_history_records).execute()
                logger.info(f"📈 Inserted price history for {len(price_history_records)} records.")
            else:
                logger.warning("No 'id' returned for upserted products. Skipping price history insertion.")

    except Exception as e:
        logger.error(f"Error upserting delta products to Supabase: {e}")
        sys.exit(1)

    # 🧠 7. لحظة السحر: توليد AI Insights
    logger.info("🧠 Generating strategic insights with Gemini...")
    insights = generate_strategic_insights(competitor_name, delta_products)
    
    if insights:
        logger.info(f"💾 Saving {len(insights)} AI Insights to Supabase...")
        db_insights = []
        for ins in insights:
            db_insights.append({
                "workspace_id": "00000000-0000-0000-0000-000000000001",
                "competitor_id": competitor_id,
                "type": ins.get("type", "general"),
                "title": ins.get("title", ""),
                "summary": ins.get("summary", ""),
                "ai_recommendation": ins.get("ai_recommendation", ""),
                "severity": ins.get("severity", "medium")
            })
        
        try:
            supabase.table("ai_insights").insert(db_insights).execute()
            logger.info("✅ Magic Loop Closed! AI Insights saved successfully!")
        except Exception as e:
            logger.error(f"Error saving AI insights: {e}")

    logger.info("🎉 Scraping, Delta Sync, and AI Analysis completed successfully!")

if __name__ == "__main__":
    main()
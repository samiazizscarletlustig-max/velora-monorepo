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
from ai.engine import generate_strategic_insights
from ai.email_sender import send_insight_email

# إعداد نظام الـ Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    # 1. تحميل متغيرات البيئة
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    
    # استخدام رابط افتراضي للاختبار إذا لم يوجد متغير بيئة
    test_competitor_url = os.getenv("COMPETITOR_URL", "https://www.gymshark.com")

    print(f"🔍 DEBUG - SUPABASE_URL: {supabase_url}")
    if not supabase_key:
        logger.error("❌ SUPABASE_SERVICE_ROLE_KEY is missing!")
        sys.exit(1)
    else:
        print(f"🔍 DEBUG - SUPABASE_KEY: {supabase_key[:15]}...")

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
        # ✅ تم تصحيح اسم العمود من website_url إلى website
        comp_res = supabase.table("competitors").select("id, name").eq("website", target_url).execute()
        
        if comp_res.data:
            competitor_id = comp_res.data[0]["id"]
            competitor_name = comp_res.data[0]['name']
            logger.info(f"✅ Found existing competitor: {competitor_name} ({competitor_id})")
        else:
            logger.warning(f"⚠️ Competitor with website '{target_url}' not found in DB.")
            logger.info("💡 Tip: Add the competitor via the app first, then run the scraper.")
            sys.exit(0) # خروج آمن بدلاً من خطأ فادح
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
    
    current_time = datetime.now(timezone.utc).isoformat()
    for p in delta_products:
        p["last_updated_at"] = current_time

    try:
        upsert_res = supabase.table("products").upsert(
            delta_products, 
            on_conflict="competitor_id,product_url"
        ).execute()
        
        upserted_count = len(upsert_res.data) if upsert_res.data else len(delta_products)
        logger.info(f"✅ Successfully upserted {upserted_count} products.")
        
        updated_records = upsert_res.data if upsert_res.data else delta_products
        
        # محاولة إدراج سجلات الأسعار (مع حماية ضد عدم وجود الجدول)
        if updated_records:
            price_history_records = []
            for record in updated_records:
                if "id" in record:
                    price_history_records.append({
                        "product_id": record["id"],
                        "price": record.get("current_price", 0)
                    })
            
            if price_history_records:
                try:
                    supabase.table("price_history").insert(price_history_records).execute()
                    logger.info(f"📈 Inserted price history for {len(price_history_records)} records.")
                except Exception as pe:
                    logger.warning(f"⚠️ Could not insert price_history (table might not exist): {pe}")

    except Exception as e:
        logger.error(f"Error upserting delta products to Supabase: {e}")
        sys.exit(1)

    # 🧠 7. توليد AI Insights
    logger.info("🧠 Generating strategic insights with Gemini...")
    insights = generate_strategic_insights(competitor_name, delta_products)
    
    if insights:
        logger.info(f"💾 Saving {len(insights)} AI Insights to Supabase...")
        db_insights = []
        critical_insights = []
        
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
            
            if ins.get("severity") in ["critical", "high"]:
                critical_insights.append(ins)
        
        try:
            supabase.table("ai_insights").insert(db_insights).execute()
            logger.info("✅ Magic Loop Closed! AI Insights saved successfully!")
        except Exception as e:
            logger.error(f"Error saving AI insights: {e}")
        
        #  إرسال الإيميل عند وجود تحديثات مهمة
        if critical_insights:
            user_email = "samiazizscarletlustig@gmail.com"
            logger.info(f"📧 Sending email alert for {len(critical_insights)} critical/high insights...")
            try:
                send_insight_email(user_email, critical_insights, competitor_name)
            except Exception as e:
                logger.error(f"Error sending email: {e}")
        else:
            logger.info("ℹ️ No critical/high severity insights. Skipping email notification.")

    logger.info("🎉 Scraping, Delta Sync, and AI Analysis completed successfully!")

if __name__ == "__main__":
    main()
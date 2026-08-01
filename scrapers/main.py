import os
import sys
import logging
from pathlib import Path
from datetime import datetime, timezone

# 🔧 CTO FIX: تحديد جذر المشروع تلقائياً لضمان عمل الاستيرادات
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))

from dotenv import load_dotenv
from supabase import create_client, Client

# تحميل متغيرات البيئة من الجذر
load_dotenv(ROOT_DIR / '.env')

# استيراد الوحدات الفرعية
from platforms.shopify_scraper import scrape_shopify
from core.delta_analyzer import DeltaAnalyzer
from ai.engine import generate_strategic_insights
from ai.email_sender import send_insight_email

# إعداد نظام التسجيل
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    # 1. التحقق من متغيرات البيئة
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    test_competitor_url = os.getenv("COMPETITOR_URL", "https://www.gymshark.com")

    print(f"🔍 DEBUG - SUPABASE_URL: {supabase_url}")
    if not supabase_key:
        logger.error("❌ SUPABASE_SERVICE_ROLE_KEY is missing!")
        sys.exit(1)
    
    if not supabase_url or not supabase_key:
        logger.error("Missing credentials. Check .env file.")
        sys.exit(1)

    # السماح بتمرير الرابط كـ Argument أو استخدام الافتراضي
    target_url = sys.argv[1] if len(sys.argv) > 1 else test_competitor_url
    logger.info(f"🚀 Starting Scraper Engine for: {target_url}")

    # 2. الاتصال بـ Supabase
    try:
        supabase: Client = create_client(supabase_url, supabase_key)
    except Exception as e:
        logger.error(f"❌ Failed to connect to Supabase: {e}")
        sys.exit(1)

    # 3. جلب بيانات المنافس (✅ تم تصحيح اسم العمود إلى website_url)
    try:
        comp_res = supabase.table("competitors").select("id, name").eq("website_url", target_url).execute()
        
        if comp_res.data:
            competitor_id = comp_res.data[0]["id"]
            competitor_name = comp_res.data[0]['name']
            logger.info(f"✅ Found competitor: {competitor_name} ({competitor_id})")
        else:
            logger.warning(f"⚠️ Competitor with URL '{target_url}' not found in DB.")
            logger.info("💡 Tip: Add the competitor via the app first.")
            sys.exit(0)
    except Exception as e:
        logger.error(f"Error querying competitors: {e}")
        sys.exit(1)

    # 4. بدء عملية السحب
    logger.info("🕷️ Initiating Shopify Scraper...")
    scraped_data = scrape_shopify(target_url)
    
    if not scraped_data:
        logger.warning("No data scraped. Exiting.")
        sys.exit(0)

    # 5. تحليل الفروقات
    analyzer = DeltaAnalyzer(supabase)
    delta_products = analyzer.get_delta(competitor_id, scraped_data)

    if not delta_products:
        logger.info("✅ Scrape complete. No new updates detected.")
        sys.exit(0)

    # 6. حفظ البيانات في Supabase
    logger.info(f" Pushing {len(delta_products)} updates to Supabase...")
    current_time = datetime.now(timezone.utc).isoformat()
    for p in delta_products:
        p["last_updated_at"] = current_time

    try:
        upsert_res = supabase.table("products").upsert(
            delta_products, 
            on_conflict="competitor_id,product_url"
        ).execute()
        
        upserted_count = len(upsert_res.data) if upsert_res.data else len(delta_products)
        logger.info(f"✅ Upserted {upserted_count} products.")
        
        updated_records = upsert_res.data if upsert_res.data else delta_products
        
        # محاولة حفظ سجل الأسعار (مع حماية ضد عدم وجود الجدول)
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
                    logger.info(f" Inserted price history for {len(price_history_records)} records.")
                except Exception as pe:
                    logger.warning(f"⚠️ Could not insert price_history: {pe}")

    except Exception as e:
        logger.error(f"Error upserting products: {e}")
        sys.exit(1)

    # 🧠 7. توليد رؤى الذكاء الاصطناعي
    logger.info("🧠 Generating strategic insights...")
    insights = generate_strategic_insights(competitor_name, delta_products)
    
    if insights:
        logger.info(f"💾 Saving {len(insights)} AI Insights...")
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
            logger.info("✅ Magic Loop Closed! Insights saved.")
        except Exception as e:
            logger.error(f"Error saving insights: {e}")
        
        # إرسال إيميل للتنبيهات المهمة
        if critical_insights:
            user_email = "samiazizscarletlustig@gmail.com"
            logger.info(f"📧 Sending alert for {len(critical_insights)} critical insights...")
            try:
                send_insight_email(user_email, critical_insights, competitor_name)
            except Exception as e:
                logger.error(f"Error sending email: {e}")

    logger.info("🎉 Scraping and Analysis completed successfully!")

if __name__ == "__main__":
    main()
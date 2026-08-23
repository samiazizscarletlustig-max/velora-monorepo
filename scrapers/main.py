"""
🚀 Scan Single Competitor
للاختبار السريع: python main.py https://anystore.com
"""
import os
import sys
import logging
from pathlib import Path
from datetime import datetime, timezone
from urllib.parse import urlparse

SCRAPERS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRAPERS_DIR))

from dotenv import load_dotenv
from supabase import create_client
load_dotenv(SCRAPERS_DIR / '.env')

from core.platform_detector import detect_platform
from platforms.shopify_scraper import scrape_shopify
from platforms.woocommerce_scraper import scrape_woocommerce
from platforms.generic_scraper import scrape_generic

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)


def extract_store_name(url: str) -> str:
    """استخراج اسم المتجر من URL"""
    try:
        domain = urlparse(url).netloc.replace('www.', '')
        return domain.split('.')[0].capitalize()
    except:
        return "Unknown Store"


def ensure_competitor(supabase, url: str) -> dict:
    """ابحث أو أضف المنافس تلقائياً"""
    # 1. البحث عن URL الحالي
    res = supabase.table("competitors").select("id, name").eq("website", url).execute()
    if res.data:
        logger.info(f"✅ Found existing competitor")
        return res.data[0]
    
    # 2. محاولة مع trailing slash
    alt = url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")
    res = supabase.table("competitors").select("id, name").eq("website", alt).execute()
    if res.data:
        logger.info(f"✅ Found existing competitor (with slash)")
        return res.data[0]
    
    # 3. إضافة تلقائية
    name = extract_store_name(url)
    logger.info(f"🆕 Competitor not found — auto-adding: {name}")
    
    # جلب أول user من DB
    users = supabase.table("users").select("id").limit(1).execute()
    if not users.data:
        logger.error("❌ No users in DB. Please sign in to the app first.")
        sys.exit(1)
    
    user_id = users.data[0]['id']
    
    # ✅ INSERT بدون .single() (متوافق مع Supabase v2.31+)
    try:
        inserted = supabase.table("competitors").insert({
            'name': name,
            'website': url,
            'user_id': user_id,
        }).execute()
        
        if inserted.data and len(inserted.data) > 0:
            logger.info(f"✅ Auto-added: {name} (ID: {inserted.data[0]['id'][:8]}...)")
            return inserted.data[0]
        else:
            logger.error("❌ Insert succeeded but returned no data")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"❌ Failed to insert competitor: {e}")
        logger.info("💡 Possible RLS issue — check Supabase RLS policies for competitors table")
        sys.exit(1)


def main():
    print("\n" + "="*60)
    print("🚀 Velora — Single Store Scan")
    print("="*60 + "\n")
    
    # 1. التحقق من Credentials
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    
    if not supabase_url or not supabase_key:
        logger.error("❌ Missing Supabase credentials in .env")
        sys.exit(1)
    
    # 2. تحديد URL الهدف
    url = sys.argv[1] if len(sys.argv) > 1 else os.getenv("COMPETITOR_URL")
    if not url:
        logger.error("❌ Usage: python main.py https://store.com")
        sys.exit(1)
    
    logger.info(f"🎯 Target: {url}")
    
    # 3. الاتصال بـ Supabase
    try:
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Connected to Supabase")
    except Exception as e:
        logger.error(f"❌ Failed to connect to Supabase: {e}")
        sys.exit(1)
    
    # 4. جلب أو إضافة المنافس
    try:
        competitor = ensure_competitor(supabase, url)
        logger.info(f"✅ Competitor: {competitor['name']} (ID: {competitor['id'][:8]}...)")
    except Exception as e:
        logger.error(f"❌ Failed to get competitor: {e}")
        sys.exit(1)
    
    # 5. تحديد المنصة
    platform = detect_platform(url)
    
    scrapers = {
        'shopify': scrape_shopify,
        'woocommerce': scrape_woocommerce,
        'generic': scrape_generic,
    }
    
    scraper = scrapers.get(platform, scrape_generic)
    logger.info(f"🕷️ Using {platform} scraper...")
    
    # 6. تشغيل الـ scraper
    try:
        products = scraper(url)
    except Exception as e:
        logger.error(f"❌ Scraper failed: {e}")
        sys.exit(1)
    
    if not products:
        logger.warning("⚠️ No products scraped. Possible causes:")
        logger.warning("   - Store blocked the request (try different User-Agent)")
        logger.warning("   - Store uses different platform structure")
        logger.warning("   - Network issue")
        sys.exit(0)
    
    logger.info(f"📦 Scraped {len(products)} products")
    
    # 7. إضافة metadata لكل منتج
    current_time = datetime.now(timezone.utc).isoformat()
    for p in products:
        p["competitor_id"] = competitor['id']
        p["last_updated_at"] = current_time
        # التأكد من وجود الحقول الأساسية
        p.setdefault("title", "Unknown Product")
        p.setdefault("product_url", url)
        p.setdefault("current_price", 0.0)
    
    # 8. حفظ في Supabase (UPSERT)
    try:
        upsert_res = supabase.table("products").upsert(
            products,
            on_conflict="competitor_id,product_url"
        ).execute()
        
        saved_count = len(upsert_res.data) if upsert_res.data else len(products)
        logger.info(f"✅ Upserted {saved_count} products to Supabase")
        
    except Exception as e:
        logger.error(f"❌ Failed to save products: {e}")
        logger.info("💡 Check Supabase RLS policies for products table")
        sys.exit(1)
    
    # 9. تحديث last_scan_at
    try:
        supabase.table("competitors").update({
            "last_scan_at": current_time
        }).eq("id", competitor['id']).execute()
        logger.info(f"🕐 Updated last_scan_at")
    except Exception as e:
        logger.warning(f"⚠️ Could not update last_scan_at: {e}")
    
    # 10. الملخص النهائي
    print("\n" + "="*60)
    logger.info(f"🎉 Successfully saved {len(products)} products for {competitor['name']}!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
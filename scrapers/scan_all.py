"""
🚀 Scan All Competitors
يشغّل الـ scraper على كل المنافسين في قاعدة البيانات تلقائياً.
هذا هو الملف الذي سيعمل على GitHub Actions كل 6 ساعات.
"""
import os
import sys
import logging
from pathlib import Path
from datetime import datetime, timezone

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


def scrape_competitor(supabase, competitor: dict):
    """يشغّل الـ scraper على منافس واحد بناءً على منصته"""
    url = competitor['website']
    name = competitor['name']
    comp_id = competitor['id']
    
    print(f"\n{'='*60}")
    logger.info(f"🎯 Scanning: {name} ({url})")
    
    # 1. تحديد المنصة تلقائياً
    platform = detect_platform(url)
    
    # 2. اختيار الـ scraper المناسب
    scraper_map = {
        'shopify': scrape_shopify,
        'woocommerce': scrape_woocommerce,
        'generic': scrape_generic,
    }
    
    scraper = scraper_map.get(platform)
    if not scraper:
        logger.warning(f"⚠️ No scraper for platform: {platform}")
        return 0
    
    # 3. تشغيل الـ scraper
    try:
        products = scraper(url)
    except Exception as e:
        logger.error(f"❌ Scraper failed for {name}: {e}")
        return 0
    
    if not products:
        logger.warning(f"⚠️ No products scraped for {name}")
        return 0
    
    logger.info(f"📦 Scraped {len(products)} products")
    
    # 4. إضافة metadata
    current_time = datetime.now(timezone.utc).isoformat()
    for p in products:
        p["competitor_id"] = comp_id
        p["last_updated_at"] = current_time
    
    # 5. حفظ في Supabase
    try:
        supabase.table("products").upsert(
            products,
            on_conflict="competitor_id,product_url"
        ).execute()
        logger.info(f"✅ Saved {len(products)} products for {name}")
    except Exception as e:
        logger.error(f"❌ Error saving products for {name}: {e}")
        return 0
    
    # 6. تحديث وقت آخر scan
    try:
        supabase.table("competitors").update({
            "last_scan_at": current_time
        }).eq("id", comp_id).execute()
    except Exception as e:
        logger.warning(f"⚠️ Could not update last_scan_at for {name}: {e}")
    
    return len(products)


def main():
    print("\n" + "="*70)
    print("🚀 Velora — Scan All Competitors (Auto Mode)")
    print("="*70)
    
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    
    if not supabase_url or not supabase_key:
        logger.error("❌ Missing Supabase credentials in .env")
        sys.exit(1)
    
    # الاتصال بـ Supabase
    try:
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Connected to Supabase")
    except Exception as e:
        logger.error(f"❌ Failed to connect: {e}")
        sys.exit(1)
    
    # جلب كل المنافسين
    try:
        res = supabase.table("competitors").select("id, name, website").execute()
        competitors = res.data or []
    except Exception as e:
        logger.error(f"❌ Failed to fetch competitors: {e}")
        sys.exit(1)
    
    if not competitors:
        logger.warning("⚠️ No competitors found in database")
        return
    
    logger.info(f"📋 Found {len(competitors)} competitors to scan")
    
    # معالجة كل منافس
    total_products = 0
    success_count = 0
    
    for competitor in competitors:
        if not competitor.get('website'):
            logger.warning(f"⚠️ Skipping {competitor.get('name', 'unknown')} — no website")
            continue
        
        products_scraped = scrape_competitor(supabase, competitor)
        if products_scraped > 0:
            total_products += products_scraped
            success_count += 1
    
    # الملخص النهائي
    print("\n" + "="*70)
    print("📊 SCAN SUMMARY")
    print("="*70)
    logger.info(f"✅ Competitors scanned: {success_count}/{len(competitors)}")
    logger.info(f"📦 Total products saved: {total_products}")
    logger.info(f"🕐 Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70 + "\n")


if __name__ == "__main__":
    main()
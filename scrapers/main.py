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
    try:
        domain = urlparse(url).netloc.replace('www.', '')
        return domain.split('.')[0].capitalize()
    except:
        return "Unknown Store"


def ensure_competitor(supabase, url: str) -> dict:
    """ابحث أو أضف المنافس تلقائياً"""
    res = supabase.table("competitors").select("id, name").eq("website", url).execute()
    if res.data:
        return res.data[0]
    
    alt = url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")
    res = supabase.table("competitors").select("id, name").eq("website", alt).execute()
    if res.data:
        return res.data[0]
    
    # إضافة تلقائية
    name = extract_store_name(url)
    users = supabase.table("users").select("id").limit(1).execute()
    if not users.data:
        logger.error("❌ No users in DB")
        sys.exit(1)
    
    inserted = supabase.table("competitors").insert({
        'name': name,
        'website': url,
        'user_id': users.data[0]['id'],
    }).select("id, name").single().execute()
    
    logger.info(f"🆕 Auto-added: {name}")
    return inserted.data


def main():
    print("\n" + "="*60)
    print("🚀 Velora — Single Store Scan")
    print("="*60 + "\n")
    
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    
    if not supabase_url or not supabase_key:
        logger.error("❌ Missing Supabase credentials")
        sys.exit(1)
    
    url = sys.argv[1] if len(sys.argv) > 1 else os.getenv("COMPETITOR_URL")
    if not url:
        logger.error("❌ Usage: python main.py https://store.com")
        sys.exit(1)
    
    logger.info(f"🎯 Target: {url}")
    
    supabase = create_client(supabase_url, supabase_key)
    competitor = ensure_competitor(supabase, url)
    
    logger.info(f"✅ Competitor: {competitor['name']}")
    
    # تحديد المنصة
    platform = detect_platform(url)
    
    scrapers = {
        'shopify': scrape_shopify,
        'woocommerce': scrape_woocommerce,
        'generic': scrape_generic,
    }
    
    scraper = scrapers.get(platform, scrape_generic)
    logger.info(f"🕷️ Using {platform} scraper...")
    
    products = scraper(url)
    if not products:
        logger.warning("⚠️ No products scraped")
        sys.exit(0)
    
    logger.info(f"📦 Scraped {len(products)} products")
    
    # حفظ
    current_time = datetime.now(timezone.utc).isoformat()
    for p in products:
        p["competitor_id"] = competitor['id']
        p["last_updated_at"] = current_time
    
    supabase.table("products").upsert(
        products,
        on_conflict="competitor_id,product_url"
    ).execute()
    
    supabase.table("competitors").update({
        "last_scan_at": current_time
    }).eq("id", competitor['id']).execute()
    
    logger.info(f"🎉 Saved {len(products)} products!")


if __name__ == "__main__":
    main()
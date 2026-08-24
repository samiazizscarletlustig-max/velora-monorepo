"""
🚀 Scan All Competitors + AI Analysis
يعمل تلقائياً على GitHub Actions كل 6 ساعات — لكل الأسواق ولكل العملاء
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
from main import generate_analysis

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)


def scrape_competitor(supabase, competitor: dict) -> int:
    url = competitor['website']
    name = competitor['name']
    comp_id = competitor['id']

    print(f"\n{'='*60}")
    logger.info(f"🎯 Scanning: {name} ({url})")

    platform = detect_platform(url)
    scrapers = {
        'shopify': scrape_shopify,
        'woocommerce': scrape_woocommerce,
        'generic': scrape_generic,
    }
    scraper = scrapers.get(platform, scrape_generic)
    logger.info(f"🕷️ Using {platform} scraper...")

    try:
        products = scraper(url)
    except Exception as e:
        logger.error(f"❌ Scraper failed: {e}")
        return 0

    if not products:
        logger.warning(f"⚠️ No products for {name}")
        return 0

    logger.info(f"📦 Scraped {len(products)} products")

    current_time = datetime.now(timezone.utc).isoformat()
    for p in products:
        p["competitor_id"] = comp_id
        p["last_updated_at"] = current_time
        p.setdefault("title", "Unknown Product")
        p.setdefault("product_url", url)
        p.setdefault("current_price", 0.0)
        p.setdefault("image_url", "")
        p.pop("sku", None)

    try:
        supabase.table("products").upsert(
            products, on_conflict="competitor_id,product_url"
        ).execute()
        logger.info(f"✅ Saved {len(products)} products for {name}")
    except Exception as e:
        logger.error(f"❌ Error saving products: {e}")
        return 0

    try:
        generate_analysis(supabase, competitor, products, current_time)
    except Exception as e:
        logger.warning(f"⚠️ Analysis failed: {e}")

    try:
        supabase.table("competitors").update({
            "last_scan_at": current_time
        }).eq("id", comp_id).execute()
    except Exception as e:
        logger.warning(f"⚠️ Could not update last_scan_at: {e}")

    return len(products)


def main():
    print("\n" + "="*70)
    print("🚀 Velora — Scan All Markets (Auto for ALL clients)")
    print("="*70)

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        logger.error("❌ Missing Supabase credentials")
        sys.exit(1)

    try:
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Connected to Supabase")
    except Exception as e:
        logger.error(f"❌ Connection failed: {e}")
        sys.exit(1)

    try:
        res = supabase.table("competitors").select("id, name, website").execute()
        competitors = res.data or []
    except Exception as e:
        logger.error(f"❌ Failed to fetch competitors: {e}")
        sys.exit(1)

    if not competitors:
        logger.warning("⚠️ No competitors in database")
        return

    logger.info(f"📋 Found {len(competitors)} markets to scan (all clients)")

    total_products = 0
    success_count = 0

    for competitor in competitors:
        if not competitor.get('website'):
            logger.warning(f"⏭️ Skipping {competitor.get('name')} — no website")
            continue
        count = scrape_competitor(supabase, competitor)
        if count > 0:
            total_products += count
            success_count += 1

    print("\n" + "="*70)
    print("📊 SCAN SUMMARY")
    print("="*70)
    logger.info(f"✅ Markets scanned: {success_count}/{len(competitors)}")
    logger.info(f"📦 Total products: {total_products}")
    print("="*70 + "\n")


if __name__ == "__main__":
    main()
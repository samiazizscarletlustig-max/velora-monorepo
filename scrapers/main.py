"""
🚀 Scan Single Competitor + AI Analysis
python main.py https://anystore.com
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
    res = supabase.table("competitors").select("id, name").eq("website", url).execute()
    if res.data:
        logger.info("✅ Found existing competitor")
        return res.data[0]

    alt = url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")
    res = supabase.table("competitors").select("id, name").eq("website", alt).execute()
    if res.data:
        logger.info("✅ Found existing competitor (with slash)")
        return res.data[0]

    name = extract_store_name(url)
    logger.info(f"🆕 Competitor not found — auto-adding: {name}")

    users = supabase.table("users").select("id").limit(1).execute()
    if not users.data:
        logger.error("❌ No users in DB. Please sign in to the app first.")
        sys.exit(1)

    try:
        inserted = supabase.table("competitors").insert({
            'name': name,
            'website': url,
            'user_id': users.data[0]['id'],
        }).execute()

        if inserted.data:
            logger.info(f"✅ Auto-added: {name}")
            return inserted.data[0]
        logger.error("❌ Insert returned no data")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Failed to insert competitor: {e}")
        sys.exit(1)


# ═══════════════════════════════════════════════════════
# 🧠 محرك التحليلات — يولد رؤى من البيانات الحقيقية
# ═══════════════════════════════════════════════════════
def generate_analysis(supabase, competitor: dict, products: list, timestamp: str):
    """توليد رؤى تحليلية وحفظها في ai_insights"""
    insights = []
    name = competitor['name']
    prices = [p["current_price"] for p in products if p.get("current_price")]

    if prices:
        avg = sum(prices) / len(prices)
        mn, mx = min(prices), max(prices)

        insights.append({
            "type": "pricing",
            "title": f"{name} — Pricing Overview",
            "summary": f"Average price ${avg:.2f} across {len(prices)} products. Range: ${mn:.2f} – ${mx:.2f}.",
            "ai_recommendation": f"Position your core products near the ${avg:.0f} average to stay competitive.",
            "severity": "medium",
        })

        cheap = [p for p in prices if p < avg * 0.7]
        if len(cheap) >= 3:
            insights.append({
                "type": "opportunity",
                "title": f"{name} — Entry-Level Cluster",
                "summary": f"{len(cheap)} products priced below ${avg * 0.7:.0f} — strong entry segment.",
                "ai_recommendation": "A competitive starter product could capture this price-sensitive audience.",
                "severity": "high",
            })

        premium = [p for p in prices if p > avg * 1.5]
        if len(premium) >= 3:
            insights.append({
                "type": "opportunity",
                "title": f"{name} — Premium Cluster",
                "summary": f"{len(premium)} products priced above ${avg * 1.5:.0f} — premium segment present.",
                "ai_recommendation": "Consider a high-margin flagship product to compete in the premium tier.",
                "severity": "medium",
            })

    insights.append({
        "type": "catalog",
        "title": f"{name} — Catalog Update",
        "summary": f"{len(products)} products tracked in the latest scan.",
        "ai_recommendation": "Monitor catalog size weekly for expansion/contraction signals.",
        "severity": "low",
    })

    db_rows = [{
        "competitor_id": competitor['id'],
        "type": i["type"],
        "title": i["title"],
        "summary": i["summary"],
        "ai_recommendation": i["ai_recommendation"],
        "severity": i["severity"],
    } for i in insights]

    try:
        supabase.table("ai_insights").insert(db_rows).execute()
        logger.info(f"🧠 Saved {len(db_rows)} AI insights")
    except Exception as e:
        logger.warning(f"⚠️ Could not save insights: {e}")


def main():
    print("\n" + "="*60)
    print("🚀 Velora — Single Store Scan + Analysis")
    print("="*60 + "\n")

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        logger.error("❌ Missing Supabase credentials in .env")
        sys.exit(1)

    url = sys.argv[1] if len(sys.argv) > 1 else os.getenv("COMPETITOR_URL")
    if not url:
        logger.error("❌ Usage: python main.py https://store.com")
        sys.exit(1)

    logger.info(f"🎯 Target: {url}")

    try:
        supabase = create_client(supabase_url, supabase_key)
        logger.info("✅ Connected to Supabase")
    except Exception as e:
        logger.error(f"❌ Failed to connect: {e}")
        sys.exit(1)

    competitor = ensure_competitor(supabase, url)
    logger.info(f"✅ Competitor: {competitor['name']}")

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
        sys.exit(1)

    if not products:
        logger.warning("⚠️ No products scraped.")
        sys.exit(0)

    logger.info(f"📦 Scraped {len(products)} products")

    current_time = datetime.now(timezone.utc).isoformat()
    for p in products:
        p["competitor_id"] = competitor['id']
        p["last_updated_at"] = current_time
        p.setdefault("title", "Unknown Product")
        p.setdefault("product_url", url)
        p.setdefault("current_price", 0.0)
        p.setdefault("image_url", "")
        p.pop("sku", None)

    try:
        upsert_res = supabase.table("products").upsert(
            products,
            on_conflict="competitor_id,product_url"
        ).execute()
        saved = len(upsert_res.data) if upsert_res.data else len(products)
        logger.info(f"✅ Upserted {saved} products to Supabase")
    except Exception as e:
        logger.error(f"❌ Failed to save products: {e}")
        sys.exit(1)

    # 🧠 توليد التحليلات
    generate_analysis(supabase, competitor, products, current_time)

    try:
        supabase.table("competitors").update({
            "last_scan_at": current_time
        }).eq("id", competitor['id']).execute()
        logger.info("🕐 Updated last_scan_at")
    except Exception as e:
        logger.warning(f"⚠️ Could not update last_scan_at: {e}")

    print("\n" + "="*60)
    logger.info(f"🎉 Saved {len(products)} products + insights for {competitor['name']}!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
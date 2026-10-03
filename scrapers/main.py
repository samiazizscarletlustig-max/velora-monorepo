"""
Velora - Advanced Competitive Market Intelligence Engine
=========================================================
PRODUCTION VERSION v4.2.0 - Enterprise-Hardened Deterministic Engine

[OK] 100% Rule-Based & Mathematical Analysis (No LLM API calls, zero AI cost)
[OK] Unlimited Scalability (no rate limits - math doesn't throttle)
[OK] GRACEFUL 403/404 HANDLING: a blocked site never crashes the run or
     leaves the client staring at a blank dashboard - it gets a clear,
     specific "why" instead
[OK] HYPER-SPECIFIC INSIGHTS: recommendations now name actual scraped
     product titles ("Launch an alternative to 'Everyday Seamless Leggings'")
     instead of generic category placeholders
[OK] Strict typing across every function signature
[OK] No silent failures: every except block logs a specific, actionable message
[OK] Chunked Supabase writes (products, price history) - safe for the
     Enterprise tier's 9,999-product ceiling
[OK] Run-level observability: a RUN SUMMARY block reporting scanned /
     succeeded / blocked / failed / skipped counts and elapsed time
[OK] Hidden Signal Extraction (Sales Velocity, Scarcity, Assortment
     Freshness) with normalized, case-insensitive, whitespace-robust matching

Architecture:
  [GitHub Actions] -> [Scraper] -> [Deterministic Math Engine] -> [Supabase] -> [Flutter App]

===================================================================
WHAT CHANGED FROM v4.1.0 AND WHY
===================================================================
1. BUG FIX: the "Quick Wins" insight in v4.1.0 built its summary string with
   plain quotes, not an f-string - "...${data['largest_gap_size']}..." was
   being saved to the database LITERALLY, not interpolated. Every Pro user
   was seeing that raw Python expression on their dashboard. Fixed.

2. SCRAPER BLOCKING: v4.1.0 had no way to tell "no products because the
   store genuinely has none" apart from "no products because Adidas just
   403'd us." Added `ScraperBlockedError`, a `ScanResult` enum, and a
   dedicated client-facing "Scan Blocked" insight so a protected site never
   looks like silent failure or (worse) an empty competitor.

3. HYPER-SPECIFIC RECOMMENDATIONS: every insight that references a product
   category or signal now pulls 1-2 REAL scraped titles to anchor the
   recommendation in something the client can click and verify, instead of
   an abstract category name.

4. SILENT FAILURES REMOVED: every bare `except Exception: pass` in v4.1.0
   (trend-insight cleanup, blocked-insight cleanup) now logs what happened.

5. CHUNKED WRITES: upsert_products and save_price_history now batch in
   groups of 500 rather than one giant payload - avoids PostgREST payload/
   timeout issues at the Enterprise tier's 9,999-product ceiling.

6. RUN SUMMARY: run_dynamic_mode now reports a clear end-of-run tally
   instead of leaving you to infer results from scrolling logs.

===================================================================
INTEGRATION NOTE FOR PLATFORM SCRAPER MODULES
===================================================================
scrape_shopify / scrape_woocommerce / scrape_generic should raise
`ScraperBlockedError(status_code, reason)` (imported from this module)
whenever they detect a bot-protection page (HTTP 403/404, or a response
body containing phrases like "security issue", "captcha", "access denied",
"unusual traffic"). A `detect_block_signal()` helper is provided below for
exactly this check. Without that change, this file still catches
`requests.exceptions.HTTPError` with a 403/404 status as a fallback, but a
scraper that swallows the exception internally and returns `[]` cannot be
distinguished from "store has zero products" - the explicit exception is
the real fix.
"""

import os
import sys
import time
import json
import logging
import argparse
import re
import inspect
import asyncio
import requests
import statistics
from pathlib import Path
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse
from typing import List, Dict, Optional, Any, Tuple
from functools import wraps
from collections import Counter
from dataclasses import dataclass, field
from enum import Enum

SCRAPERS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRAPERS_DIR))

from dotenv import load_dotenv
from supabase import create_client, Client
load_dotenv(SCRAPERS_DIR / '.env')

from core.platform_detector import detect_platform
from platforms.shopify_scraper import scrape_shopify
from platforms.woocommerce_scraper import scrape_woocommerce
from platforms.generic_scraper import scrape_generic
from core.trend_analyzer import TrendAnalyzer

# ===================================================================
# Custom Exceptions
# ===================================================================
class ScraperBlockedError(Exception):
    """
    Raised when a target site actively blocks automated access (bot
    protection, WAF challenge, geofencing, etc.) rather than genuinely
    having no products. Platform scraper modules should raise this
    explicitly when they detect such a page; this module also catches
    requests.exceptions.HTTPError with a 403/404 status as a fallback.
    """
    def __init__(self, status_code: Optional[int], reason: str = ""):
        self.status_code = status_code
        self.reason = reason or (f"HTTP {status_code}" if status_code else "Blocked by target site")
        super().__init__(self.reason)


BLOCK_SIGNAL_PHRASES = [
    "security issue", "captcha", "access denied", "unusual traffic",
    "are you a human", "bot detection", "automatically identified",
    "verify you are a human", "request blocked", "cloudflare",
    "perimeterx", "please enable javascript and cookies",
]


def detect_block_signal(status_code: Optional[int], body_text: str = "") -> Optional[str]:
    """
    Utility for platform scraper modules: given an HTTP status and/or
    response body, returns a short reason string if this looks like a
    bot-protection block, else None. Scraper modules should call this and
    raise ScraperBlockedError(status_code, reason) when it returns non-None.
    """
    if status_code in (403, 404):
        return f"HTTP {status_code}"
    lowered = (body_text or "").lower()
    for phrase in BLOCK_SIGNAL_PHRASES:
        if phrase in lowered:
            return f"Bot-protection signal detected: '{phrase}'"
    return None


# ===================================================================
# TIER SYSTEM - Strict limits for each subscription tier
# ===================================================================
TIER_LIMITS: Dict[str, Dict[str, int]] = {
    'free':       {'max_competitors': 3,    'scan_interval_hours': 24, 'max_products': 300},
    'pro':        {'max_competitors': 10,   'scan_interval_hours': 6,  'max_products': 1000},
    'pro_plus':   {'max_competitors': 25,   'scan_interval_hours': 3,  'max_products': 2500},
    'enterprise': {'max_competitors': 9999, 'scan_interval_hours': 1,  'max_products': 9999},
}

DB_CHUNK_SIZE = 500  # rows per Supabase batch write

# ===================================================================
# Rate Limiting (scraper politeness only - no AI calls in this version)
# ===================================================================
def rate_limit(calls_per_minute: int = 10):
    def decorator(func):
        last_called = [0.0]
        min_interval = 60 / calls_per_minute
        @wraps(func)
        def wrapper(*args, **kwargs):
            elapsed = time.time() - last_called[0]
            left_to_wait = min_interval - elapsed
            if left_to_wait > 0:
                time.sleep(left_to_wait)
            last_called[0] = time.time()
            return func(*args, **kwargs)
        return wrapper
    return decorator

# ===================================================================
# Logging Configuration
# ===================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(SCRAPERS_DIR / 'scraper.log', encoding='utf-8')
    ]
)
logger = logging.getLogger('VeloraScraper')
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

# ===================================================================
# Color Codes
# ===================================================================
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_banner() -> None:
    print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.OKBLUE} Velora v4.2.0 - Enterprise-Hardened Deterministic Engine{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Graceful Blocking - Hyper-Specific Insights - Full Observability{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")

def print_success(msg: str) -> None: print(f"{Colors.OKGREEN}[OK] {msg}{Colors.ENDC}")
def print_error(msg: str) -> None: print(f"{Colors.FAIL}[ERR] {msg}{Colors.ENDC}")
def print_warning(msg: str) -> None: print(f"{Colors.WARNING}[WARN] {msg}{Colors.ENDC}")
def print_info(msg: str) -> None: print(f"{Colors.OKBLUE}[INFO] {msg}{Colors.ENDC}")
def print_header(msg: str) -> None: print(f"\n{Colors.BOLD}{Colors.OKCYAN}{msg}{Colors.ENDC}")

# ===================================================================
# Text normalization (case-insensitive, whitespace/HTML-variant robust)
# ===================================================================
_WS_RE = re.compile(r"\s+")

def normalize_text(text: Optional[str]) -> str:
    """Lowercase, collapse whitespace, and strip common HTML-entity artifacts
    (non-breaking spaces, curly quotes) before keyword matching, so minor
    formatting differences across sites don't cause missed matches."""
    if not text:
        return ""
    cleaned = text.replace("\xa0", " ").replace("\u2019", "'").replace("\u2018", "'")
    cleaned = _WS_RE.sub(" ", cleaned)
    return cleaned.strip().lower()

def _chunked(items: List[Any], size: int) -> List[List[Any]]:
    return [items[i:i + size] for i in range(0, len(items), size)]

# ===================================================================
# Configuration
# ===================================================================
class Config:
    def __init__(self) -> None:
        self.supabase_url: Optional[str] = os.getenv("SUPABASE_URL")
        self.supabase_key: Optional[str] = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        self.scan_interval: int = int(os.getenv("SCAN_INTERVAL", "86400"))
        self.max_retries: int = int(os.getenv("MAX_RETRIES", "3"))

    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials in .env")
            return False
        print_info("[ENGINE] Deterministic Analytics Engine - no external AI API required")
        return True

# ===================================================================
# Database Manager
# ===================================================================
class DatabaseManager:
    def __init__(self, supabase: Client) -> None:
        self.supabase = supabase
        self.logger = logging.getLogger('DatabaseManager')

    def get_pending_competitors(self, force_all: bool = False) -> List[Dict[str, Any]]:
        try:
            response = (
                self.supabase.table("competitors")
                .select("id, name, website, shopify_store, user_id, last_scan_at")
                .order("last_scan_at", desc=False, nullsfirst=True)
                .limit(500)
                .execute()
            )
            rows = response.data or []
            if not rows:
                self.logger.info("Found 0 competitor(s) to scan")
                return []

            user_ids = list({r.get('user_id') for r in rows if r.get('user_id')})
            tiers: Dict[str, str] = {}
            if user_ids:
                ures = self.supabase.table("users").select("id, tier").in_("id", user_ids).execute()
                tiers = {u['id']: (u.get('tier') or 'free') for u in (ures.data or [])}

            now = datetime.now(timezone.utc)
            pending: List[Dict[str, Any]] = []
            per_user: Dict[Optional[str], int] = {}

            for row in rows:
                uid = row.get('user_id')
                tier = tiers.get(uid, 'free') if uid else 'free'
                limits = TIER_LIMITS.get(tier, TIER_LIMITS['free'])

                per_user[uid] = per_user.get(uid, 0) + 1
                if per_user[uid] > limits['max_competitors']:
                    self.logger.info(f"[SKIP] {row.get('name')} (User: {uid}): tier '{tier}' cap ({limits['max_competitors']}) reached")
                    continue

                if not force_all:
                    last = row.get('last_scan_at')
                    if last:
                        last_dt = datetime.fromisoformat(last.replace('Z', '+00:00'))
                        if last_dt.tzinfo is None:
                            last_dt = last_dt.replace(tzinfo=timezone.utc)

                        hours_since_scan = (now - last_dt).total_seconds() / 3600
                        required_hours = limits['scan_interval_hours']

                        if hours_since_scan < required_hours:
                            self.logger.info(f"[SKIP] {row.get('name')} (Tier: {tier}): scanned {hours_since_scan:.1f}h ago, requires {required_hours}h")
                            continue
                        else:
                            self.logger.info(f"[SCAN] {row.get('name')} (Tier: {tier}): READY! ({hours_since_scan:.1f}h >= {required_hours}h)")
                    else:
                        self.logger.info(f"[SCAN] {row.get('name')} (Tier: {tier}): READY! (Never scanned before)")

                row['_tier'] = tier
                row['_limits'] = limits
                pending.append(row)

            self.logger.info(f"Found {len(pending)} competitor(s) to scan (tier-aware)")
            return pending
        except Exception as e:
            self.logger.error(f"Failed to fetch competitors: {e}")
            return []

    def get_or_create_competitor(self, url: str, user_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        try:
            for check_url in [url, url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")]:
                response = self.supabase.table("competitors").select("id, name, website, user_id").eq("website", check_url).execute()
                if response.data:
                    return response.data[0]

            store_name = urlparse(url).netloc.replace('www.', '').split('.')[0].capitalize()
            if not user_id:
                result = self.supabase.auth.admin.list_users()
                users = result.get('users', []) if isinstance(result, dict) else (getattr(result, 'users', []) or [])
                if not users:
                    print_error("No users found in auth.users.")
                    return None
                user_id = users[0]['id']

            response = self.supabase.table("competitors").insert({
                'name': store_name, 'website': url, 'user_id': user_id,
                'created_at': datetime.now(timezone.utc).isoformat()
            }).execute()

            if response.data:
                print_success(f"Created competitor: {store_name} for user {user_id}")
            return response.data[0] if response.data else None
        except Exception as e:
            self.logger.error(f"Failed to create competitor: {e}")
            return None

    def upsert_products(self, products: List[Dict[str, Any]], chunk_size: int = DB_CHUNK_SIZE) -> int:
        """Batched upsert. Enterprise tier allows up to 9,999 products per
        competitor - a single unchunked payload at that size risks PostgREST
        payload limits or request timeouts, so we write in fixed-size chunks."""
        total = 0
        batches = _chunked(products, chunk_size)
        for idx, batch in enumerate(batches, 1):
            try:
                response = self.supabase.table("products").upsert(batch, on_conflict="competitor_id,product_url").execute()
                count = len(response.data) if response.data else len(batch)
                total += count
            except Exception as e:
                self.logger.error(f"Failed to upsert product batch {idx}/{len(batches)} ({len(batch)} rows): {e}")
        self.logger.info(f"Upserted {total}/{len(products)} products total across {len(batches)} batch(es)")
        return total

    def save_price_history(self, products: List[Dict[str, Any]], competitor_id: str, chunk_size: int = DB_CHUNK_SIZE) -> int:
        now = datetime.now(timezone.utc).isoformat()
        history_rows = [
            {
                "competitor_id": competitor_id,
                "product_url": str(p.get("product_url", ""))[:500],
                "product_title": str(p.get("title", ""))[:200],
                "price": float(p.get("current_price")),
                "recorded_at": now,
            }
            for p in products
            if p.get("current_price") and p.get("current_price") > 0
        ]

        if not history_rows:
            return 0

        total = 0
        batches = _chunked(history_rows, chunk_size)
        for idx, batch in enumerate(batches, 1):
            try:
                self.supabase.table("price_history").insert(batch).execute()
                total += len(batch)
            except Exception as e:
                self.logger.warning(f"price_history insert failed for batch {idx}/{len(batches)} (check schema/permissions): {e}")
        self.logger.info(f"Saved {total}/{len(history_rows)} price history records")
        return total

    def has_previous_price_history(self, competitor_id: str) -> bool:
        try:
            res = self.supabase.table("price_history").select("id").eq("competitor_id", competitor_id).limit(1).execute()
            return len(res.data or []) > 0
        except Exception as e:
            self.logger.warning(f"Could not check price history for {competitor_id}: {e}")
            return False

    def get_price_delta(self, competitor_id: str) -> Optional[Dict[str, Any]]:
        try:
            res = (
                self.supabase.table("price_history")
                .select("price, recorded_at")
                .eq("competitor_id", competitor_id)
                .order("recorded_at", desc=True)
                .limit(2000)
                .execute()
            )
            rows = res.data or []
            if len(rows) < 2:
                return None

            batches: Dict[str, List[float]] = {}
            for r in rows:
                ts, price = r.get("recorded_at"), r.get("price")
                if ts and price is not None:
                    batches.setdefault(ts, []).append(float(price))

            timestamps = sorted(batches.keys(), reverse=True)
            if len(timestamps) < 2:
                return None

            latest_avg = sum(batches[timestamps[0]]) / len(batches[timestamps[0]])
            prior_avg = sum(batches[timestamps[1]]) / len(batches[timestamps[1]])
            if prior_avg == 0:
                return None

            pct_change = round(((latest_avg - prior_avg) / prior_avg) * 100, 1)
            return {
                "prior_avg": round(prior_avg, 2), "latest_avg": round(latest_avg, 2),
                "pct_change": pct_change, "prior_scan_date": timestamps[1], "latest_scan_date": timestamps[0],
            }
        except Exception as e:
            self.logger.warning(f"Could not compute price delta for {competitor_id}: {e}")
            return None

    def save_insights(self, insights: List[Dict[str, Any]], competitor_id: Optional[str] = None) -> bool:
        try:
            comp_id = competitor_id or (insights[0].get('competitor_id') if insights else None)
            if comp_id:
                try:
                    # Clears prior insights AND any stale "scan_blocked" notice -
                    # a successful scan should always supersede a prior block notice.
                    self.supabase.table("ai_insights").delete().eq("competitor_id", comp_id).neq("type", "trend").execute()
                except Exception as e:
                    self.logger.warning(f"Could not clear prior insights for {comp_id} before save (duplicates may appear): {e}")

            for insight in insights:
                insight['competitor_id'] = comp_id
                insight['created_at'] = datetime.now(timezone.utc).isoformat()

            self.supabase.table("ai_insights").insert(insights).execute()
            self.logger.info(f"Saved {len(insights)} deterministic insights")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save insights for competitor {competitor_id}: {e}")
            return False

    def save_blocked_insight(self, competitor_id: str, competitor_name: str,
                              status_code: Optional[int], reason: str) -> None:
        """Client-facing explanation for a blocked scan - replaces silent
        empty-dashboard behavior with a specific, non-alarming message."""
        timestamp = datetime.now(timezone.utc).isoformat()
        status_part = f" (HTTP {status_code})" if status_code else ""
        insight = {
            "competitor_id": competitor_id,
            "type": "scan_blocked",
            "title": "Scan Blocked - Site Protection Detected",
            "summary": (
                f"We were unable to retrieve pricing data for {competitor_name} this cycle because the "
                f"site is actively blocking automated requests{status_part}. Reason: {reason}. This is "
                "common on sites using bot-protection services such as Cloudflare, Akamai, or PerimeterX, "
                "and does not indicate a problem with your account or configuration."
            ),
            "ai_recommendation": (
                "No action needed right now - we'll automatically retry on the next scheduled scan. If "
                "this persists across several cycles, contact support; this competitor may need "
                "proxy-based or headless-browser scraping enabled."
            ),
            "severity": "medium",
            "created_at": timestamp,
        }
        try:
            self.supabase.table("ai_insights").delete().eq("competitor_id", competitor_id).eq("type", "scan_blocked").execute()
        except Exception as e:
            self.logger.warning(f"Could not clear prior blocked-insight for {competitor_id}: {e}")
        try:
            self.supabase.table("ai_insights").insert(insight).execute()
            self.logger.info(f"Recorded 'scan_blocked' insight for {competitor_name}")
        except Exception as e:
            self.logger.error(f"Failed to save blocked insight for {competitor_name}: {e}")

    def save_trend_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
            formatted = [{
                "competitor_id": i.get("competitor_id"), "type": "trend", "title": i.get("title", "Trend Analysis"),
                "summary": i.get("summary", ""), "ai_recommendation": i.get("recommendation", ""),
                "severity": str(i.get("severity", "medium")).lower(), "created_at": datetime.now(timezone.utc).isoformat()
            } for i in insights]

            if formatted:
                self.supabase.table("ai_insights").insert(formatted).execute()
                self.logger.info(f"Saved {len(formatted)} trend insights")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save trend insights: {e}")
            return False

    def update_competitor_scan_time(self, competitor_id: str) -> bool:
        try:
            self.supabase.table("competitors").update({"last_scan_at": datetime.now(timezone.utc).isoformat()}).eq("id", competitor_id).execute()
            self.logger.info("Updated scan timestamp")
            return True
        except Exception as e:
            self.logger.error(f"Failed to update timestamp for {competitor_id}: {e}")
            return False

# ===================================================================
# DETERMINISTIC MARKET INTELLIGENCE ENGINE (v4.2.0)
# ===================================================================
class DeterministicMarketIntelligenceEngine:
    CATEGORY_KEYWORDS: List[str] = [
        "shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock",
        "accessory", "sweater", "hoodie", "short", "skirt", "coat", "boot",
        "sandal", "sneaker", "scarf", "belt", "watch", "jewelry", "legging",
        "tank", "bra", "jogger", "shorts", "t-shirt", "tee", "backpack",
        "oil", "balm", "kit", "socks", "underwear", "boxer", "glove", "strap"
    ]
    PROMOTION_KEYWORDS: List[str] = ["sale", "off", "discount", "limited", "new", "bestseller", "clearance", "final sale"]
    VELOCITY_KEYWORDS: List[str] = ["bestseller", "best selling", "popular", "top rated", "favorite", "trending", "most loved"]
    SCARCITY_KEYWORDS: List[str] = ["low stock", "selling fast", "limited", "final sale", "clearance", "last chance", "only a few left"]
    FRESHNESS_KEYWORDS: List[str] = ["new in", "just dropped", "new arrival", "fresh", "launch"]

    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]],
                 db: Optional[DatabaseManager] = None) -> None:
        self.competitor = competitor
        self.products = products
        self.db = db
        self.name: str = competitor.get('name', 'Unknown')
        self.tier: str = competitor.get('_tier', 'free')
        self.limits: Dict[str, int] = competitor.get('_limits', TIER_LIMITS['free'])
        self.logger = logging.getLogger('DeterministicEngine')

    def generate_all_insights(self) -> List[Dict[str, Any]]:
        return self._generate_deterministic_insights()

    # -----------------------------------------------------------------
    # Hyper-specificity helpers: pull real scraped titles to anchor
    # recommendations instead of abstract category names.
    # -----------------------------------------------------------------
    def _title_near_price(self, target_price: float) -> str:
        best_title = "an unnamed product"
        best_diff = float("inf")
        for p in self.products:
            price = p.get("current_price")
            if price is None:
                continue
            diff = abs(float(price) - target_price)
            if diff < best_diff:
                best_diff = diff
                best_title = str(p.get("title", "")).strip() or best_title
        return best_title

    @staticmethod
    def _format_sample_titles(samples: List[str], max_show: int = 2) -> str:
        shown = [f"'{t}'" for t in samples[:max_show] if t]
        if not shown:
            return ""
        if len(shown) == 1:
            return shown[0]
        return f"{shown[0]} and {shown[1]}"

    # -----------------------------------------------------------------
    # Core analysis
    # -----------------------------------------------------------------
    def _analyze_data(self) -> Dict[str, Any]:
        prices = [p.get("current_price", 0) for p in self.products if p.get("current_price") and p.get("current_price") > 0]
        if not prices:
            return {"error": "No pricing data available"}

        avg_price = sum(prices) / len(prices)
        median_price = statistics.median(prices)
        try:
            stdev_price = statistics.stdev(prices) if len(prices) > 1 else 0.0
        except statistics.StatisticsError:
            stdev_price = 0.0

        budget_threshold = avg_price * 0.6
        premium_threshold = avg_price * 1.5

        budget_products = [p for p in prices if p < budget_threshold]
        mid_tier = [p for p in prices if budget_threshold <= p <= premium_threshold]
        premium_products = [p for p in prices if p > premium_threshold]
        sorted_products = sorted(self.products, key=lambda x: x.get("current_price", 0), reverse=True)

        category_counts: Counter = Counter()
        category_samples: Dict[str, List[str]] = {}
        velocity_samples: List[str] = []
        scarcity_samples: List[str] = []
        freshness_samples: List[str] = []
        promotion_count = budget_promo_count = premium_promo_count = 0

        for p in self.products:
            raw_title = str(p.get("title", ""))
            title = normalize_text(raw_title)
            price = p.get("current_price", 0) or 0

            for kw in self.CATEGORY_KEYWORDS:
                if kw in title:
                    category_counts[kw] += 1
                    category_samples.setdefault(kw, [])
                    if raw_title and raw_title not in category_samples[kw] and len(category_samples[kw]) < 2:
                        category_samples[kw].append(raw_title.strip())

            if any(promo in title for promo in self.PROMOTION_KEYWORDS):
                promotion_count += 1
                if price < budget_threshold:
                    budget_promo_count += 1
                elif price > premium_threshold:
                    premium_promo_count += 1

            if any(kw in title for kw in self.VELOCITY_KEYWORDS) and raw_title and len(velocity_samples) < 2:
                velocity_samples.append(raw_title.strip())
            if any(kw in title for kw in self.SCARCITY_KEYWORDS) and raw_title and len(scarcity_samples) < 2:
                scarcity_samples.append(raw_title.strip())
            if any(kw in title for kw in self.FRESHNESS_KEYWORDS) and raw_title and len(freshness_samples) < 2:
                freshness_samples.append(raw_title.strip())

        velocity_count = sum(1 for p in self.products if any(kw in normalize_text(str(p.get("title", ""))) for kw in self.VELOCITY_KEYWORDS))
        scarcity_count = sum(1 for p in self.products if any(kw in normalize_text(str(p.get("title", ""))) for kw in self.SCARCITY_KEYWORDS))
        freshness_count = sum(1 for p in self.products if any(kw in normalize_text(str(p.get("title", ""))) for kw in self.FRESHNESS_KEYWORDS))

        top_categories = category_counts.most_common(5)
        total_cat = sum(category_counts.values())
        hhi = sum((count / total_cat) ** 2 for count in category_counts.values()) if total_cat > 0 else 0.0
        hhi_score = round(hhi * 10000, 1)
        hhi_interp = "highly concentrated" if hhi_score > 2500 else "moderately concentrated" if hhi_score > 1500 else "diversified"

        price_gaps: List[Dict[str, float]] = []
        sorted_prices = sorted(prices)
        for i in range(len(sorted_prices) - 1):
            gap = sorted_prices[i + 1] - sorted_prices[i]
            if gap > avg_price * 0.25:
                price_gaps.append({"from": round(sorted_prices[i], 2), "to": round(sorted_prices[i + 1], 2), "size": round(gap, 2)})

        price_gap_ratios = [
            {"from": g['from'], "to": g['to'], "size": g['size'], "ratio_to_avg": round(g['size'] / avg_price, 2) if avg_price > 0 else 0}
            for g in price_gaps[:5]
        ]
        cov = round(stdev_price / avg_price, 2) if avg_price > 0 else 0.0
        cov_interp = "inconsistent/opportunistic" if cov > 0.4 else "disciplined/confident" if cov < 0.15 else "moderate"

        promo_pct = round((promotion_count / len(self.products)) * 100, 1) if self.products else 0.0
        top_cat = top_categories[0] if top_categories else ("unknown", 0)
        top_cat_pct = round((top_cat[1] / len(prices)) * 100, 1) if len(prices) > 0 else 0.0
        largest_gap = price_gap_ratios[0] if price_gap_ratios else {"from": 0, "to": 0, "size": 0, "ratio_to_avg": 0}

        price_delta = self.db.get_price_delta(self.competitor['id']) if self.db else None

        return {
            "competitor_name": self.name,
            "tier_context": self.tier,
            "total_products_scanned": len(self.products),
            "products_with_pricing": len(prices),
            "avg_price": round(avg_price, 2),
            "median_price": round(median_price, 2),
            "stdev_price": round(stdev_price, 2),
            "min_price": round(min(prices), 2),
            "max_price": round(max(prices), 2),
            "cov": cov,
            "cov_interp": cov_interp,
            "hhi_score": hhi_score,
            "hhi_interp": hhi_interp,
            "top_cat": top_cat[0],
            "top_cat_count": top_cat[1],
            "top_cat_pct": top_cat_pct,
            "top_cat_samples": category_samples.get(top_cat[0], []),
            "promo_pct": promo_pct,
            "budget_promo_count": budget_promo_count,
            "premium_promo_count": premium_promo_count,
            "largest_gap_from": largest_gap['from'],
            "largest_gap_to": largest_gap['to'],
            "largest_gap_size": largest_gap['size'],
            "largest_gap_ratio": largest_gap['ratio_to_avg'],
            "budget_pct": round(len(budget_products) / len(prices) * 100, 1),
            "mid_pct": round(len(mid_tier) / len(prices) * 100, 1),
            "premium_pct": round(len(premium_products) / len(prices) * 100, 1),
            "price_delta": price_delta,
            "top_3_premium": [round(p.get("current_price", 0), 2) for p in sorted_products[:3]],
            "top_3_entry": [round(p.get("current_price", 0), 2) for p in sorted_products[-3:] if p.get("current_price")],
            "velocity_count": velocity_count,
            "velocity_pct": round((velocity_count / len(self.products)) * 100, 1) if self.products else 0.0,
            "velocity_samples": velocity_samples,
            "scarcity_count": scarcity_count,
            "scarcity_pct": round((scarcity_count / len(self.products)) * 100, 1) if self.products else 0.0,
            "scarcity_samples": scarcity_samples,
            "freshness_count": freshness_count,
            "freshness_pct": round((freshness_count / len(self.products)) * 100, 1) if self.products else 0.0,
            "freshness_samples": freshness_samples,
        }

    def _generate_deterministic_insights(self) -> List[Dict[str, Any]]:
        data = self._analyze_data()
        if "error" in data:
            return self._generate_fallback_insights()

        insights: List[Dict[str, Any]] = []
        timestamp = datetime.now(timezone.utc).isoformat()
        comp_id = self.competitor.get('id')

        # 1. Executive Summary
        exec_summary = (
            f"{data['competitor_name']} operates with {data['products_with_pricing']} products averaging ${data['avg_price']}, "
            f"heavily skewed toward the mid-tier ({data['mid_pct']}%). "
            f"The top category, '{data['top_cat']}', accounts for {data['top_cat_pct']}% of the catalog, "
            f"and an HHI of {data['hhi_score']} signals {data['hhi_interp']} concentration. "
            f"Price discipline is {data['cov_interp']} (CoV: {data['cov']})."
        )
        if data['price_delta']:
            direction = "risen" if data['price_delta']['pct_change'] > 0 else "fallen"
            exec_summary += f" Notably, average prices have {direction} {abs(data['price_delta']['pct_change'])}% since the last scan."

        insights.append({
            "competitor_id": comp_id, "type": "executive_summary", "title": "Market Overview",
            "summary": exec_summary,
            "ai_recommendation": "Review the strategic insights below for actionable, data-backed counter-moves.",
            "severity": "medium", "created_at": timestamp
        })

        # 2. Price Gap Exploitation - now names the actual bracketing products
        if data['largest_gap_size'] > 0:
            target_price = round((data['largest_gap_from'] + data['largest_gap_to']) / 2, 2)
            lower_title = self._title_near_price(data['largest_gap_from'])
            upper_title = self._title_near_price(data['largest_gap_to'])
            insights.append({
                "competitor_id": comp_id, "type": "product_gap", "title": "Critical Price Gap Identified",
                "summary": (
                    f"A significant whitespace exists between ${data['largest_gap_from']} ('{lower_title}') and "
                    f"${data['largest_gap_to']} ('{upper_title}') - a gap of ${data['largest_gap_size']} "
                    f"({data['largest_gap_ratio']}x the average price of ${data['avg_price']}). The competitor has "
                    "zero products in this range, leaving an unmonetized segment of buyers who want more than "
                    f"'{lower_title}' but aren't ready to pay for '{upper_title}'."
                ),
                "ai_recommendation": (
                    f"Launch a flagship product priced precisely at ${target_price}, positioned directly between "
                    f"'{lower_title}' and '{upper_title}'. Target a 30-day uptake of 500+ units. This tactical entry "
                    "captures unmet mid-premium demand and forces a pricing recalibration from the competitor."
                ),
                "severity": "high", "created_at": timestamp
            })

        # 3. Category Concentration Risk - names a real anchor product
        cat_sample_text = self._format_sample_titles(data['top_cat_samples'])
        cat_phrase = f", such as '{data['top_cat_samples'][0]}'" if data['top_cat_samples'] else ""
        insights.append({
            "competitor_id": comp_id, "type": "category_dominance", "title": "Category Concentration Risk",
            "summary": (
                f"The catalog is {data['hhi_interp']} (HHI Index: {data['hhi_score']}). The top category "
                f"'{data['top_cat']}'{cat_phrase} represents {data['top_cat_pct']}% of products, with only "
                f"{data['top_cat_count']} items. This heavy reliance exposes the brand to category-specific demand "
                "shocks and limits cross-sell opportunities."
            ),
            "ai_recommendation": (
                "Diversify into adjacent, high-margin categories (e.g., accessories or premium variants) to dilute "
                "the HHI index below 2000. Introduce bundled kits built around"
                + (f" '{data['top_cat_samples'][0]}'" if data['top_cat_samples'] else f" the {data['top_cat']} line")
                + " to increase Average Order Value (AOV) and create new revenue streams."
            ),
            "severity": "medium", "created_at": timestamp
        })

        # 4. Promotional Behavior Signal
        insights.append({
            "competitor_id": comp_id, "type": "competitive_threat", "title": "Promotional Intensity Analysis",
            "summary": (
                f"Promotional intensity is at {data['promo_pct']}%, with {data['budget_promo_count']} promos in the "
                f"budget segment and {data['premium_promo_count']} in the premium segment. This lack of aggressive "
                "discounting indicates strong pricing confidence, but leaves them vulnerable to tactical, "
                "time-bound promotions."
            ),
            "ai_recommendation": (
                "Deploy a targeted 15% off flash campaign on mid-tier staples to stimulate demand and capture "
                "price-sensitive shoppers who are currently bypassing the competitor's rigid pricing structure."
            ),
            "severity": "medium", "created_at": timestamp
        })

        # 5. Pricing Discipline
        insights.append({
            "competitor_id": comp_id, "type": "pricing_warfare", "title": "Pricing Discipline Assessment",
            "summary": (
                f"The Price Coefficient of Variation (CoV) is {data['cov']}, indicating {data['cov_interp']} pricing. "
                f"The price spread ranges from ${data['min_price']} to ${data['max_price']}. Frequent price "
                "adjustments or wide variances at this level can erode brand trust and confuse customers navigating "
                "the price ladder."
            ),
            "ai_recommendation": (
                "Implement a strict, tiered pricing architecture with a maximum 5-10% variance band per segment. "
                "Introduce a price-match guarantee for mid-tier products to reinforce consumer confidence and build "
                "a defensible pricing moat."
            ),
            "severity": "high", "created_at": timestamp
        })

        # 6. Historical Delta
        if data['price_delta']:
            direction = "risen" if data['price_delta']['pct_change'] > 0 else "fallen"
            insights.append({
                "competitor_id": comp_id, "type": "market_timing", "title": "Historical Price Shift Detected",
                "summary": (
                    f"Since the last scan, the competitor's average price has {direction} by "
                    f"{abs(data['price_delta']['pct_change'])}% (from ${data['price_delta']['prior_avg']} to "
                    f"${data['price_delta']['latest_avg']}). This indicates a strategic shift in their margin "
                    "targets or cost structure."
                ),
                "ai_recommendation": (
                    "Capitalize on this shift immediately. If prices rose, position your alternatives as the "
                    "'smart value' choice. If prices fell, emphasize your superior quality and brand equity to "
                    "avoid a race to the bottom."
                ),
                "severity": "high", "created_at": timestamp
            })

        # 7. Sales Velocity & Scarcity - names actual flagged products
        if data['velocity_pct'] > 0 or data['scarcity_pct'] > 0:
            vel_phrase = f", including {self._format_sample_titles(data['velocity_samples'])}" if data['velocity_samples'] else ""
            anchor = data['velocity_samples'][0] if data['velocity_samples'] else (data['top_cat_samples'][0] if data['top_cat_samples'] else data['top_cat'])
            insights.append({
                "competitor_id": comp_id, "type": "competitive_threat", "title": "Sales Velocity & Scarcity Signals",
                "summary": (
                    f"Deep text analysis reveals {data['velocity_pct']}% of products carry 'bestseller' or "
                    f"'popular' tags{vel_phrase}, while {data['scarcity_pct']}% show scarcity signals ('low stock', "
                    "'final sale'). This indicates high inventory turnover and strong demand in specific segments, "
                    "acting as a 'cash cow' for the competitor."
                ),
                "ai_recommendation": (
                    f"Do not engage in direct price wars on items like '{anchor}'. Instead, launch a complementary "
                    "cross-sell product or a premium alternative at a 15-20% higher price point, targeting the same "
                    "high-intent audience with superior value or bundling."
                ),
                "severity": "high", "created_at": timestamp
            })

        # 8. Assortment Freshness - names actual new-in products
        if data['freshness_pct'] > 0:
            fresh_phrase = f", such as {self._format_sample_titles(data['freshness_samples'])}" if data['freshness_samples'] else ""
            insights.append({
                "competitor_id": comp_id, "type": "market_timing", "title": "Assortment Freshness & Rapid Drops",
                "summary": (
                    f"The competitor is actively pushing new inventory, with {data['freshness_pct']}% of the catalog "
                    f"tagged as 'New In' or 'Just Dropped'{fresh_phrase}. This rapid product turnover strategy aims "
                    "to create urgency and capture trend-driven buyers."
                ),
                "ai_recommendation": (
                    "Counter this rapid-drop strategy not by matching their speed, but by establishing an "
                    "'evergreen' staple product with superior quality and a lifetime guarantee. Position your brand "
                    "as the reliable, long-term investment versus their fast-fashion approach."
                ),
                "severity": "medium", "created_at": timestamp
            })

        # 9. Pro-only extras
        if self.tier in ('pro', 'pro_plus', 'enterprise'):
            target_margin_price = round(data['avg_price'] * 1.2, 2)
            anchor_line = data['top_cat_samples'][0] if data['top_cat_samples'] else f"the {data['top_cat']} line"
            insights.append({
                "competitor_id": comp_id, "type": "financial_blueprint", "title": "Financial Execution Blueprint",
                "summary": "Detailed rollout plan for the identified price gap and category expansion.",
                "ai_recommendation": (
                    f"Product: A premium alternative to '{anchor_line}'. Target Price: ${target_margin_price}. "
                    "Target Gross Margin: 45%. Initial Production Run: 1,000 units. Days-to-execute: 30. "
                    f"Success KPI: Achieve 15% market share of the identified gap segment within 60 days, "
                    f"generating ~${round(target_margin_price * 1000, 2):,.2f} in revenue."
                ),
                "severity": "critical", "created_at": timestamp
            })
            insights.append({
                "competitor_id": comp_id, "type": "quick_wins", "title": "Quick Wins (Execute in 7 Days)",
                "summary": (
                    "- Launch a 15% off flash sale on mid-tier staples.\n"
                    "- Introduce a bundled accessory to increase AOV by 10%.\n"
                    f"- Deploy targeted ads highlighting the competitor's ${data['largest_gap_size']} price gap.\n"
                    "- Audit top 3 SKUs for bundling opportunities."
                ),
                "ai_recommendation": "Assign these to your growth team immediately for rapid execution and track conversion lift daily.",
                "severity": "high", "created_at": timestamp
            })
            insights.append({
                "competitor_id": comp_id, "type": "strategic_timeline", "title": "Strategic Timeline (30-60-90 Day)",
                "summary": (
                    "30 Days: Launch gap-filling product and achieve 500+ unit uptake.\n"
                    "60 Days: Diversify top category with 3 new accessory SKUs.\n"
                    "90 Days: Achieve 15% market share in the targeted whitespace segment."
                ),
                "ai_recommendation": "Assign a dedicated owner and a check-in date to each milestone above to ensure accountability.",
                "severity": "medium", "created_at": timestamp
            })

        self.logger.info(f"[ENGINE] Generated {len(insights)} deterministic insights for tier: {self.tier}")
        return insights

    def _generate_fallback_insights(self) -> List[Dict[str, Any]]:
        timestamp = datetime.now(timezone.utc).isoformat()
        comp_id = self.competitor.get('id')
        return [{
            "competitor_id": comp_id, "type": "executive_summary", "title": "Data Insufficient",
            "summary": f"Scanned {len(self.products)} products, but no valid pricing data was detected to perform mathematical analysis.",
            "ai_recommendation": "Ensure the scraper is correctly extracting 'current_price' fields from product pages.",
            "severity": "medium", "created_at": timestamp
        }]

# ===================================================================
# Scraper Engine
# ===================================================================
class ScraperEngine:
    def __init__(self) -> None:
        self.scrapers = {'shopify': scrape_shopify, 'woocommerce': scrape_woocommerce, 'generic': scrape_generic}
        self.logger = logging.getLogger('ScraperEngine')

    def scrape(self, url: str, platform: Optional[str] = None, max_retries: int = 3,
               max_products: int = 9999) -> Tuple[List[Dict[str, Any]], Optional[ScraperBlockedError]]:
        """
        Returns (products, blocked_error). blocked_error is non-None only
        when the site actively refused access (403/404/bot-wall) - this is
        distinct from "retries exhausted for an unrelated reason", which
        returns ([], None) and should be treated as a transient failure,
        not a block worth notifying the client about specifically.
        """
        if not platform:
            platform = detect_platform(url)
        scraper_func = self.scrapers.get(platform, scrape_generic)

        for attempt in range(max_retries):
            try:
                self.logger.info(f"[SCRAPE] Using {platform} scraper (attempt {attempt + 1}/{max_retries})...")
                products = asyncio.run(scraper_func(url)) if inspect.iscoroutinefunction(scraper_func) else scraper_func(url)

                if products and len(products) > 0:
                    if len(products) > max_products:
                        products = products[:max_products]
                        self.logger.info(f"[SKIP] Trimmed to {max_products} products (tier limit)")
                    print_success(f"Successfully scraped {len(products)} products")
                    return products, None

                # Empty result with no exception - not necessarily a block,
                # could be a genuinely empty or unparseable catalog. Retry.
                self.logger.warning(f"[EMPTY] {platform} scraper returned 0 products on attempt {attempt + 1}")

            except ScraperBlockedError as be:
                # Bot protection won't clear in the next few seconds - fail fast, no retry.
                self.logger.warning(f"[BLOCKED] {platform} scraper blocked for {url}: {be.reason}")
                return [], be

            except requests.exceptions.HTTPError as he:
                status = he.response.status_code if he.response is not None else None
                if status in (403, 404):
                    reason = detect_block_signal(status, getattr(he.response, "text", "")) or f"HTTP {status}"
                    self.logger.warning(f"[BLOCKED] HTTP {status} for {url}: {reason}")
                    return [], ScraperBlockedError(status, reason)
                self.logger.error(f"Scraper HTTP error (attempt {attempt + 1}): {he}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)

            except Exception as e:
                self.logger.error(f"Scraper failed (attempt {attempt + 1}) for {url}: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)

        self.logger.error(f"Failed to scrape {url} after {max_retries} attempts (no block detected - likely transient)")
        return [], None

    def clean_product_data(self, product: Dict[str, Any], competitor_id: str, timestamp: str) -> Dict[str, Any]:
        return {
            "competitor_id": competitor_id,
            "title": str(product.get("title", "Unknown Product"))[:255],
            "product_url": str(product.get("product_url", ""))[:500],
            "current_price": float(product.get("current_price", 0.0) or 0.0),
            "image_url": str(product.get("image_url", ""))[:500],
            "last_updated_at": timestamp,
        }

# ===================================================================
# Run-level observability
# ===================================================================
class ScanResult(str, Enum):
    SUCCESS = "success"
    BLOCKED = "blocked"
    NO_PRODUCTS = "no_products"
    FAILED = "failed"

@dataclass
class RunStats:
    scanned: int = 0
    succeeded: int = 0
    blocked: int = 0
    no_products: int = 0
    skipped: int = 0
    failed: int = 0
    start_time: float = field(default_factory=time.perf_counter)

    def record(self, result: ScanResult) -> None:
        if result == ScanResult.SUCCESS:
            self.succeeded += 1
        elif result == ScanResult.BLOCKED:
            self.blocked += 1
        elif result == ScanResult.NO_PRODUCTS:
            self.no_products += 1
        else:
            self.failed += 1

    def summary(self) -> str:
        elapsed = time.perf_counter() - self.start_time
        return (
            f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}\n"
            f"{Colors.BOLD}RUN SUMMARY{Colors.ENDC}\n"
            f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n"
            f"  Competitors found      : {self.scanned}\n"
            f"  {Colors.OKGREEN}Succeeded              : {self.succeeded}{Colors.ENDC}\n"
            f"  {Colors.WARNING}Blocked (403/bot-wall) : {self.blocked}{Colors.ENDC}\n"
            f"  No products returned   : {self.no_products}\n"
            f"  Skipped (no URL)       : {self.skipped}\n"
            f"  {Colors.FAIL}Failed (other errors)  : {self.failed}{Colors.ENDC}\n"
            f"  Elapsed time           : {elapsed:.1f}s\n"
            f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n"
        )

# ===================================================================
# Main Application
# ===================================================================
class VeloraScraper:
    def __init__(self) -> None:
        self.config = Config()
        self.supabase: Optional[Client] = None
        self.db: Optional[DatabaseManager] = None
        self.scraper: Optional[ScraperEngine] = None
        self.logger = logging.getLogger('VeloraScraper')

    def initialize(self) -> bool:
        print_banner()
        if not self.config.validate():
            return False
        try:
            self.supabase = create_client(self.config.supabase_url, self.config.supabase_key)
            self.db = DatabaseManager(self.supabase)
            self.scraper = ScraperEngine()
            print_success("Connected to Supabase")
            return True
        except Exception as e:
            print_error(f"Failed to connect to Supabase: {e}")
            return False

    def display_intelligence_brief(self, brief: Dict[str, Any], insights: List[Dict[str, Any]]) -> None:
        print_header("MARKET INTELLIGENCE BRIEFING")
        print(f"{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
        print(f"{Colors.BOLD}Target Competitor:{Colors.ENDC} {brief.get('competitor_name')}")
        print(f"{Colors.BOLD}Tier:{Colors.ENDC} {str(brief.get('tier_context', 'free')).upper()}")
        print(f"{Colors.BOLD}Products Analyzed:{Colors.ENDC} {brief.get('products_with_pricing')} / {brief.get('total_products_scanned')}")
        if brief.get('price_delta'):
            d = brief['price_delta']
            print(f"{Colors.BOLD}Price Delta vs Last Scan:{Colors.ENDC} {d['pct_change']}% (${d['prior_avg']} -> ${d['latest_avg']})")
        print()

        exec_insight = next((i for i in insights if i.get('type') == 'executive_summary'), None)
        if exec_insight:
            print(f"{Colors.BOLD}EXECUTIVE SUMMARY:{Colors.ENDC}\n  {exec_insight.get('summary')}\n")

        strategic_types = {
            "pricing_warfare", "product_gap", "competitive_threat", "counter_move", "market_timing",
            "brand_positioning", "customer_psychology", "supply_chain_signal", "category_dominance",
            "financial_blueprint", "strategic_timeline", "quick_wins", "risk_assessment"
        }

        print_header("STRATEGIC INSIGHTS")
        for i, insight in enumerate(insights, 1):
            if insight.get('type') not in strategic_types:
                continue
            severity = str(insight.get('severity', 'medium')).upper()
            severity_color = Colors.WARNING if severity in ('CRITICAL', 'HIGH') else Colors.OKGREEN
            print(f"\n{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
            print(f"{Colors.BOLD}INSIGHT #{i} [{str(insight.get('type', 'GENERAL')).upper()}] - Severity: {severity_color}{severity}{Colors.ENDC}")
            print(f"{Colors.BOLD}Title:{Colors.ENDC} {insight.get('title')}")
            print(f"\n{Colors.OKBLUE}Situation Summary:{Colors.ENDC}\n  {insight.get('summary')}")
            print(f"\n{Colors.OKGREEN}Strategic Counter-Move:{Colors.ENDC}\n  {insight.get('ai_recommendation')}")
        print(f"\n{Colors.OKGREEN}{'='*80}{Colors.ENDC}\n")

    def scan_competitor(self, competitor: Dict[str, Any], url: str) -> ScanResult:
        competitor_name = competitor.get('name', 'Unknown')
        competitor_id = competitor.get('id')
        tier = competitor.get('_tier', 'free')
        limits = competitor.get('_limits', TIER_LIMITS['free'])

        print(f"\n{'='*80}\n[TARGET] Target Acquired: {competitor_name}\n[URL] {url}\n[TIER] {tier.upper()} (max {limits['max_products']} products)\n{'='*80}\n")

        try:
            products, blocked_error = self.scraper.scrape(url, max_products=limits['max_products'])

            if blocked_error:
                print_warning(f"[BLOCKED] {competitor_name}: {blocked_error.reason}")
                self.db.save_blocked_insight(competitor_id, competitor_name, blocked_error.status_code, blocked_error.reason)
                # Respect the normal scan interval for a known block - retrying
                # every GitHub Actions run against an active bot-wall is pointless.
                self.db.update_competitor_scan_time(competitor_id)
                return ScanResult.BLOCKED

            if not products:
                print_warning(f"No products found for {competitor_name} (not a detected block - will retry sooner)")
                return ScanResult.NO_PRODUCTS

            timestamp = datetime.now(timezone.utc).isoformat()
            cleaned_products = [self.scraper.clean_product_data(p, competitor_id, timestamp) for p in products]

            if self.db.upsert_products(cleaned_products) == 0:
                print_error(f"Failed to save any products for {competitor_name}")
                return ScanResult.FAILED

            has_history = self.db.has_previous_price_history(competitor_id)
            self.db.save_price_history(cleaned_products, competitor_id)

            if has_history:
                try:
                    self.supabase.table("ai_insights").delete().eq("competitor_id", competitor_id).eq("type", "trend").execute()
                except Exception as e:
                    self.logger.warning(f"Could not clear prior trend insights for {competitor_id}: {e}")
                try:
                    print(f"\n[TREND] Analyzing price trends for {competitor_name}...")
                    trend_analyzer = TrendAnalyzer(competitor_id, products)
                    trend_data = trend_analyzer.analyze_price_trends()
                    if "error" not in trend_data and trend_data.get("insights"):
                        moving = [i for i in trend_data["insights"] if "stable" not in str(i.get("title", "")).lower()]
                        if moving:
                            self.db.save_trend_insights(moving)
                            print_success(f"Saved {len(moving)} real price-movement trends")
                        else:
                            print_info("[SKIP] No real price movements detected - skipping trend cards")
                except Exception as e:
                    self.logger.error(f"Trend analysis failed for {competitor_name}: {e}")
            else:
                print_info("[SKIP] First scan - skipping trend analysis (no price history yet)")

            intel_engine = DeterministicMarketIntelligenceEngine(competitor, products, db=self.db)
            insights = intel_engine.generate_all_insights()

            brief = intel_engine._analyze_data()
            if "error" not in brief and insights:
                self.display_intelligence_brief(brief, insights)

            if insights:
                self.db.save_insights(insights, competitor_id)
                print_success(f"Saved {len(insights)} strategic insights to database")

            self.db.update_competitor_scan_time(competitor_id)
            print_success(f"[DONE] Mission Complete: {competitor_name}")
            print(f"   - Products Mapped: {len(cleaned_products)}\n   - Insights Generated: {len(insights)}")
            return ScanResult.SUCCESS

        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception(f"Unhandled exception scanning {competitor_name} ({url}):")
            return ScanResult.FAILED

    def run_dynamic_mode(self, force_all: bool = False) -> RunStats:
        stats = RunStats()
        print_info("Running in TIER-AWARE DYNAMIC MODE")
        pending = self.db.get_pending_competitors(force_all=force_all)
        stats.scanned = len(pending)

        if not pending:
            print_success("[DONE] All competitors are up to date!")
            print_info("   Next auto-update according to tier schedules")
            print(stats.summary())
            return stats

        print_info(f"Found {len(pending)} competitor(s) to scan\n")
        for i, comp in enumerate(pending, 1):
            print(f"\n[{i}/{len(pending)}]")
            url = comp.get('website') or comp.get('shopify_store')
            if not url:
                self.logger.warning(f"Competitor {comp.get('name')} has no URL - skipping")
                stats.skipped += 1
                continue
            result = self.scan_competitor(comp, url)
            stats.record(result)
            if i < len(pending):
                time.sleep(5)  # gentle throttle between targets

        print(stats.summary())
        return stats

    def run(self, url: Optional[str] = None, continuous: bool = False, force_all: bool = False) -> None:
        if not self.initialize():
            sys.exit(1)

        if continuous:
            print_info(f"[WAIT] Continuous mode: checking every {self.config.scan_interval}s")
            try:
                while True:
                    self.run_dynamic_mode(force_all=True)
                    time.sleep(self.config.scan_interval)
            except KeyboardInterrupt:
                print_info("\n[STOP] Continuous mode stopped by user")
        elif url:
            comp = self.db.get_or_create_competitor(url)
            if comp:
                result = self.scan_competitor(comp, url)
                print_info(f"Result: {result.value.upper()}")
        elif force_all:
            self.run_dynamic_mode(force_all=True)
        else:
            self.run_dynamic_mode(force_all=False)

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Velora v4.2.0 - Enterprise-Hardened Deterministic Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('url', nargs='?', help='Store URL to scan (optional)')
    parser.add_argument('--continuous', '-c', action='store_true', help='Run continuously')
    parser.add_argument('--force-all', '-f', action='store_true', help='Force scan all competitors')
    args = parser.parse_args()

    scraper = VeloraScraper()
    scraper.run(url=args.url, continuous=args.continuous, force_all=args.force_all)

if __name__ == "__main__":
    main()
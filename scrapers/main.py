"""
 Velora — Advanced Competitive Market Intelligence Engine
═══════════════════════════════════════════════════════════════
PRODUCTION VERSION v3.0 — "Executive Edition"

☁️ Cloud-Powered (Hugging Face Router — Multi-Provider Chain)
🏆 Tier-Aware Scanning (Free / Pro / Pro Plus / Enterprise)
🧠 Deep Strategic Analysis (8 insights + Executive Summary + Scorecard)
📈 Price History Tracking (for trend comparison)

Architecture:
  [GitHub Actions] → [Scraper] → [AI Analysis] → [Supabase] → [Flutter App]
"""

import os, sys, time, json, logging, argparse, re, inspect, asyncio, requests, statistics
from pathlib import Path
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse
from typing import List, Dict, Optional, Any, Tuple
from functools import wraps
from collections import Counter

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

# ═══════════════════════════════════════════════════════════
# 🏆 TIER SYSTEM — حدود كل خطة اشتراك
# ═══════════════════════════════════════════════════════════
TIER_LIMITS = {
    'free':       {'max_competitors': 3,    'scan_interval_hours': 24, 'max_products': 300,  'ai_depth': 'standard'},
    'pro':        {'max_competitors': 10,   'scan_interval_hours': 6,  'max_products': 1000, 'ai_depth': 'advanced'},
    'pro_plus':   {'max_competitors': 25,   'scan_interval_hours': 3,  'max_products': 2500, 'ai_depth': 'executive'},
    'enterprise': {'max_competitors': 9999, 'scan_interval_hours': 1,  'max_products': 9999, 'ai_depth': 'executive'},
}

# ═══════════════════════════════════════════════════════════
# 🛡️ Rate Limiting (Protects API Limits)
# ═════════════════════════════════════════════════════════
def rate_limit(calls_per_minute: int = 10):
    def decorator(func):
        last_called = [0]
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

# ═══════════════════════════════════════════════════════════
# 📝 Logging Configuration
# ═════════════════════════════════════════════════════════
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

# ═══════════════════════════════════════════════════════════
# 🎨 Color Codes (Terminal Output)
# ══════════════════════════════════════════════════════════
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_banner():
    print(f"\n{Colors.HEADER}{'═'*80}{Colors.ENDC}")
    print(f"{Colors.OKBLUE} Velora v3.0 — Executive Market Intelligence Engine{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Cloud-Powered (Multi-Provider) • Tier-Aware • Deep Analysis{Colors.ENDC}")
    print(f"{Colors.HEADER}{'═'*80}{Colors.ENDC}\n")

def print_success(msg): print(f"{Colors.OKGREEN}✅ {msg}{Colors.ENDC}")
def print_error(msg): print(f"{Colors.FAIL}❌ {msg}{Colors.ENDC}")
def print_warning(msg): print(f"{Colors.WARNING}⚠️  {msg}{Colors.ENDC}")
def print_info(msg): print(f"{Colors.OKBLUE}ℹ️  {msg}{Colors.ENDC}")
def print_header(msg): print(f"\n{Colors.BOLD}{Colors.OKCYAN}{msg}{Colors.ENDC}")

# ═══════════════════════════════════════════════════════════
# 🔧 Configuration
# ══════════════════════════════════════════════════════════
class Config:
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        self.hf_api_key = os.getenv("HF_API_KEY")
        self.scan_interval = int(os.getenv("SCAN_INTERVAL", "86400"))
        self.max_retries = int(os.getenv("MAX_RETRIES", "3"))
        
    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials in .env")
            return False
        if not self.hf_api_key:
            print_error("Missing HF_API_KEY in .env")
            return False
        print_info("☁️ Using Hugging Face Router (Multi-Provider Chain)")
        return True

# ═══════════════════════════════════════════════════════════
# 🗄️ Database Manager (Tier-Aware)
# ══════════════════════════════════════════════════════════
class DatabaseManager:
    def __init__(self, supabase: Client):
        self.supabase = supabase
        self.logger = logging.getLogger('DatabaseManager')
    
    def get_pending_competitors(self, force_all: bool = False) -> List[Dict[str, Any]]:
        """
        يجلب المنافسين المستحقين للمسح مع مراعاة:
        1. خطة كل مستخدم (tier) — عدد المنافسين المسموح
        2. جدولة المسح حسب الخطة (free=24h, pro=6h, ...)
        """
        try:
            response = (
                self.supabase.table("competitors")
                .select("id, name, website, shopify_store, user_id, last_scan_at")
                .order("last_scan_at", desc=True, nullsfirst=True)
                .limit(500)
                .execute()
            )
            rows = response.data or []
            if not rows:
                self.logger.info("Found 0 competitor(s) to scan")
                return []

            # جلب خطة كل مالك دفعة واحدة (كفاءة)
            user_ids = list({r.get('user_id') for r in rows if r.get('user_id')})
            tiers = {}
            if user_ids:
                ures = self.supabase.table("users").select("id, tier").in_("id", user_ids).execute()
                tiers = {u['id']: (u.get('tier') or 'free') for u in (ures.data or [])}

            now = datetime.now(timezone.utc)
            pending = []
            per_user = {}

            for row in rows:
                uid = row.get('user_id')
                tier = tiers.get(uid, 'free')
                limits = TIER_LIMITS.get(tier, TIER_LIMITS['free'])

                # حدّ عدد المنافسين لكل خطة
                per_user[uid] = per_user.get(uid, 0) + 1
                if per_user[uid] > limits['max_competitors']:
                    self.logger.info(f"⏭️ Skip {row.get('name')}: tier '{tier}' cap reached")
                    continue

                # جدولة المسح حسب الخطة
                if not force_all:
                    last = row.get('last_scan_at')
                    if last:
                        last_dt = datetime.fromisoformat(last.replace('Z', '+00:00'))
                        if last_dt.tzinfo is None:
                            last_dt = last_dt.replace(tzinfo=timezone.utc)
                        if now - last_dt < timedelta(hours=limits['scan_interval_hours']):
                            continue  # لم يحن دور هذه الخطة بعد

                # إرفاق الـ tier مع المنافس للاستخدام لاحقاً
                row['_tier'] = tier
                row['_limits'] = limits
                pending.append(row)

            self.logger.info(f"Found {len(pending)} competitor(s) to scan (tier-aware)")
            return pending
        except Exception as e:
            self.logger.error(f"Failed to fetch competitors: {e}")
            return []
    
    def get_or_create_competitor(self, url: str) -> Optional[Dict[str, Any]]:
        try:
            for check_url in [url, url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")]:
                response = self.supabase.table("competitors").select("id, name, website, user_id").eq("website", check_url).execute()
                if response.data: return response.data[0]
            
            store_name = urlparse(url).netloc.replace('www.', '').split('.')[0].capitalize()
            users = self.supabase.table("users").select("id").limit(1).execute()
            if not users.data: print_error("No users found."); return None
            
            response = self.supabase.table("competitors").insert({
                'name': store_name, 'website': url, 'user_id': users.data[0]['id'],
                'created_at': datetime.now(timezone.utc).isoformat()
            }).execute()
            if response.data: print_success(f"Created competitor: {store_name}")
            return response.data[0] if response.data else None
        except Exception as e:
            self.logger.error(f"Failed to create competitor: {e}")
            return None
    
    def upsert_products(self, products: List[Dict[str, Any]]) -> int:
        try:
            response = self.supabase.table("products").upsert(products, on_conflict="competitor_id,product_url").execute()
            count = len(response.data) if response.data else len(products)
            self.logger.info(f"Upserted {count} products")
            return count
        except Exception as e:
            self.logger.error(f"Failed to upsert products: {e}")
            return 0
    
    def save_price_history(self, products: List[Dict[str, Any]], competitor_id: str) -> int:
        """يحفظ الأسعار في جدول price_history للتحليل المستقبلي (ميزة Pro Plus)"""
        try:
            now = datetime.now(timezone.utc).isoformat()
            history_rows = []
            for p in products:
                price = p.get("current_price")
                if price and price > 0:
                    history_rows.append({
                        "competitor_id": competitor_id,
                        "product_url": str(p.get("product_url", ""))[:500],
                        "product_title": str(p.get("title", ""))[:200],
                        "price": float(price),
                        "recorded_at": now
                    })
            
            if not history_rows:
                return 0
            
            # محاولة الإدراج — إذا لم يكن الجدول موجوداً، نخطئ بصمت
            try:
                self.supabase.table("price_history").insert(history_rows).execute()
                self.logger.info(f"Saved {len(history_rows)} price history records")
                return len(history_rows)
            except Exception as e:
                self.logger.warning(f"price_history table may not exist yet: {e}")
                return 0
        except Exception as e:
            self.logger.error(f"Failed to save price history: {e}")
            return 0
    
    def get_previous_scan_data(self, competitor_id: str) -> Optional[Dict[str, Any]]:
        """يجلب بيانات المسح السابق للمقارنة (ميزة Pro)"""
        try:
            # جلب آخر insight سابق
            response = (
                self.supabase.table("ai_insights")
                .select("*")
                .eq("competitor_id", competitor_id)
                .order("created_at", desc=True)
                .limit(8)
                .execute()
            )
            if not response.data:
                return None
            return {"previous_insights": response.data}
        except Exception as e:
            self.logger.warning(f"Could not fetch previous scan: {e}")
            return None
    
    def save_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
            # حذف الـ insights القديمة لنفس المنافس قبل الإدراج (تجديد)
            if insights:
                comp_id = insights[0].get('competitor_id')
                if comp_id:
                    try:
                        self.supabase.table("ai_insights").delete().eq("competitor_id", comp_id).eq("type", "trend").execute()
                    except: pass
            
            self.supabase.table("ai_insights").insert(insights).execute()
            self.logger.info(f"Saved {len(insights)} AI insights")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save insights: {e}")
            return False

    def save_trend_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
            formatted_insights = []
            for insight in insights:
                formatted_insights.append({
                    "competitor_id": insight.get("competitor_id"),
                    "type": "trend",
                    "title": insight.get("title", "Trend Analysis"),
                    "summary": insight.get("summary", ""),
                    "ai_recommendation": insight.get("recommendation", ""),
                    "severity": insight.get("severity", "medium").lower(),
                    "created_at": datetime.now(timezone.utc).isoformat()
                })
            if formatted_insights:
                self.supabase.table("ai_insights").insert(formatted_insights).execute()
                self.logger.info(f"Saved {len(formatted_insights)} trend insights")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save trend insights: {e}")
            return False
    
    def update_competitor_scan_time(self, competitor_id: str) -> bool:
        try:
            self.supabase.table("competitors").update({
                "last_scan_at": datetime.now(timezone.utc).isoformat()
            }).eq("id", competitor_id).execute()
            self.logger.info("Updated scan timestamp")
            return True
        except Exception as e:
            self.logger.error(f"Failed to update timestamp: {e}")
            return False

# ═══════════════════════════════════════════════════════════
# 🧠 ELITE MARKET INTELLIGENCE ENGINE (v3.0 — Executive)
# ═══════════════════════════════════════════════════════════
class MarketIntelligenceEngine:
    """
    محرك الذكاء الاستراتيجى — سلسلة مزودين + تحليل عميق.
    
    التحسينات في v3.0:
    - 8 رؤى استراتيجية (بدل 6)
    - Executive Summary (ملخص تنفيذي)
    - Quick Wins (3 إجراءات سريعة)
    - Competitive Scorecard (تقييم المنافس من 10)
    - تحليل التنوع (Shannon Index)
    - كشف الكلمات المفتاحية والعروض
    - مقارنة مع المسح السابق
    """
    
    PROVIDERS = [
        {
            "name": "Llama-3.3-70B",
            "model": "meta-llama/Llama-3.3-70B-Instruct",
            "url": "https://router.huggingface.co/v1/chat/completions",
        },
        {
            "name": "Qwen-2.5-72B",
            "model": "Qwen/Qwen2.5-72B-Instruct",
            "url": "https://router.huggingface.co/v1/chat/completions",
        },
        {
            "name": "Mixtral-8x7B",
            "model": "mistralai/Mixtral-8x7B-Instruct-v0.1",
            "url": "https://router.huggingface.co/v1/chat/completions",
        },
    ]

    # الكلمات المفتاحية للكشف عن الفئات والعروض
    CATEGORY_KEYWORDS = [
        "shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock", 
        "accessory", "sweater", "hoodie", "short", "skirt", "coat", "boot",
        "sandal", "sneaker", "scarf", "belt", "watch", "jewelry"
    ]
    
    PROMOTION_KEYWORDS = ["sale", "off", "discount", "limited", "new", "bestseller", "clearance"]

    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]], 
                 previous_scan: Optional[Dict[str, Any]] = None):
        self.competitor = competitor
        self.products = products
        self.previous_scan = previous_scan
        self.name = competitor.get('name', 'Unknown')
        self.tier = competitor.get('_tier', 'free')
        self.limits = competitor.get('_limits', TIER_LIMITS['free'])
        self.logger = logging.getLogger('MarketIntelligence')
        self.hf_api_key = os.getenv("HF_API_KEY")

    def generate_all_insights(self) -> List[Dict[str, Any]]:
        return self._generate_advanced_insights()

    def _analyze_competitor_data(self) -> Dict[str, Any]:
        """تحليل كمي شامل للبيانات — يُرسل كسياق للـ AI"""
        prices = [p.get("current_price", 0) for p in self.products if p.get("current_price") and p.get("current_price") > 0]
        
        if not prices:
            return {"error": "No pricing data available"}
        
        # إحصائيات الأسعار الأساسية
        avg_price = sum(prices) / len(prices)
        median_price = statistics.median(prices)
        try:
            stdev_price = statistics.stdev(prices) if len(prices) > 1 else 0
        except:
            stdev_price = 0
        
        budget_threshold = avg_price * 0.6
        premium_threshold = avg_price * 1.5
        
        budget_products = [p for p in prices if p < budget_threshold]
        mid_tier = [p for p in prices if budget_threshold <= p <= premium_threshold]
        premium_products = [p for p in prices if p > premium_threshold]
        
        sorted_products = sorted(self.products, key=lambda x: x.get("current_price", 0), reverse=True)
        
        # تحليل الكلمات المفتاحية (الفئات)
        category_counts = Counter()
        promotion_count = 0
        
        for p in self.products:
            title = str(p.get("title", "")).lower()
            for kw in self.CATEGORY_KEYWORDS:
                if kw in title:
                    category_counts[kw] += 1
            for promo in self.PROMOTION_KEYWORDS:
                if promo in title:
                    promotion_count += 1
                    break
        
        top_categories = category_counts.most_common(5)
        diversity_score = len(category_counts) / max(len(self.CATEGORY_KEYWORDS), 1) * 100
        
        # كشف الفجوات السعرية (Price Gaps)
        price_gaps = []
        sorted_prices = sorted(prices)
        for i in range(len(sorted_prices) - 1):
            gap = sorted_prices[i+1] - sorted_prices[i]
            if gap > avg_price * 0.3:  # فجوة كبيرة
                price_gaps.append({
                    "from": round(sorted_prices[i], 2),
                    "to": round(sorted_prices[i+1], 2),
                    "size": round(gap, 2)
                })
        
        # مقارنة مع المسح السابق (إن وجد)
        comparison = None
        if self.previous_scan and self.previous_scan.get("previous_insights"):
            comparison = {
                "previous_scan_available": True,
                "previous_insights_count": len(self.previous_scan["previous_insights"])
            }
        
        return {
            "competitor_name": self.name,
            "scan_date": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
            "tier_context": self.tier,
            "total_products_scanned": len(self.products),
            "products_with_pricing": len(prices),
            "pricing_intelligence": {
                "average_price": round(avg_price, 2),
                "median_price": round(median_price, 2),
                "standard_deviation": round(stdev_price, 2),
                "lowest_price": round(min(prices), 2),
                "highest_price": round(max(prices), 2),
                "price_spread": round(max(prices) - min(prices), 2),
                "price_coefficient_of_variation": round(stdev_price / avg_price, 2) if avg_price > 0 else 0
            },
            "market_positioning": {
                "budget_segment": {
                    "count": len(budget_products),
                    "percentage": round(len(budget_products)/len(prices)*100, 1),
                    "threshold": f"Under ${round(budget_threshold, 2)}"
                },
                "mid_tier_segment": {
                    "count": len(mid_tier),
                    "percentage": round(len(mid_tier)/len(prices)*100, 1),
                    "threshold": f"${round(budget_threshold, 2)} - ${round(premium_threshold, 2)}"
                },
                "premium_segment": {
                    "count": len(premium_products),
                    "percentage": round(len(premium_products)/len(prices)*100, 1),
                    "threshold": f"Above ${round(premium_threshold, 2)}"
                }
            },
            "category_intelligence": {
                "top_5_categories": [{"category": k, "count": v} for k, v in top_categories],
                "diversity_score_percent": round(diversity_score, 1),
                "unique_categories_detected": len(category_counts)
            },
            "promotion_signals": {
                "products_with_promo_keywords": promotion_count,
                "promo_percentage": round(promotion_count / len(self.products) * 100, 1) if self.products else 0
            },
            "price_gaps": price_gaps[:5],  # أكبر 5 فجوات
            "strategic_anchors": {
                "top_3_premium": [{"title": p.get("title", "")[:60], "price": round(p.get("current_price", 0), 2)} for p in sorted_products[:3]],
                "top_3_entry": [{"title": p.get("title", "")[:60], "price": round(p.get("current_price", 0), 2)} for p in sorted_products[-3:] if p.get("current_price")]
            },
            "comparison_with_previous_scan": comparison
        }

    def _build_strategic_prompt(self, data: Dict[str, Any]) -> Tuple[str, str]:
        """بناء Prompt احترافي — Executive Edition"""
        
        system_prompt = """You are an Elite E-commerce Market Strategist with 20+ years of experience at McKinsey, BCG, and Bain. You advise Fortune 500 brands on competitive warfare, pricing architecture, category domination, and brand positioning.

## YOUR MISSION
Produce a complete BOARD-READY strategic intelligence package for the CEO. Your output must be so actionable that the executive team can act on it within 48 hours.

## UNCOMPROMISING STANDARDS:
- Output ONLY valid JSON. No markdown, no commentary outside the JSON.
- Every insight MUST cite hard data (exact prices, counts, percentages) from the intelligence report.
- Every 'ai_recommendation' MUST specify:
  * A concrete price point or price range (e.g., "$89-99")
  * An expected gross margin percentage (e.g., "55-65%")
  * A timeline in days/weeks (e.g., "launch in 45 days")
  * An inventory or unit target (e.g., "500 units initial run")
  * A clear KPI for success
- 'severity' MUST be: "critical", "high", "medium", or "low".
- 'score' in scorecard MUST be 1-10 (10 = dominant, 1 = weak).

## REQUIRED OUTPUT STRUCTURE:
{
  "executive_summary": "3 sentences capturing the most critical strategic findings (under 100 words)",
  "competitive_scorecard": {
    "pricing_strategy": {"score": 8, "rationale": "..."},
    "category_depth": {"score": 7, "rationale": "..."},
    "brand_positioning": {"score": 9, "rationale": "..."},
    "market_coverage": {"score": 6, "rationale": "..."}
  },
  "insights": [
    {
      "type": "pricing_warfare|product_gap|competitive_threat|counter_move|market_timing|brand_positioning|customer_psychology|supply_chain_signal",
      "title": "Board-level headline (under 80 chars)",
      "summary": "Data-backed situation analysis (80-150 words)",
      "ai_recommendation": "Specific action plan with numbers (80-150 words)",
      "severity": "critical|high|medium|low"
    }
  ],
  "quick_wins": [
    "Actionable step executable within 7 days (with expected impact)",
    "Actionable step executable within 7 days (with expected impact)",
    "Actionable step executable within 7 days (with expected impact)"
  ],
  "risk_assessment": "2-3 sentences on the biggest risks if we fail to respond"
}"""

        user_prompt = f"""## COMPETITOR INTELLIGENCE REPORT — {data.get('competitor_name')}
Scan Date: {data.get('scan_date')}
Analysis Tier: {data.get('tier_context')}

{json.dumps(data, indent=2, ensure_ascii=False)}

## YOUR DELIVERABLE — 8 STRATEGIC INSIGHTS (one per type):
1. "pricing_warfare" — Price tier architecture, margin pockets, where to surgically undercut.
2. "product_gap" — Missing category, orphan price point, or feature void to exploit.
3. "competitive_threat" — Their strongest moat and a 90-day plan to neutralize it.
4. "counter_move" — Aggressive asymmetric go-to-market action for the next 45 days.
5. "market_timing" — Seasonal/cyclical insight: when to attack, hold, or bundle.
6. "brand_positioning" — Emotional territory they own vs. whitespace to claim.
7. "customer_psychology" — What their pricing/catalog reveals about their target customer.
8. "supply_chain_signal" — What their product distribution hints about their operations.

Return ONLY the JSON object. No preambles, no signatures."""

        return system_prompt, user_prompt

    def _call_ai_provider(self, system_prompt: str, user_prompt: str) -> Optional[str]:
        """يُجرّب المزودين بالترتيب حتى ينجح أحدهم."""
        for i, provider in enumerate(self.PROVIDERS):
            try:
                print(f"\n☁️ [{i+1}/{len(self.PROVIDERS)}] Calling {provider['name']}...")
                
                response = requests.post(
                    provider["url"],
                    headers={
                        "Authorization": f"Bearer {self.hf_api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": provider["model"],
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_prompt}
                        ],
                        "max_tokens": 3500,
                        "temperature": 0.3,
                        "top_p": 0.9,
                    },
                    timeout=150
                )
                
                if response.status_code != 200:
                    self.logger.warning(f"  ↳ {provider['name']} returned {response.status_code}: {response.text[:200]}")
                    continue
                
                data = response.json()
                # OpenAI-compatible format
                if "choices" in data and len(data["choices"]) > 0:
                    text = data["choices"][0].get("message", {}).get("content", "")
                    if text:
                        print_success(f"  ↳ {provider['name']} responded successfully ({len(text)} chars)")
                        return text
                
                # Legacy HF format
                if isinstance(data, list) and len(data) > 0:
                    text = data[0].get("generated_text", "")
                    if text:
                        print_success(f"  ↳ {provider['name']} responded (legacy)")
                        return text
                
                self.logger.warning(f"  ↳ {provider['name']} returned empty/unexpected format")
                continue
                
            except requests.exceptions.ConnectionError as e:
                self.logger.warning(f"  ↳ {provider['name']} connection failed: {str(e)[:100]}")
                continue
            except requests.exceptions.Timeout:
                self.logger.warning(f"  ↳ {provider['name']} timed out")
                continue
            except Exception as e:
                self.logger.warning(f"  ↳ {provider['name']} error: {str(e)[:100]}")
                continue
        
        return None

    def _parse_ai_response(self, text: str, analysis_data: Dict) -> List[Dict[str, Any]]:
        try:
            text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.IGNORECASE).strip()
            text = re.sub(r'\s*```$', '', text).strip()
            
            start_idx = text.find('{')
            end_idx = text.rfind('}')
            if start_idx != -1 and end_idx != -1:
                text = text[start_idx:end_idx+1]
            
            ai_response = json.loads(text.strip())
            
            insights = []
            timestamp = datetime.now(timezone.utc).isoformat()
            comp_id = self.competitor['id']
            
            valid_types = {"pricing_warfare", "product_gap", "competitive_threat", 
                          "counter_move", "market_timing", "brand_positioning",
                          "customer_psychology", "supply_chain_signal"}
            
            # 1. Executive Summary (كـ insight خاص)
            exec_summary = ai_response.get('executive_summary', '')
            if exec_summary:
                insights.append({
                    "competitor_id": comp_id,
                    "type": "executive_summary",
                    "title": "🎯 Executive Briefing",
                    "summary": str(exec_summary).strip(),
                    "ai_recommendation": "Review the full strategic package below and prioritize the top 2 quick wins for this sprint.",
                    "severity": "high",
                    "created_at": timestamp
                })
            
            # 2. Competitive Scorecard
            scorecard = ai_response.get('competitive_scorecard', {})
            if scorecard:
                scorecard_text = " | ".join([
                    f"{k.replace('_', ' ').title()}: {v.get('score', 0)}/10"
                    for k, v in scorecard.items() if isinstance(v, dict)
                ])
                insights.append({
                    "competitor_id": comp_id,
                    "type": "scorecard",
                    "title": "📊 Competitive Scorecard",
                    "summary": scorecard_text,
                    "ai_recommendation": "; ".join([
                        v.get('rationale', '')[:200] 
                        for v in scorecard.values() if isinstance(v, dict)
                    ]),
                    "severity": "medium",
                    "created_at": timestamp
                })
            
            # 3. Strategic Insights (حتى 8)
            insights_data = ai_response.get('insights', [])
            for i, insight in enumerate(insights_data[:8]):
                insight_type = str(insight.get('type', 'general')).lower()
                if insight_type not in valid_types:
                    insight_type = "general"
                
                severity = str(insight.get('severity', 'medium')).lower()
                if severity not in {"critical", "high", "medium", "low"}:
                    severity = "medium"
                
                insights.append({
                    "competitor_id": comp_id,
                    "type": insight_type,
                    "title": str(insight.get('title', f'Strategic Insight #{i+1}')).strip()[:200],
                    "summary": str(insight.get('summary', '')).strip(),
                    "ai_recommendation": str(insight.get('ai_recommendation', '')).strip(),
                    "severity": severity,
                    "created_at": timestamp
                })
            
            # 4. Quick Wins (كـ insight واحد يحتوي على قائمة)
            quick_wins = ai_response.get('quick_wins', [])
            if quick_wins and isinstance(quick_wins, list):
                insights.append({
                    "competitor_id": comp_id,
                    "type": "quick_wins",
                    "title": "⚡ Quick Wins (Execute in 7 Days)",
                    "summary": "\n".join([f"• {w}" for w in quick_wins[:3]]),
                    "ai_recommendation": "Assign these to your growth team immediately. Each is designed for sub-7-day execution with measurable impact.",
                    "severity": "high",
                    "created_at": timestamp
                })
            
            # 5. Risk Assessment
            risk = ai_response.get('risk_assessment', '')
            if risk:
                insights.append({
                    "competitor_id": comp_id,
                    "type": "risk_assessment",
                    "title": "⚠️ Risk Assessment",
                    "summary": str(risk).strip(),
                    "ai_recommendation": "Treat this as a 30-day warning window. Begin mitigation immediately.",
                    "severity": "high",
                    "created_at": timestamp
                })
            
            self.logger.info(f"🤖 Generated {len(insights)} Executive insights (including summary/scorecard/quick-wins)")
            return insights
            
        except json.JSONDecodeError as e:
            self.logger.error(f"⚠️ JSON parse failed: {e}")
            self.logger.error(f"🔍 Raw AI Response snippet: '{text[:400]}...'")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"⚠️ Error parsing response: {e}")
            return self._generate_fallback_insights()

    @rate_limit(calls_per_minute=8)
    def _generate_advanced_insights(self) -> List[Dict[str, Any]]:
        try:
            print(f"\n📊 Analyzing market positioning for {self.name} (tier: {self.tier})...")
            analysis_data = self._analyze_competitor_data()
            
            if "error" in analysis_data:
                return self._generate_fallback_insights()
            
            system_prompt, user_prompt = self._build_strategic_prompt(analysis_data)
            
            print(f"\n🧠 Generating Executive strategic package...")
            print("⏳ Deep market analysis in progress (60-150 seconds)...")
            
            ai_text = self._call_ai_provider(system_prompt, user_prompt)
            
            if ai_text:
                return self._parse_ai_response(ai_text, analysis_data)
            else:
                self.logger.warning("⚠️ All AI providers failed — using fallback template")
                return self._generate_fallback_insights()
                
        except Exception as e:
            self.logger.error(f"❌ AI generation failed: {e}")
            self.logger.exception("Full traceback:")
            return self._generate_fallback_insights()

    def _generate_fallback_insights(self) -> List[Dict[str, Any]]:
        timestamp = datetime.now(timezone.utc).isoformat()
        prices = [p.get("current_price") for p in self.products if p.get("current_price")]
        insights = []
        comp_id = self.competitor['id']
        
        # Executive Summary fallback
        insights.append({
            "competitor_id": comp_id,
            "type": "executive_summary",
            "title": "🎯 Executive Briefing (Baseline)",
            "summary": f"Scanned {len(self.products)} products from {self.name}. Average price: ${sum(prices)/len(prices):.2f} across {len(prices)} priced items.",
            "ai_recommendation": "AI providers were temporarily unavailable. Baseline analysis generated. Re-scan in 24 hours for full strategic package.",
            "severity": "medium",
            "created_at": timestamp
        })
        
        if prices:
            avg_price = sum(prices) / len(prices)
            insights.append({
                "competitor_id": comp_id,
                "type": "pricing_warfare",
                "title": f"Baseline Pricing Intelligence",
                "summary": f"Average market price: ${avg_price:.2f} across {len(prices)} products. Range: ${min(prices):.2f} to ${max(prices):.2f}.",
                "ai_recommendation": "Position core competing products within 10% of this average to maintain market parity. Target 50-60% gross margin on premium SKUs.",
                "severity": "medium",
                "created_at": timestamp
            })
        
        self.logger.info(f"⚠️ Generated {len(insights)} fallback insights")
        return insights

# ═══════════════════════════════════════════════════════════
# 🕷️ Scraper Engine
# ═════════════════════════════════════════════════════════
class ScraperEngine:
    def __init__(self):
        self.scrapers = {
            'shopify': scrape_shopify,
            'woocommerce': scrape_woocommerce,
            'generic': scrape_generic
        }
        self.logger = logging.getLogger('ScraperEngine')
    
    def scrape(self, url: str, platform: str = None, max_retries: int = 3, max_products: int = 9999) -> List[Dict[str, Any]]:
        if not platform:
            platform = detect_platform(url)
        
        scraper_func = self.scrapers.get(platform, scrape_generic)
        
        for attempt in range(max_retries):
            try:
                self.logger.info(f"🕷️ Using {platform} scraper (attempt {attempt + 1}/{max_retries})...")
                
                if inspect.iscoroutinefunction(scraper_func):
                    products = asyncio.run(scraper_func(url))
                else:
                    products = scraper_func(url)

                if products and len(products) > 0:
                    # حدّ المنتجات حسب الخطة
                    if len(products) > max_products:
                        products = products[:max_products]
                        self.logger.info(f"⏭️ Trimmed to {max_products} products (tier limit)")
                    
                    print_success(f"Successfully scraped {len(products)} products")
                    return products
                    
            except Exception as e:
                self.logger.error(f"Scraper failed (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)
        
        print_error(f"Failed to scrape after {max_retries} attempts")
        return []
    
    def clean_product_data(self, product: Dict[str, Any], competitor_id: str, timestamp: str) -> Dict[str, Any]:
        return {
            "competitor_id": competitor_id,
            "title": str(product.get("title", "Unknown Product"))[:255],
            "product_url": str(product.get("product_url", ""))[:500],
            "current_price": float(product.get("current_price", 0.0) or 0.0),
            "image_url": str(product.get("image_url", ""))[:500],
            "last_updated_at": timestamp,
        }

# ═══════════════════════════════════════════════════════════
# 🚀 Main Application
# ══════════════════════════════════════════════════════════
class VeloraScraper:
    def __init__(self):
        self.config = Config()
        self.supabase = None
        self.db = None
        self.scraper = ScraperEngine()
        self.logger = logging.getLogger('VeloraScraper')
    
    def initialize(self) -> bool:
        print_banner()
        if not self.config.validate():
            return False
        
        try:
            self.supabase = create_client(self.config.supabase_url, self.config.supabase_key)
            self.db = DatabaseManager(self.supabase)
            print_success("Connected to Supabase")
            return True
        except Exception as e:
            print_error(f"Failed to connect to Supabase: {e}")
            return False
    
    def display_intelligence_brief(self, brief: Dict, insights: List[Dict]):
        print_header("📊 MARKET INTELLIGENCE BRIEFING")
        print(f"{Colors.OKCYAN}{'─'*80}{Colors.ENDC}")
        
        print(f"{Colors.BOLD}Target Competitor:{Colors.ENDC} {brief.get('competitor_name')}")
        print(f"{Colors.BOLD}Tier:{Colors.ENDC} {brief.get('tier_context', 'free').upper()}")
        print(f"{Colors.BOLD}Products Analyzed:{Colors.ENDC} {brief.get('products_with_pricing')} / {brief.get('total_products_scanned')}")
        print()
        
        # Executive Summary
        exec_insight = next((i for i in insights if i.get('type') == 'executive_summary'), None)
        if exec_insight:
            print(f"{Colors.BOLD}🎯 EXECUTIVE SUMMARY:{Colors.ENDC}")
            print(f"  {exec_insight.get('summary')}")
            print()
        
        # Scorecard
        scorecard_insight = next((i for i in insights if i.get('type') == 'scorecard'), None)
        if scorecard_insight:
            print(f"{Colors.BOLD}📊 COMPETITIVE SCORECARD:{Colors.ENDC}")
            print(f"  {scorecard_insight.get('summary')}")
            print()
        
        # Strategic Insights
        strategic_types = {"pricing_warfare", "product_gap", "competitive_threat", 
                          "counter_move", "market_timing", "brand_positioning",
                          "customer_psychology", "supply_chain_signal"}
        
        print_header("🧠 STRATEGIC INSIGHTS")
        for i, insight in enumerate(insights, 1):
            if insight.get('type') not in strategic_types:
                continue
            severity_color = Colors.WARNING if insight.get('severity') in ['critical', 'high'] else Colors.OKGREEN
            print(f"\n{Colors.OKCYAN}{'─'*80}{Colors.ENDC}")
            print(f"{Colors.BOLD}INSIGHT #{i} [{insight.get('type').upper()}] - Severity: {severity_color}{insight.get('severity').upper()}{Colors.ENDC}")
            print(f"{Colors.BOLD}Title:{Colors.ENDC} {insight.get('title')}")
            print(f"\n{Colors.OKBLUE}Situation Summary:{Colors.ENDC}")
            print(f"  {insight.get('summary')}")
            print(f"\n{Colors.OKGREEN}🎯 Strategic Counter-Move:{Colors.ENDC}")
            print(f"  {insight.get('ai_recommendation')}")
        
        # Quick Wins
        qw_insight = next((i for i in insights if i.get('type') == 'quick_wins'), None)
        if qw_insight:
            print_header("⚡ QUICK WINS")
            print(f"  {qw_insight.get('summary')}")
        
        print(f"\n{Colors.OKGREEN}{'═'*80}{Colors.ENDC}\n")

    def scan_competitor(self, competitor: Dict[str, Any], url: str) -> bool:
        competitor_name = competitor.get('name', 'Unknown')
        competitor_id = competitor.get('id')
        tier = competitor.get('_tier', 'free')
        limits = competitor.get('_limits', TIER_LIMITS['free'])
        
        print(f"\n{'='*80}")
        print(f"🎯 Target Acquired: {competitor_name}")
        print(f"📍 URL: {url}")
        print(f"🏆 Tier: {tier.upper()} (max {limits['max_products']} products)")
        print(f"{'='*80}\n")
        
        try:
            products = self.scraper.scrape(url, max_products=limits['max_products'])
            if not products:
                print_warning(f"No products found for {competitor_name}")
                return False
            
            timestamp = datetime.now(timezone.utc).isoformat()
            cleaned_products = [self.scraper.clean_product_data(p, competitor_id, timestamp) for p in products]
            
            if self.db.upsert_products(cleaned_products) == 0:
                print_error("Failed to save products")
                return False
            
            # حفظ history (ميزة Pro Plus)
            self.db.save_price_history(cleaned_products, competitor_id)
            
            # جلب المسح السابق (ميزة Pro)
            previous_scan = self.db.get_previous_scan_data(competitor_id)
            
            # توليد الرؤى
            intel_engine = MarketIntelligenceEngine(competitor, products, previous_scan)
            insights = intel_engine.generate_all_insights()
            
            brief = intel_engine._analyze_competitor_data()
            if "error" not in brief:
                self.display_intelligence_brief(brief, insights)
            
            if insights:
                self.db.save_insights(insights)
                print_success(f"Saved {len(insights)} strategic insights to database")
            
            try:
                print(f"\n📈 Analyzing price trends for {competitor_name}...")
                trend_analyzer = TrendAnalyzer(competitor_id, products)
                trend_data = trend_analyzer.analyze_price_trends()
                
                if "error" not in trend_data and trend_data.get("insights"):
                    self.db.save_trend_insights(trend_data["insights"])
                    print_success(f"Saved {len(trend_data['insights'])} trend insights")
            except Exception as e:
                self.logger.error(f"Trend analysis failed: {e}")
            
            self.db.update_competitor_scan_time(competitor_id)
            
            print_success(f"✅ Mission Complete: {competitor_name}")
            print(f"   • Products Mapped: {len(cleaned_products)}")
            print(f"   • Executive Insights Generated: {len(insights)}")
            
            return True
            
        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception("Scan failed:")
            return False
    
    def run_dynamic_mode(self, force_all: bool = False):
        print_info("Running in TIER-AWARE DYNAMIC MODE")
        pending = self.db.get_pending_competitors(force_all=force_all)
        
        if not pending:
            print_success("✅ All competitors are up to date!")
            print_info("   Next auto-update according to tier schedules")
            return
        
        print_info(f"Found {len(pending)} competitor(s) to scan\n")
        
        for i, comp in enumerate(pending, 1):
            print(f"\n[{i}/{len(pending)}]")
            url = comp.get('website') or comp.get('shopify_store')
            if url:
                self.scan_competitor(comp, url)
            if i < len(pending):
                time.sleep(2)
    
    def run(self, url: str = None, continuous: bool = False, force_all: bool = False):
        if not self.initialize():
            sys.exit(1)
        
        if continuous:
            print_info(f"⏳ Continuous mode: checking every {self.config.scan_interval}s")
            first_run = True
            try:
                while True:
                    self.run_dynamic_mode(force_all=(first_run and force_all))
                    first_run = False
                    time.sleep(self.config.scan_interval)
            except KeyboardInterrupt:
                print_info("\n👋 Continuous mode stopped by user")
        elif url:
            comp = self.db.get_or_create_competitor(url)
            if comp:
                self.scan_competitor(comp, url)
        elif force_all:
            self.run_dynamic_mode(force_all=True)
        else:
            self.run_dynamic_mode(force_all=False)

def main():
    parser = argparse.ArgumentParser(
        description="Velora v3.0 — Executive Market Intelligence Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py                          # Scan based on tier schedules
  python main.py --force-all              # Force scan all competitors (ignore schedules)
  python main.py --continuous             # Run continuously
  python main.py https://example.com      # Scan specific URL
        """
    )
    
    parser.add_argument('url', nargs='?', help='Store URL to scan (optional)')
    parser.add_argument('--continuous', '-c', action='store_true', help='Run continuously')
    parser.add_argument('--force-all', '-f', action='store_true', help='Force scan all competitors')
    
    args = parser.parse_args()
    
    scraper = VeloraScraper()
    scraper.run(
        url=args.url,
        continuous=args.continuous,
        force_all=args.force_all
    )

if __name__ == "__main__":
    main()
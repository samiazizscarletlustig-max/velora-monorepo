"""
 Velora — Advanced Competitive Market Intelligence Engine
═══════════════════════════════════════════════════════════════
PRODUCTION VERSION v3.4 — "The AI Whisperer Edition"

☁️ Cloud-Powered (Hugging Face Router — Multi-Provider Chain)
🏆 Tier-Aware Scanning (Free / Pro / Pro Plus / Enterprise)
🧠 Dynamic AI Analysis (Strictly Optimized): 
   - Free: 4 Surgical, Data-Driven Insights (Upgrade Pressure)
   - Pro: 8 Executive Insights + Scorecard + Financial Blueprint
📈 Price History Tracking & Strict Rate Limiting

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
# 🏆 TIER SYSTEM — حدود صارمة لكل خطة اشتراك
# ═══════════════════════════════════════════════════════════
TIER_LIMITS = {
    'free':       {'max_competitors': 3,    'scan_interval_hours': 24, 'max_products': 300,  'ai_depth': 'scientific', 'ai_tokens': 3000},
    'pro':        {'max_competitors': 10,   'scan_interval_hours': 6,  'max_products': 1000, 'ai_depth': 'executive',  'ai_tokens': 4500},
    'pro_plus':   {'max_competitors': 25,   'scan_interval_hours': 3,  'max_products': 2500, 'ai_depth': 'executive',  'ai_tokens': 4500},
    'enterprise': {'max_competitors': 9999, 'scan_interval_hours': 1,  'max_products': 9999, 'ai_depth': 'executive',  'ai_tokens': 4500},
}

# ═══════════════════════════════════════════════════════════
# 🛡️ Rate Limiting
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
# 🎨 Color Codes
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
    print(f"{Colors.OKBLUE} Velora v3.4 — The AI Whisperer Edition{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Surgical Precision • Zero Fluff • Maximum Token Efficiency{Colors.ENDC}")
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
# 🗄️ Database Manager
# ══════════════════════════════════════════════════════════
class DatabaseManager:
    def __init__(self, supabase: Client):
        self.supabase = supabase
        self.logger = logging.getLogger('DatabaseManager')
    
    def get_pending_competitors(self, force_all: bool = False) -> List[Dict[str, Any]]:
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

                per_user[uid] = per_user.get(uid, 0) + 1
                if per_user[uid] > limits['max_competitors']:
                    self.logger.info(f"⏭️ Skip {row.get('name')}: tier '{tier}' cap reached")
                    continue

                if not force_all:
                    last = row.get('last_scan_at')
                    if last:
                        last_dt = datetime.fromisoformat(last.replace('Z', '+00:00'))
                        if last_dt.tzinfo is None:
                            last_dt = last_dt.replace(tzinfo=timezone.utc)
                        if now - last_dt < timedelta(hours=limits['scan_interval_hours']):
                            continue

                row['_tier'] = tier
                row['_limits'] = limits
                pending.append(row)

            self.logger.info(f"Found {len(pending)} competitor(s) to scan (tier-aware)")
            return pending
        except Exception as e:
            self.logger.error(f"Failed to fetch competitors: {e}")
            return []
    
    def get_or_create_competitor(self, url: str, user_id: str = None) -> Optional[Dict[str, Any]]:
        try:
            for check_url in [url, url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")]:
                response = self.supabase.table("competitors").select("id, name, website, user_id").eq("website", check_url).execute()
                if response.data: return response.data[0]
            
            store_name = urlparse(url).netloc.replace('www.', '').split('.')[0].capitalize()
            
            if not user_id:
                users = self.supabase.auth.admin.list_users().get('users', [])
                if not users:
                    print_error("No users found in auth.users.")
                    return None
                user_id = users[0]['id']
            
            response = self.supabase.table("competitors").insert({
                'name': store_name, 'website': url, 'user_id': user_id,
                'created_at': datetime.now(timezone.utc).isoformat()
            }).execute()
            if response.data: print_success(f"Created competitor: {store_name} for user {user_id}")
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
            
            if not history_rows: return 0
            
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
        try:
            response = (
                self.supabase.table("ai_insights")
                .select("*")
                .eq("competitor_id", competitor_id)
                .order("created_at", desc=True)
                .limit(8)
                .execute()
            )
            if not response.data: return None
            return {"previous_insights": response.data}
        except Exception as e:
            self.logger.warning(f"Could not fetch previous scan: {e}")
            return None
    
    def save_insights(self, insights: List[Dict[str, Any]], competitor_id: str = None) -> bool:
        try:
            for insight in insights:
                if not insight.get('competitor_id'):
                    insight['competitor_id'] = competitor_id or insights[0].get('competitor_id')
                if not insight.get('created_at'):
                    insight['created_at'] = datetime.now(timezone.utc).isoformat()
            
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
# 🧠 DYNAMIC MARKET INTELLIGENCE ENGINE (v3.4 - AI WHISPERER)
# ═══════════════════════════════════════════════════════════
class MarketIntelligenceEngine:
    PROVIDERS = [
        {"name": "Llama-3.3-70B", "model": "meta-llama/Llama-3.3-70B-Instruct", "url": "https://router.huggingface.co/v1/chat/completions"},
        {"name": "Qwen-2.5-72B", "model": "Qwen/Qwen2.5-72B-Instruct", "url": "https://router.huggingface.co/v1/chat/completions"},
        {"name": "Mixtral-8x7B", "model": "mistralai/Mixtral-8x7B-Instruct-v0.1", "url": "https://router.huggingface.co/v1/chat/completions"},
    ]

    CATEGORY_KEYWORDS = ["shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock", "accessory", "sweater", "hoodie", "short", "skirt", "coat", "boot", "sandal", "sneaker", "scarf", "belt", "watch", "jewelry"]
    PROMOTION_KEYWORDS = ["sale", "off", "discount", "limited", "new", "bestseller", "clearance"]

    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]], previous_scan: Optional[Dict[str, Any]] = None):
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
        prices = [p.get("current_price", 0) for p in self.products if p.get("current_price") and p.get("current_price") > 0]
        if not prices: return {"error": "No pricing data available"}
        
        avg_price = sum(prices) / len(prices)
        median_price = statistics.median(prices)
        try: stdev_price = statistics.stdev(prices) if len(prices) > 1 else 0
        except: stdev_price = 0
        
        budget_threshold = avg_price * 0.6
        premium_threshold = avg_price * 1.5
        
        budget_products = [p for p in prices if p < budget_threshold]
        mid_tier = [p for p in prices if budget_threshold <= p <= premium_threshold]
        premium_products = [p for p in prices if p > premium_threshold]
        
        sorted_products = sorted(self.products, key=lambda x: x.get("current_price", 0), reverse=True)
        
        category_counts = Counter()
        promotion_count = 0
        for p in self.products:
            title = str(p.get("title", "")).lower()
            for kw in self.CATEGORY_KEYWORDS:
                if kw in title: category_counts[kw] += 1
            for promo in self.PROMOTION_KEYWORDS:
                if promo in title:
                    promotion_count += 1
                    break
        
        top_categories = category_counts.most_common(5)
        
        # ✅ NEW: Category Concentration Index (HHI)
        total_cat_products = sum(category_counts.values())
        hhi = sum((count / total_cat_products) ** 2 for count in category_counts.values()) if total_cat_products > 0 else 0
        hhi_score = round(hhi * 10000, 1)
        hhi_interp = "highly concentrated" if hhi_score > 2500 else "moderately concentrated" if hhi_score > 1500 else "diversified"
        
        price_gaps = []
        sorted_prices = sorted(prices)
        for i in range(len(sorted_prices) - 1):
            gap = sorted_prices[i+1] - sorted_prices[i]
            if gap > avg_price * 0.3:
                price_gaps.append({"from": round(sorted_prices[i], 2), "to": round(sorted_prices[i+1], 2), "size": round(gap, 2)})
        
        # ✅ NEW: Price-Gap-to-Average Ratio
        price_gap_ratios = []
        for gap in price_gaps[:5]:
            ratio = gap['size'] / avg_price if avg_price > 0 else 0
            price_gap_ratios.append({**gap, 'ratio_to_avg': round(ratio, 2)})
        
        cov = round(stdev_price / avg_price, 2) if avg_price > 0 else 0
        cov_interp = "inconsistent/opportunistic" if cov > 0.4 else "disciplined/confident" if cov < 0.15 else "moderate"
        
        promo_pct = round((promotion_count / len(self.products)) * 100, 1) if self.products else 0
        top_cat = top_categories[0] if top_categories else ("unknown", 0)
        top_cat_pct = round((top_cat[1] / len(prices)) * 100, 1) if len(prices) > 0 else 0
        largest_gap = price_gap_ratios[0] if price_gap_ratios else {"from": 0, "to": 0, "size": 0, "ratio_to_avg": 0}

        # ✅ NEW: Headline Stats (Forced AI Usage)
        headline_stats = f"""
        HEADLINE STATS (You MUST use at least 3 of these verbatim with exact values):
        - Largest Price Gap: ${largest_gap['from']}-${largest_gap['to']} (Size: ${largest_gap['size']}, Ratio to Avg: {largest_gap['ratio_to_avg']}x)
        - Category Concentration: Top category is '{top_cat[0]}' ({top_cat[1]} products, {top_cat_pct}% of catalog). HHI Index: {hhi_score} ({hhi_interp}).
        - Promotional Intensity: {promo_pct}% of products use promo keywords.
        - Price Discipline (CoV): {cov} ({cov_interp} pricing).
        """

        return {
            "competitor_name": self.name,
            "scan_date": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
            "tier_context": self.tier,
            "total_products_scanned": len(self.products),
            "products_with_pricing": len(prices),
            "headline_stats": headline_stats,
            "pricing_intelligence": {
                "average_price": round(avg_price, 2), "median_price": round(median_price, 2),
                "standard_deviation": round(stdev_price, 2), "lowest_price": round(min(prices), 2),
                "highest_price": round(max(prices), 2), "price_spread": round(max(prices) - min(prices), 2),
                "price_coefficient_of_variation": cov, "cov_interpretation": cov_interp
            },
            "market_positioning": {
                "budget_segment": {"count": len(budget_products), "percentage": round(len(budget_products)/len(prices)*100, 1)},
                "mid_tier_segment": {"count": len(mid_tier), "percentage": round(len(mid_tier)/len(prices)*100, 1)},
                "premium_segment": {"count": len(premium_products), "percentage": round(len(premium_products)/len(prices)*100, 1)}
            },
            "category_intelligence": {
                "top_5_categories": [{"category": k, "count": v} for k, v in top_categories], 
                "hhi_index": hhi_score, "hhi_interpretation": hhi_interp
            },
            "promotion_signals": {"products_with_promo_keywords": promotion_count, "promo_percentage": promo_pct},
            "price_gaps": price_gap_ratios,
            "strategic_anchors": {
                "top_3_premium_prices": [round(p.get("current_price", 0), 2) for p in sorted_products[:3]],
                "top_3_entry_prices": [round(p.get("current_price", 0), 2) for p in sorted_products[-3:] if p.get("current_price")]
            }
        }

    def _build_strategic_prompt(self, data: Dict[str, Any]) -> Tuple[str, str, int]:
        forbidden_rules = """
        FORBIDDEN PHRASES (Using any fails the task): "focus on quality", "improve marketing", "stand out from competitors", "consider offering", "it may be beneficial", "in today's market", "leverage your strengths".
        CRITICAL RULE: Every single sentence in your summary and recommendation MUST contain at least one specific number from the data. Sentences with zero numbers are strictly forbidden.
        NO HEDGING: Never use "could", "might", or "consider". Use "Launch", "Price at", "Cut", "Target".
        """

        if self.tier == 'free':
            system_prompt = f"""You are a SENIOR E-COMMERCE MARKET ANALYST. Data scientist who talks like a founder's smartest friend. Precise, blunt, zero corporate hedging.

YOUR MISSION: Provide exactly 4 DEEP, SCIENTIFIC, DATA-DRIVEN strategic insights in this EXACT order:
1. Price Gap Exploitation (product_gap): Identify 1-2 specific dollar ranges where competitor has ZERO products.
2. Category Concentration Risk (category_dominance): Use HHI index to show where they are strong but exposed.
3. Promotional Behavior Signal (competitive_threat): High promo % = inventory stress. Low promo % = pricing confidence.
4. Positioning Verdict (pricing_warfare): Budget/mid/premium split + CoV verdict.

{forbidden_rules}

UPGRADE TRIGGER: End the ai_recommendation of the 4th insight with a dangling thread: "The optimal entry price for this gap is calculable from margin data — Pro users get the exact price point and unit target."

OUTPUT FORMAT (JSON only):
{{
  "executive_summary": "3-sentence overview: market position, top category with data, primary vulnerability",
  "insights": [
    {{
      "type": "product_gap|category_dominance|competitive_threat|pricing_warfare",
      "title": "Professional 6-8 word headline",
      "summary": "Scientific observation with specific data points (80-120 words)",
      "ai_recommendation": "Exact tactical move: Launch X products in Y category at $Z price within 30 days (80-120 words)",
      "severity": "high|medium|low"
    }}
  ]
}}"""
            
            user_prompt = f"""{data.get('headline_stats')}

Analyze this competitor data and provide 4 deep, scientific insights.
Competitor: {data.get('competitor_name')}
Products Analyzed: {data.get('products_with_pricing')}
Avg Price: ${data.get('pricing_intelligence', {}).get('average_price', 0):.2f}

Full Data:
{json.dumps(data, indent=2)}
"""
            max_tokens = 3000

        else:  # Pro, Pro Plus, Enterprise
            system_prompt = f"""You are a CHIEF STRATEGY OFFICER (CSO) and former McKinsey Partner specializing in D2C/E-commerce.

YOUR MISSION: Generate a BOARD-READY strategic intelligence dossier with EXECUTABLE financial blueprints.

{forbidden_rules}
CROSS-REFERENCE RULE: Every recommendation must reference at least one other insight in this report by name (e.g., "As noted in the Price Gap insight..."). This must read as one connected thesis.

REQUIRED OUTPUT STRUCTURE (JSON only):
{{
  "executive_summary": "3 sentences: market position, biggest whitespace opportunity, most critical threat",
  "competitive_scorecard": {{
    "pricing_strategy": {{"score": 7, "rationale": "Data-backed reason with numbers"}},
    "category_depth": {{"score": 6, "rationale": "Data-backed reason with numbers"}},
    "brand_positioning": {{"score": 8, "rationale": "Data-backed reason with numbers"}},
    "market_coverage": {{"score": 5, "rationale": "Data-backed reason with numbers"}}
  }},
  "insights": [
    {{
      "type": "pricing_warfare|product_gap|competitive_threat|counter_move|market_timing|brand_positioning|customer_psychology|supply_chain_signal",
      "title": "Board-level headline",
      "summary": "Data-backed situation analysis (100-150 words)",
      "ai_recommendation": "Executable plan with financial metrics (100-150 words)",
      "severity": "critical|high|medium|low"
    }}
  ],
  "financial_execution_blueprint": "One paragraph detailing: exact product to launch, target price range, target gross margin %, initial unit count, days-to-execute, and one success KPI.",
  "quick_wins": ["Actionable step executable within 7 days with expected impact", "...", "..."],
  "risk_assessment": "2-3 sentences on the biggest strategic risks if we fail to respond in 30 days, with a timeline."
}}"""
            
            user_prompt = f"""{data.get('headline_stats')}

## COMPETITOR INTELLIGENCE REPORT — {data.get('competitor_name')}
Tier: {data.get('tier_context').upper()}
Scan Date: {data.get('scan_date')}

{json.dumps(data, indent=2)}

## DELIVERABLE — 8 STRATEGIC INSIGHTS:
1. Pricing warfare  2. Product gap  3. Competitive threat  4. Counter-move
5. Market timing  6. Brand positioning  7. Customer psychology  8. Supply chain signal

Return ONLY valid JSON."""
            max_tokens = 4500

        return system_prompt, user_prompt, max_tokens

    def _call_ai_provider(self, system_prompt: str, user_prompt: str, max_tokens: int) -> Optional[str]:
        for i, provider in enumerate(self.PROVIDERS):
            try:
                print(f"\n☁️ [{i+1}/{len(self.PROVIDERS)}] Calling {provider['name']}...")
                response = requests.post(
                    provider["url"],
                    headers={"Authorization": f"Bearer {self.hf_api_key}", "Content-Type": "application/json"},
                    json={
                        "model": provider["model"],
                        "messages": [{"role": "system", "content": system_prompt}, {"role": "user", "content": user_prompt}],
                        "max_tokens": max_tokens,
                        "temperature": 0.3,
                        "top_p": 0.9,
                    },
                    timeout=150
                )
                
                if response.status_code != 200:
                    self.logger.warning(f"  ↳ {provider['name']} returned {response.status_code}: {response.text[:200]}")
                    continue
                
                data = response.json()
                if "choices" in data and len(data["choices"]) > 0:
                    text = data["choices"][0].get("message", {}).get("content", "")
                    if text:
                        print_success(f"  ↳ {provider['name']} responded successfully ({len(text)} chars)")
                        return text
                
                self.logger.warning(f"  ↳ {provider['name']} returned empty/unexpected format")
                continue
            except Exception as e:
                self.logger.warning(f"  ↳ {provider['name']} error: {str(e)[:100]}")
                continue
        return None

    def _parse_ai_response(self, text: str, analysis_data: Dict) -> List[Dict[str, Any]]:
        try:
            text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.IGNORECASE).strip()
            text = re.sub(r'\s*```$', '', text).strip()
            start_idx, end_idx = text.find('{'), text.rfind('}')
            if start_idx != -1 and end_idx != -1: text = text[start_idx:end_idx+1]
            
            ai_response = json.loads(text.strip())
            insights = []
            timestamp = datetime.now(timezone.utc).isoformat()
            comp_id = self.competitor['id']
            valid_types = {"pricing_warfare", "product_gap", "competitive_threat", "counter_move", "market_timing", "brand_positioning", "customer_psychology", "supply_chain_signal", "category_dominance"}
            
            if self.tier == 'free':
                exec_summary = ai_response.get('executive_summary', '')
                if exec_summary:
                    insights.append({"competitor_id": comp_id, "type": "executive_summary", "title": "📊 Market Overview", "summary": str(exec_summary).strip(), "ai_recommendation": "Review insights below. Upgrade to Pro for detailed financial projections, unit targets, and execution timelines.", "severity": "medium", "created_at": timestamp})
                
                for i, insight in enumerate(ai_response.get('insights', [])[:4]):
                    severity = str(insight.get('severity', 'medium')).lower()
                    if severity not in {"critical", "high", "medium", "low"}: severity = "medium"
                    insights.append({
                        "competitor_id": comp_id, "type": str(insight.get('type', 'general')).lower(),
                        "title": str(insight.get('title', f'Insight #{i+1}')).strip()[:200],
                        "summary": str(insight.get('summary', '')).strip(),
                        "ai_recommendation": str(insight.get('ai_recommendation', '')).strip(),
                        "severity": severity, "created_at": timestamp
                    })
            else:
                exec_summary = ai_response.get('executive_summary', '')
                if exec_summary:
                    insights.append({"competitor_id": comp_id, "type": "executive_summary", "title": "🎯 Executive Briefing", "summary": str(exec_summary).strip(), "ai_recommendation": "Review the full strategic package below and prioritize the top 2 quick wins.", "severity": "high", "created_at": timestamp})
                
                scorecard = ai_response.get('competitive_scorecard', {})
                if scorecard:
                    scorecard_text = " | ".join([f"{k.replace('_', ' ').title()}: {v.get('score', 0)}/10 — {v.get('rationale', '')[:100]}" for k, v in scorecard.items() if isinstance(v, dict)])
                    insights.append({"competitor_id": comp_id, "type": "scorecard", "title": "📊 Competitive Scorecard", "summary": scorecard_text, "ai_recommendation": "Focus on the lowest-scoring area for immediate competitive advantage.", "severity": "medium", "created_at": timestamp})
                
                for i, insight in enumerate(ai_response.get('insights', [])[:8]):
                    insight_type = str(insight.get('type', 'general')).lower()
                    if insight_type not in valid_types: insight_type = "general"
                    severity = str(insight.get('severity', 'medium')).lower()
                    if severity not in {"critical", "high", "medium", "low"}: severity = "medium"
                    insights.append({"competitor_id": comp_id, "type": insight_type, "title": str(insight.get('title', f'Insight #{i+1}')).strip()[:200], "summary": str(insight.get('summary', '')).strip(), "ai_recommendation": str(insight.get('ai_recommendation', '')).strip(), "severity": severity, "created_at": timestamp})
                
                financial_blueprint = ai_response.get('financial_execution_blueprint', '')
                if financial_blueprint:
                    insights.append({"competitor_id": comp_id, "type": "financial_blueprint", "title": "💰 Financial Execution Blueprint", "summary": "Detailed rollout plan", "ai_recommendation": str(financial_blueprint).strip(), "severity": "critical", "created_at": timestamp})
                
                quick_wins = ai_response.get('quick_wins', [])
                if quick_wins and isinstance(quick_wins, list):
                    insights.append({"competitor_id": comp_id, "type": "quick_wins", "title": "⚡ Quick Wins (Execute in 7 Days)", "summary": "\n".join([f"• {w}" for w in quick_wins[:3]]), "ai_recommendation": "Assign these to your growth team immediately.", "severity": "high", "created_at": timestamp})
                
                risk = ai_response.get('risk_assessment', '')
                if risk:
                    insights.append({"competitor_id": comp_id, "type": "risk_assessment", "title": "⚠️ Risk Assessment", "summary": str(risk).strip(), "ai_recommendation": "Treat this as a 30-day warning window. Begin mitigation immediately.", "severity": "high", "created_at": timestamp})
            
            self.logger.info(f"🤖 Generated {len(insights)} insights for tier: {self.tier}")
            return insights
        except json.JSONDecodeError as e:
            self.logger.error(f"⚠️ JSON parse failed: {e}")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"⚠️ Error parsing response: {e}")
            return self._generate_fallback_insights()

    @rate_limit(calls_per_minute=8)
    def _generate_advanced_insights(self) -> List[Dict[str, Any]]:
        try:
            print(f"\n📊 Analyzing market positioning for {self.name} (tier: {self.tier})...")
            analysis_data = self._analyze_competitor_data()
            if "error" in analysis_data: return self._generate_fallback_insights()
            
            system_prompt, user_prompt, max_tokens = self._build_strategic_prompt(analysis_data)
            print(f"\n🧠 Generating {self.tier.upper()} strategic package...")
            print("⏳ Deep market analysis in progress...")
            
            ai_text = self._call_ai_provider(system_prompt, user_prompt, max_tokens)
            if ai_text: return self._parse_ai_response(ai_text, analysis_data)
            
            self.logger.warning("⚠️ All AI providers failed — using fallback template")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"❌ AI generation failed: {e}")
            return self._generate_fallback_insights()

    def _generate_fallback_insights(self) -> List[Dict[str, Any]]:
        timestamp = datetime.now(timezone.utc).isoformat()
        prices = [p.get("current_price") for p in self.products if p.get("current_price")]
        insights = []
        comp_id = self.competitor['id']
        
        insights.append({"competitor_id": comp_id, "type": "executive_summary", "title": "🎯 Executive Briefing (Baseline)", "summary": f"Scanned {len(self.products)} products from {self.name}. Average price: ${sum(prices)/len(prices):.2f} across {len(prices)} priced items.", "ai_recommendation": "AI providers were temporarily busy. Baseline analysis generated. Re-scan in 24 hours for full strategic package.", "severity": "medium", "created_at": timestamp})
        
        if prices:
            avg_price = sum(prices) / len(prices)
            insights.append({"competitor_id": comp_id, "type": "pricing_warfare", "title": "Baseline Pricing Intelligence", "summary": f"Average market price: ${avg_price:.2f} across {len(prices)} products. Range: ${min(prices):.2f} to ${max(prices):.2f}.", "ai_recommendation": "Position core competing products within 10% of this average to maintain market parity.", "severity": "medium", "created_at": timestamp})
        
        self.logger.info(f"⚠️ Generated {len(insights)} fallback insights")
        return insights

# ═══════════════════════════════════════════════════════════
# 🕷️ Scraper Engine
# ═════════════════════════════════════════════════════════
class ScraperEngine:
    def __init__(self):
        self.scrapers = {'shopify': scrape_shopify, 'woocommerce': scrape_woocommerce, 'generic': scrape_generic}
        self.logger = logging.getLogger('ScraperEngine')
    
    def scrape(self, url: str, platform: str = None, max_retries: int = 3, max_products: int = 9999) -> List[Dict[str, Any]]:
        if not platform: platform = detect_platform(url)
        scraper_func = self.scrapers.get(platform, scrape_generic)
        
        for attempt in range(max_retries):
            try:
                self.logger.info(f"🕷️ Using {platform} scraper (attempt {attempt + 1}/{max_retries})...")
                products = asyncio.run(scraper_func(url)) if inspect.iscoroutinefunction(scraper_func) else scraper_func(url)

                if products and len(products) > 0:
                    if len(products) > max_products:
                        products = products[:max_products]
                        self.logger.info(f"⏭️ Trimmed to {max_products} products (tier limit)")
                    print_success(f"Successfully scraped {len(products)} products")
                    return products
            except Exception as e:
                self.logger.error(f"Scraper failed (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1: time.sleep(2 ** attempt)
        
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
        if not self.config.validate(): return False
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
        
        exec_insight = next((i for i in insights if i.get('type') == 'executive_summary'), None)
        if exec_insight:
            print(f"{Colors.BOLD}🎯 EXECUTIVE SUMMARY:{Colors.ENDC}\n  {exec_insight.get('summary')}\n")
        
        scorecard_insight = next((i for i in insights if i.get('type') == 'scorecard'), None)
        if scorecard_insight:
            print(f"{Colors.BOLD}📊 COMPETITIVE SCORECARD:{Colors.ENDC}\n  {scorecard_insight.get('summary')}\n")
        
        strategic_types = {"pricing_warfare", "product_gap", "competitive_threat", "counter_move", "market_timing", "brand_positioning", "customer_psychology", "supply_chain_signal", "category_dominance", "financial_blueprint"}
        print_header("🧠 STRATEGIC INSIGHTS")
        for i, insight in enumerate(insights, 1):
            if insight.get('type') not in strategic_types: continue
            severity_color = Colors.WARNING if insight.get('severity') in ['critical', 'high'] else Colors.OKGREEN
            print(f"\n{Colors.OKCYAN}{'─'*80}{Colors.ENDC}")
            print(f"{Colors.BOLD}INSIGHT #{i} [{insight.get('type').upper()}] - Severity: {severity_color}{insight.get('severity').upper()}{Colors.ENDC}")
            print(f"{Colors.BOLD}Title:{Colors.ENDC} {insight.get('title')}")
            print(f"\n{Colors.OKBLUE}Situation Summary:{Colors.ENDC}\n  {insight.get('summary')}")
            print(f"\n{Colors.OKGREEN}🎯 Strategic Counter-Move:{Colors.ENDC}\n  {insight.get('ai_recommendation')}")
        
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
            
            self.db.save_price_history(cleaned_products, competitor_id)
            previous_scan = self.db.get_previous_scan_data(competitor_id)
            
            intel_engine = MarketIntelligenceEngine(competitor, products, previous_scan)
            insights = intel_engine.generate_all_insights()
            
            brief = intel_engine._analyze_competitor_data()
            if "error" not in brief: self.display_intelligence_brief(brief, insights)
            
            if insights:
                self.db.save_insights(insights, competitor_id)
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
            if url: self.scan_competitor(comp, url)
            if i < len(pending): time.sleep(2)
    
    def run(self, url: str = None, continuous: bool = False, force_all: bool = False):
        if not self.initialize(): sys.exit(1)
        
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
            if comp: self.scan_competitor(comp, url)
        elif force_all:
            self.run_dynamic_mode(force_all=True)
        else:
            self.run_dynamic_mode(force_all=False)

def main():
    parser = argparse.ArgumentParser(description="Velora v3.4 — The AI Whisperer Edition", formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('url', nargs='?', help='Store URL to scan (optional)')
    parser.add_argument('--continuous', '-c', action='store_true', help='Run continuously')
    parser.add_argument('--force-all', '-f', action='store_true', help='Force scan all competitors')
    args = parser.parse_args()
    
    scraper = VeloraScraper()
    scraper.run(url=args.url, continuous=args.continuous, force_all=args.force_all)

if __name__ == "__main__":
    main()
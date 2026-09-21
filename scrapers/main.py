"""
 Velora — Advanced Competitive Market Intelligence Engine
═══════════════════════════════════════════════════════════════
PRODUCTION VERSION — Cloud-Powered (Hugging Face Inference Providers)
Multi-Provider Chain: Llama-3.3-70B → Qwen-2.5-72B → Fallback
Fast, Reliable, and Ready for GitHub Actions
Free Tier: 3 Competitors, Scan Every 24 Hours

v2.0 — Deep Strategic Analysis (6 board-level insights per scan)
"""

import os, sys, time, json, logging, argparse, re, inspect, asyncio, requests
from pathlib import Path
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse
from typing import List, Dict, Optional, Any
from functools import wraps

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
#  Logging Configuration
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
    print(f"{Colors.OKBLUE} Velora — Competitive Market Intelligence Engine{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Cloud-Powered by Hugging Face (Multi-Provider Chain){Colors.ENDC}")
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
        print_info("☁️ Using Hugging Face Cloud API (Multi-Provider Chain)")
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
            max_competitors = int(os.getenv("MAX_COMPETITORS", "3"))
            
            query = self.supabase.table("competitors").select("id, name, website, shopify_store, user_id")
            if not force_all:
                threshold_str = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat().replace('+00:00', 'Z')
                query = query.or_(f"last_scan_at.is.null,last_scan_at.lt.{threshold_str}")
            response = query.order("last_scan_at", desc=True, nullsfirst=True).limit(max_competitors).execute()
            self.logger.info(f"Found {len(response.data or [])} competitor(s) to scan (Max: {max_competitors})")
            return response.data or []
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
    
    def save_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
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
# 🧠 ELITE MARKET INTELLIGENCE ENGINE (v2.0 — Multi-Provider)
# ═══════════════════════════════════════════════════════════
# سلسلة المزودين لضمان عدم انقطاع التحليل:
# 1. Llama-3.3-70B-Instruct (الأقوى — عبر Fireworks/Together/SambaNova)
# 2. Qwen-2.5-72B-Instruct (احتياطي سريع — عبر HF Router)
# 3. القالب الاحتياطي (آخر مطاف)
# ═══════════════════════════════════════════════════════════
class MarketIntelligenceEngine:
    # قائمة المزودين (الترتيب = الأولوية)
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

    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]]):
        self.competitor = competitor
        self.products = products
        self.name = competitor.get('name', 'Unknown')
        self.logger = logging.getLogger('MarketIntelligence')
        self.hf_api_key = os.getenv("HF_API_KEY")

    def generate_all_insights(self) -> List[Dict[str, Any]]:
        return self._generate_advanced_insights()

    def _analyze_competitor_data(self) -> Dict[str, Any]:
        prices = [p.get("current_price", 0) for p in self.products if p.get("current_price")]
        if not prices:
            return {"error": "No pricing data available"}
        
        avg_price = sum(prices) / len(prices)
        median_price = sorted(prices)[len(prices)//2]
        
        budget_threshold = avg_price * 0.6
        premium_threshold = avg_price * 1.5
        
        budget_products = [p for p in prices if p < budget_threshold]
        mid_tier = [p for p in prices if budget_threshold <= p <= premium_threshold]
        premium_products = [p for p in prices if p > premium_threshold]
        
        sorted_products = sorted(self.products, key=lambda x: x.get("current_price", 0), reverse=True)
        
        # تحليل إضافي: كثافة الفئات (استنتاج من أسماء المنتجات إن وجدت)
        title_keywords = {}
        for p in self.products:
            title = str(p.get("title", "")).lower()
            for kw in ["shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock", "accessory"]:
                if kw in title:
                    title_keywords[kw] = title_keywords.get(kw, 0) + 1
        
        top_category = max(title_keywords.items(), key=lambda x: x[1])[0] if title_keywords else "general"
        
        return {
            "competitor_name": self.name,
            "total_products_scanned": len(self.products),
            "products_with_pricing": len(prices),
            "pricing_intelligence": {
                "average_price": round(avg_price, 2),
                "median_price": round(median_price, 2),
                "lowest_price": round(min(prices), 2),
                "highest_price": round(max(prices), 2),
                "price_spread": round(max(prices) - min(prices), 2),
                "price_coefficient_of_variation": round((sum((p - avg_price)**2 for p in prices)/len(prices))**0.5 / avg_price, 2) if avg_price > 0 else 0
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
            "top_category_dominance": top_category,
            "strategic_anchors": {
                "top_3_premium": [{"title": p.get("title", "")[:60], "price": round(p.get("current_price", 0), 2)} for p in sorted_products[:3]],
                "top_3_entry": [{"title": p.get("title", "")[:60], "price": round(p.get("current_price", 0), 2)} for p in sorted_products[-3:]]
            }
        }

    def _build_strategic_prompt(self, data: Dict[str, Any]) -> tuple:
        """إرجاع (system_prompt, user_prompt) المنفصلين — الصيغة الحديثة."""
        
        system_prompt = """You are an Elite E-commerce Market Strategist with 20+ years of experience at McKinsey, BCG, and Bain. You advise Fortune 500 brands on competitive warfare, pricing architecture, and category domination.

## YOUR MISSION
Generate exactly 6 BOARD-READY, highly actionable strategic insights that would make a CEO act within 48 hours.

## UNCOMPROMISING STANDARDS:
- Output ONLY valid JSON. No markdown, no commentary outside the JSON.
- Every 'summary' MUST cite hard data (exact prices, counts, percentages) from the intelligence report.
- Every 'ai_recommendation' MUST specify:
  * A concrete price point or price range (e.g., "$89-99")
  * An expected gross margin percentage (e.g., "55-65%")
  * A timeline in days/weeks (e.g., "launch in 45 days")
  * An inventory or unit target (e.g., "500 units initial run")
  * A clear KPI for success (e.g., "capture 8% of mid-premium segment in 90 days")
- 'severity' MUST be one of: "critical", "high", "medium", "low".

## OUTPUT SCHEMA:
{
  "insights": [
    {
      "type": "pricing_warfare" | "product_gap" | "competitive_threat" | "counter_move" | "market_timing" | "brand_positioning",
      "title": "Board-level headline (under 80 chars)",
      "summary": "Data-backed situation analysis (80-150 words)",
      "ai_recommendation": "Specific action plan with numbers (80-150 words)",
      "severity": "critical|high|medium|low"
    }
  ]
}"""

        user_prompt = f"""## COMPETITOR INTELLIGENCE REPORT — {data.get('competitor_name')}
Scan Date: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}

{json.dumps(data, indent=2, ensure_ascii=False)}

## YOUR DELIVERABLE — 6 STRATEGIC INSIGHTS (one per type):
1. "pricing_warfare" — How they architect price tiers, where their margin is richest, and where we can surgically undercut.
2. "product_gap" — A specific missing category, orphan price point, or feature void we can exploit with a new SKU.
3. "competitive_threat" — Their single strongest moat based on this data, and a concrete plan to neutralize it in 90 days.
4. "counter_move" — An aggressive, asymmetric go-to-market action we should launch in the next 45 days.
5. "market_timing" — Seasonal or cyclical timing insight: when to attack, when to hold, when to bundle.
6. "brand_positioning" — Emotional/brand territory they own vs. whitespace we can claim.

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
                        "max_tokens": 2500,
                        "temperature": 0.3,
                        "top_p": 0.9,
                    },
                    timeout=120
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
        
        # كل المزودين فشلوا
        return None

    def _parse_ai_response(self, text: str) -> List[Dict[str, Any]]:
        try:
            # تنظيف الرد من markdown fences
            text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.IGNORECASE).strip()
            text = re.sub(r'\s*```$', '', text).strip()
            
            start_idx = text.find('{')
            end_idx = text.rfind('}')
            if start_idx != -1 and end_idx != -1:
                text = text[start_idx:end_idx+1]
            
            ai_response = json.loads(text.strip())
            insights_data = ai_response.get('insights', [])
            
            if not insights_data:
                self.logger.warning("⚠️ AI returned empty insights array — using fallback")
                return self._generate_fallback_insights()
            
            insights = []
            valid_types = {"pricing_warfare", "product_gap", "competitive_threat", 
                          "counter_move", "market_timing", "brand_positioning"}
            
            for i, insight in enumerate(insights_data[:6]):
                insight_type = str(insight.get('type', 'general')).lower()
                if insight_type not in valid_types:
                    insight_type = "general"
                
                severity = str(insight.get('severity', 'medium')).lower()
                if severity not in {"critical", "high", "medium", "low"}:
                    severity = "medium"
                
                insights.append({
                    "competitor_id": self.competitor['id'],
                    "type": insight_type,
                    "title": str(insight.get('title', f'Strategic Insight #{i+1}')).strip()[:200],
                    "summary": str(insight.get('summary', '')).strip(),
                    "ai_recommendation": str(insight.get('ai_recommendation', '')).strip(),
                    "severity": severity,
                    "created_at": datetime.now(timezone.utc).isoformat()
                })
            
            self.logger.info(f"🤖 Generated {len(insights)} ELITE STRATEGIC insights")
            return insights
            
        except json.JSONDecodeError as e:
            self.logger.error(f"⚠️ JSON parse failed: {e}")
            self.logger.error(f"🔍 Raw AI Response snippet: '{text[:400]}...'")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"⚠️ Error parsing response: {e}")
            return self._generate_fallback_insights()

    @rate_limit(calls_per_minute=10)
    def _generate_advanced_insights(self) -> List[Dict[str, Any]]:
        try:
            print(f"\n📊 Analyzing market positioning for {self.name}...")
            analysis_data = self._analyze_competitor_data()
            
            if "error" in analysis_data:
                return self._generate_fallback_insights()
            
            system_prompt, user_prompt = self._build_strategic_prompt(analysis_data)
            
            print(f"\n🧠 Generating board-level strategic counter-moves...")
            print("⏳ Deep market analysis in progress (60-120 seconds)...")
            
            ai_text = self._call_ai_provider(system_prompt, user_prompt)
            
            if ai_text:
                return self._parse_ai_response(ai_text)
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
        
        if prices:
            avg_price = sum(prices) / len(prices)
            insights.append({
                "competitor_id": self.competitor['id'],
                "type": "pricing_warfare",
                "title": f"{self.name} — Baseline Pricing Intelligence",
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
    
    def scrape(self, url: str, platform: str = None, max_retries: int = 3) -> List[Dict[str, Any]]:
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
        print(f"{Colors.BOLD}Products Analyzed:{Colors.ENDC} {brief.get('products_with_pricing')} / {brief.get('total_products_scanned')}")
        print()
        
        pi = brief.get('pricing_intelligence', {})
        print(f"{Colors.OKGREEN}┌{'─'*78}{Colors.ENDC}")
        print(f"{Colors.OKGREEN}│{Colors.ENDC} {Colors.BOLD}PRICING INTELLIGENCE{Colors.ENDC}".ljust(80) + f"{Colors.OKGREEN}│{Colors.ENDC}")
        print(f"{Colors.OKGREEN}├{'─'*78}{Colors.ENDC}")
        print(f"{Colors.OKGREEN}│{Colors.ENDC} Average Price: ${pi.get('average_price', 0):.2f}  |  Median: ${pi.get('median_price', 0):.2f}")
        print(f"{Colors.OKGREEN}│{Colors.ENDC} Price Spread:  ${pi.get('lowest_price', 0):.2f}  to  ${pi.get('highest_price', 0):.2f}")
        print(f"{Colors.OKGREEN}└{'─'*78}┘{Colors.ENDC}")
        print()
        
        mp = brief.get('market_positioning', {})
        print(f"{Colors.BOLD}🎯 MARKET POSITIONING:{Colors.ENDC}")
        print(f"  {Colors.WARNING}Budget Segment:{Colors.ENDC} {mp.get('budget_segment', {}).get('count')} products ({mp.get('budget_segment', {}).get('percentage')}%)")
        print(f"  {Colors.OKCYAN}Mid-Tier Segment:{Colors.ENDC} {mp.get('mid_tier_segment', {}).get('count')} products ({mp.get('mid_tier_segment', {}).get('percentage')}%)")
        print(f"  {Colors.OKGREEN}Premium Segment:{Colors.ENDC} {mp.get('premium_segment', {}).get('count')} products ({mp.get('premium_segment', {}).get('percentage')}%)")
        print()
        
        print_header("🧠 AI STRATEGIC COUNTER-MOVES")
        for i, insight in enumerate(insights, 1):
            severity_color = Colors.WARNING if insight.get('severity') in ['critical', 'high'] else Colors.OKGREEN
            print(f"\n{Colors.OKCYAN}{'─'*80}{Colors.ENDC}")
            print(f"{Colors.BOLD}INSIGHT #{i} [{insight.get('type').upper()}] - Severity: {severity_color}{insight.get('severity').upper()}{Colors.ENDC}")
            print(f"{Colors.BOLD}Title:{Colors.ENDC} {insight.get('title')}")
            print(f"\n{Colors.OKBLUE}Situation Summary:{Colors.ENDC}")
            print(f"  {insight.get('summary')}")
            print(f"\n{Colors.OKGREEN}🎯 Strategic Counter-Move:{Colors.ENDC}")
            print(f"  {insight.get('ai_recommendation')}")
        
        print(f"\n{Colors.OKGREEN}{'═'*80}{Colors.ENDC}\n")

    def scan_competitor(self, competitor: Dict[str, Any], url: str) -> bool:
        competitor_name = competitor.get('name', 'Unknown')
        competitor_id = competitor.get('id')
        
        print(f"\n{'='*80}")
        print(f"🎯 Target Acquired: {competitor_name}")
        print(f"📍 URL: {url}")
        print(f"{'='*80}\n")
        
        try:
            products = self.scraper.scrape(url)
            if not products:
                print_warning(f"No products found for {competitor_name}")
                return False
            
            timestamp = datetime.now(timezone.utc).isoformat()
            cleaned_products = [self.scraper.clean_product_data(p, competitor_id, timestamp) for p in products]
            
            if self.db.upsert_products(cleaned_products) == 0:
                print_error("Failed to save products")
                return False
            
            intel_engine = MarketIntelligenceEngine(competitor, products)
            insights = intel_engine.generate_all_insights()
            
            brief = intel_engine._analyze_competitor_data()
            if "error" not in brief:
                self.display_intelligence_brief(brief, insights)
            
            if insights:
                self.db.save_insights(insights)
                print_success(f"Saved {len(insights)} strategic insights to database (Ready for Flutter & Email)")
            
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
            print(f"   • Strategic Insights Generated: {len(insights)}")
            
            return True
            
        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception("Scan failed:")
            return False
    
    def run_dynamic_mode(self, force_all: bool = False):
        print_info(" Running in DYNAMIC MODE")
        pending = self.db.get_pending_competitors(force_all=force_all)
        
        if not pending:
            print_success("✅ All competitors are up to date!")
            print_info("   Next auto-update in 24 hours")
            return
        
        print_info(f" Found {len(pending)} competitor(s) to scan\n")
        
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
        description="Velora — Competitive Market Intelligence Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py                          # Scan outdated competitors
  python main.py --force-all              # Force scan all competitors
  python main.py --continuous             # Run continuously (every 86400s)
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
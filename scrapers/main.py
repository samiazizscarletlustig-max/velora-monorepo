"""
🚀 Velora — Advanced Multi-Market Scraper & AI Analysis Engine
═══════════════════════════════════════════════════════════════
PRODUCTION VERSION — Perfectly Tuned for Groq Free Tier
Generates Enterprise-Grade Strategic Intelligence + Trend Analysis
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
# 🧠 SMART MODEL DETECTOR
# ═══════════════════════════════════════════════════════════
def get_best_available_groq_model(api_key: str) -> str:
    try:
        response = requests.get(
            "https://api.groq.com/openai/v1/models",
            headers={"Authorization": f"Bearer {api_key}"}
        )
        if response.status_code == 200:
            models = response.json().get("data", [])
            model_ids = [m["id"] for m in models]
            
            for preferred in ["openai/gpt-oss-20b", "qwen/qwen2.5-32b", "qwen/qwen3.6-27b"]:
                for m in model_ids:
                    if preferred in m:
                        return m
            
            for m in model_ids:
                if "qwen" in m.lower() or "llama-3" in m.lower():
                    return m
                    
            if model_ids:
                return model_ids[0]
                
    except Exception as e:
        logging.getLogger('VeloraScraper').warning(f"Could not fetch models: {e}")
    
    return "openai/gpt-oss-20b"

# ═══════════════════════════════════════════════════════════
# 🛡️ Rate Limiting
# ═════════════════════════════════════════════════════════
def rate_limit(calls_per_minute: int = 6):
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
# ══════════════════════════════════════════════════════════
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
    print(f"\n{Colors.HEADER}{'='*70}{Colors.ENDC}")
    print(f"{Colors.OKBLUE}🚀 Velora — Advanced Competitive Intelligence{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Perfectly Tuned for Groq Free Tier{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*70}{Colors.ENDC}\n")

def print_success(msg): print(f"{Colors.OKGREEN}✅ {msg}{Colors.ENDC}")
def print_error(msg): print(f"{Colors.FAIL}❌ {msg}{Colors.ENDC}")
def print_warning(msg): print(f"{Colors.WARNING}⚠️  {msg}{Colors.ENDC}")
def print_info(msg): print(f"{Colors.OKBLUE}ℹ️  {msg}{Colors.ENDC}")

# ═══════════════════════════════════════════════════════════
# 🔧 Configuration
# ══════════════════════════════════════════════════════════
class Config:
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        self.use_local_ollama = os.getenv("USE_LOCAL_OLLAMA", "false").lower() == "true"
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.scan_interval = int(os.getenv("SCAN_INTERVAL", "600"))
        self.max_retries = int(os.getenv("MAX_RETRIES", "3"))
        
    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials in .env")
            return False
        if not self.use_local_ollama and not self.groq_api_key:
            print_error("Missing GROQ_API_KEY in .env.")
            return False
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
            query = self.supabase.table("competitors").select("id, name, website, shopify_store, user_id")
            if not force_all:
                threshold_str = (datetime.now(timezone.utc) - timedelta(hours=6)).isoformat().replace('+00:00', 'Z')
                query = query.or_(f"last_scan_at.is.null,last_scan_at.lt.{threshold_str}")
            response = query.order("last_scan_at", desc=True, nullsfirst=True).limit(50).execute()
            self.logger.info(f"Found {len(response.data or [])} competitor(s) to scan")
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

# ══════════════════════════════════════════════════════════
# 🤖 ADVANCED AI INSIGHT GENERATOR (Perfectly Tuned)
# ══════════════════════════════════════════════════════════
class InsightGenerator:
    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]]):
        self.competitor = competitor
        self.products = products
        self.name = competitor.get('name', 'Unknown')
        self.logger = logging.getLogger('InsightGenerator')
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.active_model = get_best_available_groq_model(self.groq_api_key) if self.groq_api_key else "openai/gpt-oss-20b"
    
    def generate_all_insights(self) -> List[Dict[str, Any]]:
        return self._generate_advanced_insights()

    def _analyze_competitor_data(self) -> Dict[str, Any]:
        prices = [p.get("current_price", 0) for p in self.products if p.get("current_price")]
        if not prices:
            return {"error": "No pricing data available"}
        
        avg_price = sum(prices) / len(prices)
        budget_threshold = avg_price * 0.6
        premium_threshold = avg_price * 1.5
        
        budget_products = [p for p in prices if p < budget_threshold]
        mid_tier = [p for p in prices if budget_threshold <= p <= premium_threshold]
        premium_products = [p for p in prices if p > premium_threshold]
        
        sorted_products = sorted(self.products, key=lambda x: x.get("current_price", 0), reverse=True)
        
        return {
            "competitor_name": self.name,
            "total_products": len(self.products),
            "products_with_pricing": len(prices),
            "avg_price": round(avg_price, 2),
            "min_price": round(min(prices), 2),
            "max_price": round(max(prices), 2),
            "budget_count": len(budget_products),
            "mid_tier_count": len(mid_tier),
            "premium_count": len(premium_products),
            "top_3_expensive": [{"title": p.get("title", "")[:40], "price": round(p.get("current_price", 0), 2)} for p in sorted_products[:3]]
        }

    def _build_advanced_prompt(self, data: Dict[str, Any]) -> str:
        # ✅ تم تشديد قيود الطول بشكل أقصى لضمان عدم تجاوز 800 Token
        return f"""Analyze this e-commerce data and output exactly 2 short strategic insights as valid JSON.

DATA: {json.dumps(data, indent=2)}

RULES:
- Output ONLY valid JSON. No markdown, no text outside the JSON.
- STRICT LENGTH LIMIT: Max 15 words for 'summary' and Max 15 words for 'ai_recommendation'. BE EXTREMELY CONCISE.
- Include exact numbers from the data.

JSON FORMAT:
{{
  "insights": [
    {{
      "type": "pricing",
      "title": "Short Title",
      "summary": "Max 15 words with hard data.",
      "ai_recommendation": "Max 15 words actionable step.",
      "severity": "medium"
    }}
  ]
}}
"""

    def _parse_ai_response(self, text: str) -> List[Dict[str, Any]]:
        try:
            if not text or not text.strip():
                raise ValueError("AI returned an empty response")
                
            if text.startswith('```'):
                text = re.sub(r'^```(?:json)?\n', '', text).strip()
                text = re.sub(r'\n```$', '', text).strip()
            
            text = text.strip()
            ai_response = json.loads(text)
            insights_data = ai_response.get('insights', [])
            
            if not insights_data:
                return self._generate_fallback_insights()
            
            insights = []
            for i, insight in enumerate(insights_data[:2]):
                insights.append({
                    "competitor_id": self.competitor['id'],
                    "type": insight.get('type', 'general'),
                    "title": insight.get('title', f'Insight #{i+1}'),
                    "summary": insight.get('summary', '').strip(),
                    "ai_recommendation": insight.get('ai_recommendation', '').strip(),
                    "severity": insight.get('severity', 'medium').lower(),
                    "created_at": datetime.now(timezone.utc).isoformat()
                })
            
            self.logger.info(f"🤖 Generated {len(insights)} ENTERPRISE-GRADE AI insights")
            return insights
            
        except json.JSONDecodeError as e:
            self.logger.error(f"⚠️ JSON parse failed: {e}")
            self.logger.error(f"🔍 Raw AI Response: '{text[:300]}...'")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"⚠️ Error parsing response: {e}")
            return self._generate_fallback_insights()

    @rate_limit(calls_per_minute=6)
    def _generate_advanced_insights(self) -> List[Dict[str, Any]]:
        try:
            print(f"\n📊 Analyzing {len(self.products)} products from {self.name}...")
            analysis_data = self._analyze_competitor_data()
            
            if "error" in analysis_data:
                return self._generate_fallback_insights()
            
            prompt = self._build_advanced_prompt(analysis_data)
            
            if not self.groq_api_key:
                self.logger.error("❌ GROQ_API_KEY not found")
                return self._generate_fallback_insights()
            
            print(f"\n🚀 Generating insights with Groq (Model: {self.active_model})...")
            
            response = requests.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.groq_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": self.active_model,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.3,
                    "max_tokens": 800  # ✅ الرقم المثالي: أقل من حد 1000، وكافٍ لإنهاء JSON
                },
                timeout=30
            )
            
            if response.status_code != 200:
                raise Exception(f"Groq API Error {response.status_code}: {response.text}")
            
            groq_response = response.json()
            text = groq_response["choices"][0]["message"]["content"]
            
            return self._parse_ai_response(text)
            
        except requests.exceptions.ConnectionError:
            self.logger.error("❌ Cannot connect to Groq API.")
            return self._generate_fallback_insights()
        except requests.exceptions.Timeout:
            self.logger.error("❌ Groq API request timed out.")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"❌ AI generation failed: {e}")
            return self._generate_fallback_insights()

    def _generate_fallback_insights(self) -> List[Dict[str, Any]]:
        timestamp = datetime.now(timezone.utc).isoformat()
        prices = [p.get("current_price") for p in self.products if p.get("current_price")]
        insights = []
        
        if prices:
            avg_price = sum(prices) / len(prices)
            insights.append({
                "competitor_id": self.competitor['id'],
                "type": "pricing",
                "title": f"{self.name} — Pricing Analysis",
                "summary": f"Average price: ${avg_price:.2f} across {len(prices)} products.",
                "ai_recommendation": "Position core products within 10% of competitor average.",
                "severity": "medium",
                "created_at": timestamp
            })
        
        self.logger.info(f"⚠️ Generated {len(insights)} fallback insights")
        return insights

# ═══════════════════════════════════════════════════════════
# 🕷️ Scraper Engine
# ══════════════════════════════════════════════════════════
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
    
    def scan_competitor(self, competitor: Dict[str, Any], url: str) -> bool:
        competitor_name = competitor.get('name', 'Unknown')
        competitor_id = competitor.get('id')
        
        print(f"\n{'='*60}")
        print(f"🎯 Scanning: {competitor_name}")
        print(f"📍 URL: {url}")
        print(f"{'='*60}\n")
        
        try:
            products = self.scraper.scrape(url)
            if not products:
                print_warning(f"No products found for {competitor_name}")
                return False
            
            timestamp = datetime.now(timezone.utc).isoformat()
            cleaned_products = [
                self.scraper.clean_product_data(p, competitor_id, timestamp)
                for p in products
            ]
            
            if self.db.upsert_products(cleaned_products) == 0:
                print_error("Failed to save products")
                return False
            
            insight_gen = InsightGenerator(competitor, products)
            insights = insight_gen.generate_all_insights()
            if insights:
                self.db.save_insights(insights)
            
            try:
                print(f"\n📈 Analyzing price trends for {competitor_name}...")
                trend_analyzer = TrendAnalyzer(competitor_id, products)
                trend_data = trend_analyzer.analyze_price_trends()
                
                if "error" not in trend_data and trend_data.get("insights"):
                    self.db.save_trend_insights(trend_data["insights"])
                    print_success(f"Saved {len(trend_data['insights'])} trend insights")
                else:
                    print_warning("Not enough historical data for trend analysis yet.")
            except Exception as e:
                self.logger.error(f"Trend analysis failed: {e}")
            
            self.db.update_competitor_scan_time(competitor_id)
            
            print_success(f"✅ Completed scan for {competitor_name}")
            print(f"   • Products: {len(cleaned_products)}")
            print(f"   • AI Insights: {len(insights)}")
            
            return True
            
        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception("Scan failed:")
            return False
    
    def run_dynamic_mode(self, force_all: bool = False):
        print_info("🔄 Running in DYNAMIC MODE")
        pending = self.db.get_pending_competitors(force_all=force_all)
        
        if not pending:
            print_success("✅ All competitors are up to date!")
            print_info("   Next auto-update in 6 hours")
            return
        
        print_info(f"📋 Found {len(pending)} competitor(s) to scan\n")
        
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

# ═══════════════════════════════════════════════════════════
# 🎯 Main Entry Point
# ══════════════════════════════════════════════════════════
def main():
    parser = argparse.ArgumentParser(
        description="Velora — Advanced Competitive Intelligence Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py                          # Scan outdated competitors
  python main.py --force-all              # Force scan all competitors
  python main.py --continuous             # Run continuously (every 600s)
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
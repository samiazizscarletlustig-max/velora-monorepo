"""
🚀 Velora — Advanced Multi-Market Scraper & AI Analysis Engine
═══════════════════════════════════════════════════════════════
PRODUCTION VERSION — 100% FREE (Local Ollama AI)
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
from core.trend_analyzer import TrendAnalyzer  # ✅ NEW: Import Trend Analyzer

# ═══════════════════════════════════════════════════════════
# 🛡️ Rate Limiting (Protects AI APIs)
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
# 🎨 Color Codes for Terminal
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
    print(f"{Colors.OKCYAN}   Enterprise-Grade AI Analysis + Trend Tracking (100% Free){Colors.ENDC}")
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
        self.scan_interval = int(os.getenv("SCAN_INTERVAL", "600"))
        self.max_retries = int(os.getenv("MAX_RETRIES", "3"))
        
    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials in .env")
            return False
        if not self.use_local_ollama:
            print_warning("Add 'USE_LOCAL_OLLAMA=true' to .env for free AI")
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
            if not users.data: print_error("No users found. Please sign up first."); return None
            
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

    # ✅ NEW: Save Trend Insights specifically
    def save_trend_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
            formatted_insights = []
            for insight in insights:
                formatted_insights.append({
                    "competitor_id": insight.get("competitor_id"),
                    "type": "trend", # Explicitly mark as trend analysis
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
# 🤖 ADVANCED AI INSIGHT GENERATOR (Ollama Local)
# ══════════════════════════════════════════════════════════
class InsightGenerator:
    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]]):
        self.competitor = competitor
        self.products = products
        self.name = competitor.get('name', 'Unknown')
        self.logger = logging.getLogger('InsightGenerator')
    
    def generate_all_insights(self) -> List[Dict[str, Any]]:
        """Main entry point - generates advanced strategic insights"""
        return self._generate_advanced_insights()

    def _analyze_competitor_data(self) -> Dict[str, Any]:
        """Advanced data analysis with market segmentation"""
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
        
        price_ranges = {
            "under_10": len([p for p in prices if p < 10]),
            "10_to_25": len([p for p in prices if 10 <= p < 25]),
            "25_to_50": len([p for p in prices if 25 <= p < 50]),
            "50_to_100": len([p for p in prices if 50 <= p < 100]),
            "over_100": len([p for p in prices if p >= 100])
        }
        
        sorted_products = sorted(self.products, key=lambda x: x.get("current_price", 0), reverse=True)
        
        return {
            "competitor_name": self.name,
            "analysis_date": datetime.now().strftime("%Y-%m-%d"),
            "total_products_scanned": len(self.products),
            "products_with_pricing": len(prices),
            "pricing_statistics": {
                "average_price": round(avg_price, 2),
                "median_price": round(median_price, 2),
                "lowest_price": round(min(prices), 2),
                "highest_price": round(max(prices), 2),
                "price_spread": round(max(prices) - min(prices), 2)
            },
            "market_segmentation": {
                "budget": {
                    "count": len(budget_products),
                    "percentage": round(len(budget_products)/len(prices)*100, 1),
                    "avg_price": round(sum(budget_products)/len(budget_products), 2) if budget_products else 0,
                    "threshold": f"Below ${round(budget_threshold, 2)}"
                },
                "mid_tier": {
                    "count": len(mid_tier),
                    "percentage": round(len(mid_tier)/len(prices)*100, 1),
                    "avg_price": round(sum(mid_tier)/len(mid_tier), 2) if mid_tier else 0,
                    "range": f"${round(budget_threshold, 2)} - ${round(premium_threshold, 2)}"
                },
                "premium": {
                    "count": len(premium_products),
                    "percentage": round(len(premium_products)/len(prices)*100, 1),
                    "avg_price": round(sum(premium_products)/len(premium_products), 2) if premium_products else 0,
                    "threshold": f"Above ${round(premium_threshold, 2)}"
                }
            },
            "price_distribution": price_ranges,
            "top_10_most_expensive": [
                {"title": p.get("title", "")[:80], "price": round(p.get("current_price", 0), 2)}
                for p in sorted_products[:10]
            ],
            "top_10_least_expensive": [
                {"title": p.get("title", "")[:80], "price": round(p.get("current_price", 0), 2)}
                for p in sorted_products[-10:]
            ],
            "strategic_observations": self._generate_observations(budget_products, mid_tier, premium_products, avg_price)
        }

    def _generate_observations(self, budget: List, mid: List, premium: List, avg: float) -> List[str]:
        observations = []
        if len(budget) > len(premium) * 2:
            observations.append(f"Strong focus on budget segment ({len(budget)} products vs {len(premium)} premium)")
        if len(premium) > len(budget):
            observations.append("Premium positioning strategy detected")
        if avg < 20:
            observations.append("Ultra-competitive pricing strategy (avg under $20)")
        elif avg > 100:
            observations.append("Luxury market positioning (avg over $100)")
        return observations

    def _build_advanced_prompt(self, data: Dict[str, Any]) -> str:
        return f"""You are a Chief Strategy Officer with 20+ years at McKinsey & BCG, specializing in e-commerce competitive intelligence.

## COMPETITOR ANALYSIS DATA
{json.dumps(data, indent=2)}

## YOUR TASK
Generate exactly 4 BOARD-READY strategic insights that will help our e-commerce business dominate the market.

## REQUIREMENTS FOR EACH INSIGHT
### 1. Type: "pricing", "opportunity", "threat", or "portfolio"
### 2. Title: Executive-level, max 10 words.
### 3. Summary: 2-3 sentences with HARD DATA (percentages, counts, price points). Use '-' for bullets.
### 4. AI Recommendation: 4-6 SPECIFIC steps (exact prices, 40-60% margins, 30/60/90 day timelines, inventory levels). Use '-' for bullets.
### 5. Severity: "critical", "high", "medium", or "low"

## OUTPUT FORMAT (ONLY valid JSON):
{{
  "insights": [
    {{
      "type": "pricing",
      "title": "Budget Segment Dominance Opportunity",
      "summary": "- 142 products (57%) priced below $15\\n- Avg budget product: $11.50",
      "ai_recommendation": "- Launch entry-level at $12.99 (45% margin)\\n- Timeline: 60-90 days",
      "severity": "high"
    }}
  ]
}}
"""

    def _parse_ai_response(self, text: str) -> List[Dict[str, Any]]:
        try:
            if text.startswith('```'):
                text = re.sub(r'^```(?:json)?\n', '', text).strip()
                text = re.sub(r'\n```$', '', text).strip()
            
            text = text.strip()
            ai_response = json.loads(text)
            insights_data = ai_response.get('insights', [])
            
            if not insights_data:
                return self._generate_fallback_insights()
            
            insights = []
            for i, insight in enumerate(insights_data[:4]):
                insights.append({
                    "competitor_id": self.competitor['id'],
                    "type": insight.get('type', 'general'),
                    "title": insight.get('title', f'Strategic Insight #{i+1}'),
                    "summary": insight.get('summary', '').strip(),
                    "ai_recommendation": insight.get('ai_recommendation', '').strip(),
                    "severity": insight.get('severity', 'medium').lower(),
                    "created_at": datetime.now(timezone.utc).isoformat()
                })
            
            self.logger.info(f"🤖 Generated {len(insights)} ENTERPRISE-GRADE AI insights")
            return insights
            
        except json.JSONDecodeError as e:
            self.logger.error(f"⚠️ JSON parse failed: {e}")
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
            
            print(f"\n🚀 Generating strategic insights with Local AI (llama3.2)...")
            print("⏳ Please wait, this may take a few minutes for deep analysis...")
            
            response = requests.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "llama3.2",
                    "prompt": prompt,
                    "stream": False,
                    "options": {"temperature": 0.7, "top_p": 0.9, "num_predict": 2048}
                },
                timeout=600
            )
            
            if response.status_code != 200:
                raise Exception(f"Ollama Error {response.status_code}: {response.text}")
            
            return self._parse_ai_response(response.json()["response"])
            
        except requests.exceptions.ConnectionError:
            self.logger.error("❌ Cannot connect to Ollama. Start with: ollama serve")
            return self._generate_fallback_insights()
        except requests.exceptions.Timeout:
            self.logger.error("❌ Ollama request timed out. Try lighter model like 'phi3'")
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
            # Step 1: Scrape products
            products = self.scraper.scrape(url)
            if not products:
                print_warning(f"No products found for {competitor_name}")
                return False
            
            # Step 2: Save to database
            timestamp = datetime.now(timezone.utc).isoformat()
            cleaned_products = [
                self.scraper.clean_product_data(p, competitor_id, timestamp)
                for p in products
            ]
            
            if self.db.upsert_products(cleaned_products) == 0:
                print_error("Failed to save products")
                return False
            
            # Step 3: Generate AI insights
            insight_gen = InsightGenerator(competitor, products)
            insights = insight_gen.generate_all_insights()
            if insights:
                self.db.save_insights(insights)
            
            # ✅ Step 3.5: NEW - Analyze and Save Price Trends
            try:
                print(f"\n📈 Analyzing price trends for {competitor_name}...")
                trend_analyzer = TrendAnalyzer(competitor_id, products)
                trend_data = trend_analyzer.analyze_price_trends()
                
                if "error" not in trend_data and trend_data.get("insights"):
                    self.db.save_trend_insights(trend_data["insights"])
                    print_success(f"Saved {len(trend_data['insights'])} trend insights")
                else:
                    print_warning("Not enough historical data for trend analysis yet (will build up over time).")
            except Exception as e:
                self.logger.error(f"Trend analysis failed: {e}")
            
            # Step 4: Update timestamp
            self.db.update_competitor_scan_time(competitor_id)
            
            # Step 5: Report results
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
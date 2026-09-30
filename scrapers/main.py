"""
Velora - Advanced Competitive Market Intelligence Engine
=========================================================
PRODUCTION VERSION v3.9.0 - Groq API with Bulletproof Response Parser

[OK] Cloud-Powered (Groq API only)
[OK] Dynamic Groq model resolver with real probe testing
[OK] Robust response extraction for standard, reasoning, and OSS-style models
[OK] Tier-Aware Scanning (Free / Pro / Pro Plus / Enterprise)
[OK] Price History Tracking & Strict Rate Limiting
[OK] AI Insights Lifecycle Managed (No Accumulation Bug)
[OK] Historical Deltas Computed (Proves Active Monitoring)
[OK] Token Optimization (No Duplicate Headline Stats)
[OK] STRICT TIER ENFORCEMENT: Explicit logging for all skip/scan decisions
[OK] API KEY FORMAT: Requires valid Groq API key (starts with 'gsk_')

Architecture:
  [GitHub Actions] -> [Scraper] -> [AI Analysis (Groq)] -> [Supabase] -> [Flutter App]
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

# ===================================================================
# TIER SYSTEM - Strict limits for each subscription tier
# ===================================================================
TIER_LIMITS = {
    'free':       {'max_competitors': 3,    'scan_interval_hours': 24, 'max_products': 300,  'ai_depth': 'scientific', 'ai_tokens': 4000},
    'pro':        {'max_competitors': 10,   'scan_interval_hours': 6,  'max_products': 1000, 'ai_depth': 'executive',  'ai_tokens': 6000},
    'pro_plus':   {'max_competitors': 25,   'scan_interval_hours': 3,  'max_products': 2500, 'ai_depth': 'executive',  'ai_tokens': 6000},
    'enterprise': {'max_competitors': 9999, 'scan_interval_hours': 1,  'max_products': 9999, 'ai_depth': 'executive',  'ai_tokens': 6000},
}

# ===================================================================
# Rate Limiting
# ===================================================================
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

# Reduce noisy HTTP client logs
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

# ===================================================================
# Color Codes (ASCII only, no emojis)
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

def print_banner():
    print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.OKBLUE} Velora v3.9.0 - Groq API with Bulletproof Response Parser{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Surgical Precision - Zero Fluff - Active Monitoring Deltas{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")

def print_success(msg): print(f"{Colors.OKGREEN}[OK] {msg}{Colors.ENDC}")
def print_error(msg): print(f"{Colors.FAIL}[ERR] {msg}{Colors.ENDC}")
def print_warning(msg): print(f"{Colors.WARNING}[WARN] {msg}{Colors.ENDC}")
def print_info(msg): print(f"{Colors.OKBLUE}[INFO] {msg}{Colors.ENDC}")
def print_header(msg): print(f"\n{Colors.BOLD}{Colors.OKCYAN}{msg}{Colors.ENDC}")

# ===================================================================
# Configuration
# ===================================================================
class Config:
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.groq_model_override = os.getenv("GROQ_MODEL")
        self.scan_interval = int(os.getenv("SCAN_INTERVAL", "86400"))
        self.max_retries = int(os.getenv("MAX_RETRIES", "3"))
        
    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials in .env")
            return False

        if not self.groq_api_key:
            print_error("Missing GROQ_API_KEY in .env")
            return False

        if not self.groq_api_key.startswith("gsk_"):
            print_error("Invalid GROQ_API_KEY format. Groq keys must start with 'gsk_'.")
            return False

        if self.groq_model_override:
            print_info(f"[CLOUD] Using Groq API with manual model override: {self.groq_model_override}")
        else:
            print_info("[CLOUD] Using Groq API with automatic model resolver")

        return True

# ===================================================================
# Database Manager
# ===================================================================
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
    
    def get_or_create_competitor(self, url: str, user_id: str = None) -> Optional[Dict[str, Any]]:
        try:
            for check_url in [url, url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")]:
                response = self.supabase.table("competitors").select("id, name, website, user_id").eq("website", check_url).execute()
                if response.data:
                    return response.data[0]
            
            store_name = urlparse(url).netloc.replace('www.', '').split('.')[0].capitalize()
            
            if not user_id:
                result = self.supabase.auth.admin.list_users()
                if isinstance(result, dict):
                    users = result.get('users', [])
                else:
                    users = getattr(result, 'users', []) or []

                if not users:
                    print_error("No users found in auth.users.")
                    return None
                user_id = users[0]['id']
            
            response = self.supabase.table("competitors").insert({
                'name': store_name,
                'website': url,
                'user_id': user_id,
                'created_at': datetime.now(timezone.utc).isoformat()
            }).execute()

            if response.data:
                print_success(f"Created competitor: {store_name} for user {user_id}")
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
            
            if not history_rows:
                return 0
            
            try:
                self.supabase.table("price_history").insert(history_rows).execute()
                self.logger.info(f"Saved {len(history_rows)} price history records")
                return len(history_rows)
            except Exception as e:
                msg = str(e)
                if "price_history" in msg and "competitor_id" in msg:
                    self.logger.warning("price_history table/schema is broken or missing competitor_id. Run the Supabase SQL fix.")
                else:
                    self.logger.warning(f"price_history insert failed: {e}")
                return 0
        except Exception as e:
            self.logger.error(f"Failed to save price history: {e}")
            return 0

    def has_previous_price_history(self, competitor_id: str) -> bool:
        try:
            res = (
                self.supabase.table("price_history")
                .select("id")
                .eq("competitor_id", competitor_id)
                .limit(1)
                .execute()
            )
            return len(res.data or []) > 0
        except Exception:
            return False
    
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
            if not response.data:
                return None
            return {"previous_insights": response.data}
        except Exception as e:
            self.logger.warning(f"Could not fetch previous scan: {e}")
            return None
    
    def save_insights(self, insights: List[Dict[str, Any]], competitor_id: str = None) -> bool:
        try:
            comp_id = competitor_id or (insights[0].get('competitor_id') if insights else None)
            
            if comp_id:
                try:
                    self.supabase.table("ai_insights").delete().eq("competitor_id", comp_id).neq("type", "trend").execute()
                except Exception:
                    pass
            
            for insight in insights:
                if not insight.get('competitor_id'):
                    insight['competitor_id'] = comp_id
                if not insight.get('created_at'):
                    insight['created_at'] = datetime.now(timezone.utc).isoformat()
            
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
                    "severity": str(insight.get("severity", "medium")).lower(),
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

# ===================================================================
# DYNAMIC MARKET INTELLIGENCE ENGINE (v3.9.0)
# ===================================================================
class MarketIntelligenceEngine:
    PROVIDERS = [
        {
            "name": "Groq (Bulletproof)",
            "url": "https://api.groq.com/openai/v1/chat/completions",
            "type": "groq"
        }
    ]

    GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions"
    GROQ_MODELS_URL = "https://api.groq.com/openai/v1/models"
    _cached_groq_model: Optional[str] = None

    CATEGORY_KEYWORDS = [
        "shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock",
        "accessory", "sweater", "hoodie", "short", "skirt", "coat", "boot",
        "sandal", "sneaker", "scarf", "belt", "watch", "jewelry"
    ]
    PROMOTION_KEYWORDS = ["sale", "off", "discount", "limited", "new", "bestseller", "clearance"]

    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]], previous_scan: Optional[Dict[str, Any]] = None):
        self.competitor = competitor
        self.products = products
        self.previous_scan = previous_scan
        self.name = competitor.get('name', 'Unknown')
        self.tier = competitor.get('_tier', 'free')
        self.limits = competitor.get('_limits', TIER_LIMITS['free'])
        self.logger = logging.getLogger('MarketIntelligence')
        self.groq_api_key = os.getenv("GROQ_API_KEY")

    def generate_all_insights(self) -> List[Dict[str, Any]]:
        return self._generate_advanced_insights()

    # ===================================================================
    # ROBUST GROQ TRANSPORT / MODEL RESOLVER
    # ===================================================================
    def _is_non_chat_model(self, model_id: str) -> bool:
        """
        Exclude models that are usually not normal text/chat completion models
        or models that require special terms/access.
        """
        s = (model_id or "").lower()

        blocked_keywords = [
            "prompt",
            "guard",
            "safeguard",
            "embedding",
            "embed",
            "whisper",
            "tts",
            "stt",
            "audio",
            "speech",
            "voice",
            "orpheus",
            "vision",
            "image",
            "ocr",
            "rerank",
            "classifier",
        ]

        return any(keyword in s for keyword in blocked_keywords)

    def _coerce_text(self, value: Any) -> str:
        """
        Convert common Groq/OpenAI response content shapes to plain text.
        """
        if value is None:
            return ""

        if isinstance(value, str):
            return value.strip()

        if isinstance(value, list):
            parts = []
            for item in value:
                if isinstance(item, dict):
                    txt = item.get("text") or item.get("content") or item.get("value") or ""
                    parts.append(str(txt))
                else:
                    parts.append(str(item))
            return "".join(parts).strip()

        if isinstance(value, dict):
            return str(value.get("text") or value.get("content") or "").strip()

        return str(value).strip()

    def _extract_text_from_groq_response(self, data: Any) -> str:
        """
        Robustly extract text from Groq chat completion response.
        Handles:
        - choices[0].message.content
        - choices[0].message.reasoning_content
        - choices[0].message.reasoning
        - choices[0].text
        - content as list of parts
        """
        try:
            if not isinstance(data, dict):
                return ""

            choices = data.get("choices") or []
            if not isinstance(choices, list) or not choices:
                return ""

            first = choices[0]
            if not isinstance(first, dict):
                return ""

            message = first.get("message") or {}
            delta = first.get("delta") or {}

            candidates = []

            if isinstance(message, dict):
                candidates.extend([
                    message.get("content"),
                    message.get("reasoning_content"),
                    message.get("reasoning"),
                    message.get("text"),
                ])
            elif isinstance(message, str):
                candidates.append(message)

            if isinstance(delta, dict):
                candidates.extend([
                    delta.get("content"),
                    delta.get("reasoning_content"),
                    delta.get("reasoning"),
                    delta.get("text"),
                ])

            candidates.extend([
                first.get("text"),
                first.get("content"),
                data.get("content"),
                data.get("text"),
            ])

            for candidate in candidates:
                text = self._coerce_text(candidate)
                if text:
                    return text

            return ""

        except Exception:
            return ""

    def _build_groq_payload(
        self,
        model: str,
        system_prompt: str,
        user_prompt: str,
        max_tokens: int,
        mode: str
    ) -> Dict[str, Any]:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        if mode == "completion_tokens":
            return {
                "model": model,
                "messages": messages,
                "max_completion_tokens": max_tokens,
                "temperature": 0.3,
                "top_p": 0.9,
            }

        if mode == "temp1":
            return {
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": 1,
                "top_p": 1,
            }

        if mode == "minimal":
            return {
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
            }

        if mode == "user_only":
            return {
                "model": model,
                "messages": [
                    {"role": "user", "content": f"{system_prompt}\n\n{user_prompt}"}
                ],
                "max_tokens": max_tokens,
                "temperature": 0.3,
                "top_p": 0.9,
            }

        # standard
        return {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": 0.3,
            "top_p": 0.9,
        }

    def _post_groq_chat(
        self,
        model: str,
        system_prompt: str,
        user_prompt: str,
        max_tokens: int
    ) -> Optional[str]:
        """
        Send chat request to Groq and try multiple compatible payload modes.
        This is important because some Groq models reject temperature/top_p
        or require max_completion_tokens instead of max_tokens.
        """
        if not self.groq_api_key:
            self.logger.warning("No GROQ_API_KEY found.")
            return None

        # Reasoning/OSS-like models may consume tokens internally.
        effective_max_tokens = max_tokens
        model_lower = (model or "").lower()
        if any(token in model_lower for token in ["oss", "reason", "o1", "o3", "qwq"]):
            effective_max_tokens = max(max_tokens, 8192)

        modes = ["standard", "completion_tokens", "temp1", "minimal", "user_only"]
        last_debug = ""

        for mode in modes:
            try:
                payload = self._build_groq_payload(
                    model=model,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    max_tokens=effective_max_tokens,
                    mode=mode
                )

                response = requests.post(
                    self.GROQ_CHAT_URL,
                    headers={
                        "Authorization": f"Bearer {self.groq_api_key}",
                        "Content-Type": "application/json"
                    },
                    json=payload,
                    timeout=300
                )

                if response.status_code == 200:
                    try:
                        data = response.json()
                    except Exception:
                        data = {}

                    if isinstance(data, dict) and data.get("error"):
                        last_debug = f"{mode}: HTTP 200 but payload error: {str(data.get('error'))[:220]}"
                        continue

                    text = self._extract_text_from_groq_response(data)
                    if text:
                        print_success(f"  -> Groq model {model} responded via {mode} ({len(text)} chars)")
                        return text

                    debug = {
                        "top_keys": list(data.keys()) if isinstance(data, dict) else str(type(data))
                    }

                    if isinstance(data, dict) and data.get("choices"):
                        first_choice = data["choices"][0] if isinstance(data["choices"], list) and data["choices"] else {}
                        if isinstance(first_choice, dict):
                            debug["choice_keys"] = list(first_choice.keys())
                            msg = first_choice.get("message")
                            if isinstance(msg, dict):
                                debug["message_keys"] = list(msg.keys())
                                content = msg.get("content")
                                debug["content_type"] = str(type(content))

                    last_debug = f"{mode}: HTTP 200 but no extractable text. {debug}"

                else:
                    last_debug = f"{mode}: HTTP {response.status_code} {response.text[:220]}"

            except Exception as e:
                last_debug = f"{mode}: exception {str(e)[:180]}"

        self.logger.warning(f"  -> Groq model {model} failed all payload modes. Last debug: {last_debug}")
        return None

    def _probe_groq_chat_model(self, model_id: str) -> bool:
        """
        Send a tiny real request to verify this Groq model actually returns text.
        """
        text = self._post_groq_chat(
            model=model_id,
            system_prompt="You are a connectivity test assistant.",
            user_prompt="Reply with exactly: OK",
            max_tokens=256
        )
        return bool(text)

    def _get_groq_model_candidates(self) -> List[str]:
        """
        Build ordered candidate list:
        1. GROQ_MODEL from .env
        2. Preferred visible models
        3. All visible non-blocked models
        4. Preferred hardcoded models
        """
        candidates: List[str] = []
        seen = set()

        def add_model(model_id: Optional[str]):
            model_id = (model_id or "").strip()
            if not model_id:
                return
            if model_id in seen:
                return
            if self._is_non_chat_model(model_id):
                return
            candidates.append(model_id)
            seen.add(model_id)

        # 1. Manual override
        manual_model = os.getenv("GROQ_MODEL")
        add_model(manual_model)

        preferred = [
            "openai/gpt-oss-120b",
            "openai/gpt-oss-20b",
            "qwen/qwen3.8-27b",
            "allam-2-7b",
            "llama-3.3-70b-versatile",
            "llama-3.1-70b-versatile",
            "llama-3.1-8b-instant",
            "llama-3.2-3b-instruct",
            "llama-3.2-1b-instruct",
            "mixtral-8x7b-32768",
            "gemma2-9b-it",
        ]

        # 2. Fetch visible models for this API key
        visible_models: List[str] = []
        try:
            response = requests.get(
                self.GROQ_MODELS_URL,
                headers={
                    "Authorization": f"Bearer {self.groq_api_key}",
                    "Content-Type": "application/json"
                },
                timeout=45
            )

            if response.status_code == 200:
                models_data = response.json().get("data", [])
                visible_models = [
                    m.get("id") for m in models_data
                    if isinstance(m, dict) and m.get("id")
                ]
                print_info(f"[SMART] Groq returned {len(visible_models)} visible models")
            else:
                self.logger.warning(f"Could not list Groq models: {response.status_code} {response.text[:200]}")

        except Exception as e:
            self.logger.warning(f"Could not fetch Groq models dynamically: {e}")

        # 3. Preferred models that are actually visible
        for model_id in preferred:
            if model_id in visible_models:
                add_model(model_id)

        # 4. All visible non-blocked models
        for model_id in visible_models:
            add_model(model_id)

        # 5. Preferred hardcoded fallbacks
        for model_id in preferred:
            add_model(model_id)

        return candidates[:20]

    def _get_working_groq_model(self) -> str:
        """
        Probe candidates and cache the first model that truly returns text.
        """
        cached = MarketIntelligenceEngine._cached_groq_model
        if cached:
            print_info(f"[SMART] Using cached Groq chat model: {cached}")
            return cached

        candidates = self._get_groq_model_candidates()

        if not candidates:
            print_error("❌ CRITICAL: No usable Groq chat model candidates found.")
            sys.exit(1)

        for model_id in candidates:
            print_info(f"[PROBE] Testing Groq model: {model_id}")
            if self._probe_groq_chat_model(model_id):
                MarketIntelligenceEngine._cached_groq_model = model_id
                print_success(f"[SMART] Working Groq chat model selected: {model_id}")
                return model_id
            time.sleep(1)

        print_warning("[WARN] All Groq model probes failed. Returning first candidate for final attempt.")
        first = candidates[0]
        MarketIntelligenceEngine._cached_groq_model = first
        return first

    def _call_ai_provider(self, system_prompt: str, user_prompt: str, max_tokens: int) -> Optional[str]:
        """
        Final Groq caller:
        - validates key
        - resolves working model
        - tries multiple models if the first one fails on the real prompt
        """
        if not self.groq_api_key:
            self.logger.warning("No GROQ_API_KEY found in .env")
            return None

        if not self.groq_api_key.startswith("gsk_"):
            print_error("❌ CRITICAL ERROR: Invalid GROQ_API_KEY!")
            print_error(f"Your key starts with: '{self.groq_api_key[:5]}...'")
            print_error("Groq keys MUST start with 'gsk_'.")
            print_error("Please go to https://console.groq.com/keys and create a NEW Groq API key.")
            sys.exit(1)

        working_model = self._get_working_groq_model()
        candidates = self._get_groq_model_candidates()

        models_to_try: List[str] = []
        seen = set()

        for model_id in [working_model] + candidates:
            if model_id and model_id not in seen:
                seen.add(model_id)
                models_to_try.append(model_id)

        for model_id in models_to_try[:8]:
            print_info(f"Attempting to use chat model: {model_id}")
            text = self._post_groq_chat(
                model=model_id,
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                max_tokens=max_tokens
            )

            if text:
                MarketIntelligenceEngine._cached_groq_model = model_id
                return text

        return None

    def _analyze_competitor_data(self) -> Dict[str, Any]:
        prices = [p.get("current_price", 0) for p in self.products if p.get("current_price") and p.get("current_price") > 0]
        if not prices:
            return {"error": "No pricing data available"}
        
        avg_price = sum(prices) / len(prices)
        median_price = statistics.median(prices)
        try:
            stdev_price = statistics.stdev(prices) if len(prices) > 1 else 0
        except Exception:
            stdev_price = 0
        
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
                if kw in title:
                    category_counts[kw] += 1
            for promo in self.PROMOTION_KEYWORDS:
                if promo in title:
                    promotion_count += 1
                    break
        
        top_categories = category_counts.most_common(5)
        
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
                "average_price": round(avg_price, 2),
                "median_price": round(median_price, 2),
                "standard_deviation": round(stdev_price, 2),
                "lowest_price": round(min(prices), 2),
                "highest_price": round(max(prices), 2),
                "price_spread": round(max(prices) - min(prices), 2),
                "price_coefficient_of_variation": cov,
                "cov_interpretation": cov_interp
            },
            "market_positioning": {
                "budget_segment": {"count": len(budget_products), "percentage": round(len(budget_products)/len(prices)*100, 1)},
                "mid_tier_segment": {"count": len(mid_tier), "percentage": round(len(mid_tier)/len(prices)*100, 1)},
                "premium_segment": {"count": len(premium_products), "percentage": round(len(premium_products)/len(prices)*100, 1)}
            },
            "category_intelligence": {
                "top_5_categories": [{"category": k, "count": v} for k, v in top_categories], 
                "hhi_index": hhi_score,
                "hhi_interpretation": hhi_interp
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
        STYLE GUIDANCE (best practice, not a hard failure condition): Prefer specific, data-grounded
        language over generic filler like "focus on quality", "improve marketing", "stand out from
        competitors", "consider offering", "it may be beneficial", "in today's market", "leverage your
        strengths". These phrases aren't banned outright - but analysis that leans on real numbers,
        percentages, and dollar figures instead of these phrases will always read stronger.
        DEPTH OVER RIGIDITY: Ground the analysis in the data provided and cite concrete figures where
        they strengthen the argument, but do not force a number into every single sentence - let the
        reasoning breathe and connect ideas naturally, the way a sharp human strategist would write.
        VOICE: Prefer confident, decisive language ("Launch", "Price at", "Cut", "Target") over hedging
        ("could", "might", "consider") whenever the data supports a strong claim - but natural
        transitional language ("this suggests", "as a result") is fine and expected in flowing prose.
        """

        previous_context = ""
        if self.previous_scan and self.previous_scan.get("previous_insights"):
            prev_insights = self.previous_scan["previous_insights"]
            prev_summary = " | ".join([f"{i.get('title', 'Insight')}" for i in prev_insights[:3]])
            previous_context = f"\nPREVIOUS SCAN CONTEXT: Last scan noted: {prev_summary}. \nCRITICAL INSTRUCTION: Compare current data with previous scan. Highlight specific deltas (e.g., 'Average price rose $X since last scan', 'New category emerged'). This proves active monitoring, not just snapshotting."

        if self.tier == 'free':
            system_prompt = f"""You are a SENIOR E-COMMERCE MARKET ANALYST. Data scientist who talks like a founder's smartest friend. Precise, insightful, zero corporate hedging.

YOUR MISSION: Provide exactly 4 DEEP, SCIENTIFIC, DATA-DRIVEN strategic insights in this EXACT order. Provide deep, nuanced analysis with specific examples and strategic context - don't just state a number, explain what it means and why it matters:
1. Price Gap Exploitation (product_gap): Identify 1-2 specific dollar ranges where competitor has ZERO products.
2. Category Concentration Risk (category_dominance): Use HHI index to show where they are strong but exposed.
3. Promotional Behavior Signal (competitive_threat): High promo % = inventory stress. Low promo % = pricing confidence.
4. Positioning Verdict (pricing_warfare): Budget/mid/premium split + CoV verdict.

{forbidden_rules}

LENGTH: Each insight's "summary" and "ai_recommendation" should each run 150-200 words - long enough to develop real reasoning, not a one-line verdict.

UPGRADE TRIGGER: End the ai_recommendation of the 4th insight with a dangling thread: "The optimal entry price for this gap is calculable from margin data - Pro users get the exact price point and unit target."

OUTPUT FORMAT (JSON only):
{{
  "executive_summary": "3-sentence overview: market position, top category with data, primary vulnerability",
  "insights": [
    {{
      "type": "product_gap|category_dominance|competitive_threat|pricing_warfare",
      "title": "Professional 6-8 word headline",
      "summary": "Scientific observation with specific data points and strategic context (150-200 words)",
      "ai_recommendation": "Exact tactical move: Launch X products in Y category at $Z price within 30 days, with reasoning (150-200 words)",
      "severity": "high|medium|low"
    }}
  ]
}}"""
            
            data_for_json = {k: v for k, v in data.items() if k != 'headline_stats'}
            user_prompt = f"""{data.get('headline_stats')}{previous_context}

Think like a $10M/year e-commerce consultant advising a client - not a bot filling in a template.
Great analysis connects the dots between data points (e.g., a high promo percentage combined with a
diversified catalog tells a different story than the same promo percentage on a highly concentrated
one) and explains the "so what," not just the "what."

Analyze this competitor data and provide 4 deep, scientific insights.
Competitor: {data.get('competitor_name')}
Products Analyzed: {data.get('products_with_pricing')}
Avg Price: ${data.get('pricing_intelligence', {}).get('average_price', 0):.2f}

Full Data:
{json.dumps(data_for_json, indent=2)}
"""
            max_tokens = self.limits['ai_tokens']

        else:
            system_prompt = f"""You are a CHIEF STRATEGY OFFICER (CSO) and former McKinsey Partner specializing in D2C/E-commerce.

YOUR MISSION: Generate a BOARD-READY strategic intelligence dossier with EXECUTABLE financial blueprints. Think like a $10M/year e-commerce consultant writing for a client who is paying a premium for genuine depth, not a template filled with numbers.

{forbidden_rules}

PER-INSIGHT DEPTH: Each insight must include competitive context, relevant market trends, specific data points from the report, and actionable recommendations with concrete timelines. Each "summary" and "ai_recommendation" should run 200-300 words - long enough to build a real argument.

CROSS-REFERENCE: Where it strengthens the thesis, reference another insight in this report by name (e.g., "As noted in the Price Gap insight..."), so the report reads like one connected strategic narrative. Don't force this in every insight - only where it's a natural, genuine connection.

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
      "summary": "Data-backed situation analysis with competitive context and market trends (200-300 words)",
      "ai_recommendation": "Executable plan with financial metrics and timelines (200-300 words)",
      "severity": "critical|high|medium|low"
    }}
  ],
  "financial_execution_blueprint": "2-3 detailed paragraphs with specific metrics covering: exact product to launch, target price range, target gross margin %, initial unit count, days-to-execute breakdown, and one clear success KPI with the math shown.",
  "quick_wins": ["Actionable step executable within 7 days with expected impact", "...", "...", "...", "..."],
  "strategic_timeline": {{
    "30_days": "Specific milestone with a measurable target",
    "60_days": "Specific milestone with a measurable target",
    "90_days": "Specific milestone with a measurable target"
  }},
  "risk_assessment": "2-3 sentences on the biggest strategic risks if we fail to respond in 30 days, with a timeline."
}}"""
            
            data_for_json = {k: v for k, v in data.items() if k != 'headline_stats'}
            user_prompt = f"""{data.get('headline_stats')}{previous_context}

Think like a $10M/year e-commerce consultant advising a client on a six-figure retainer. The bar is:
every paragraph should teach the reader something they didn't already know from glancing at the raw
numbers - connect data points together, explain competitive implications, and give recommendations
specific enough that someone could execute them without asking a follow-up question.

## COMPETITOR INTELLIGENCE REPORT - {data.get('competitor_name')}
Tier: {data.get('tier_context').upper()}
Scan Date: {data.get('scan_date')}

Full Data:
{json.dumps(data_for_json, indent=2)}

## DELIVERABLE - 8 STRATEGIC INSIGHTS:
1. Pricing warfare  2. Product gap  3. Competitive threat  4. Counter-move
5. Market timing  6. Brand positioning  7. Customer psychology  8. Supply chain signal

Return ONLY valid JSON."""
            max_tokens = self.limits['ai_tokens']

        return system_prompt, user_prompt, max_tokens

    def _parse_ai_response(self, text: str, analysis_data: Dict) -> List[Dict[str, Any]]:
        try:
            text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.IGNORECASE).strip()
            text = re.sub(r'\s*```$', '', text).strip()
            start_idx, end_idx = text.find('{'), text.rfind('}')
            if start_idx != -1 and end_idx != -1:
                text = text[start_idx:end_idx+1]
            
            ai_response = json.loads(text.strip())
            if not isinstance(ai_response, dict):
                raise ValueError("AI response is not a JSON object")

            insights = []
            timestamp = datetime.now(timezone.utc).isoformat()
            comp_id = self.competitor.get('id')
            valid_types = {
                "pricing_warfare", "product_gap", "competitive_threat", "counter_move",
                "market_timing", "brand_positioning", "customer_psychology",
                "supply_chain_signal", "category_dominance"
            }
            
            raw_insights = ai_response.get('insights', [])
            if isinstance(raw_insights, dict):
                raw_insights = [raw_insights]
            if not isinstance(raw_insights, list):
                raw_insights = []

            has_numbers = any(
                re.search(r'\d', str(insight.get('ai_recommendation', '')) + str(insight.get('summary', '')))
                for insight in raw_insights
            )
            if not has_numbers and len(raw_insights) > 0:
                self.logger.warning("[WARN] AI response has few/no numeric data points - using it anyway.")
            
            if self.tier == 'free':
                exec_summary = ai_response.get('executive_summary', '')
                if exec_summary:
                    insights.append({
                        "competitor_id": comp_id,
                        "type": "executive_summary",
                        "title": "Market Overview",
                        "summary": str(exec_summary).strip(),
                        "ai_recommendation": "Review insights below. Upgrade to Pro for detailed financial projections, unit targets, and execution timelines.",
                        "severity": "medium",
                        "created_at": timestamp
                    })
                
                for i, insight in enumerate(raw_insights[:4]):
                    if not isinstance(insight, dict):
                        continue
                    severity = str(insight.get('severity', 'medium')).lower()
                    if severity not in {"critical", "high", "medium", "low"}:
                        severity = "medium"
                    insights.append({
                        "competitor_id": comp_id,
                        "type": str(insight.get('type', 'general')).lower(),
                        "title": str(insight.get('title', f'Insight #{i+1}')).strip()[:200],
                        "summary": str(insight.get('summary', '')).strip(),
                        "ai_recommendation": str(insight.get('ai_recommendation', '')).strip(),
                        "severity": severity,
                        "created_at": timestamp
                    })
            else:
                exec_summary = ai_response.get('executive_summary', '')
                if exec_summary:
                    insights.append({
                        "competitor_id": comp_id,
                        "type": "executive_summary",
                        "title": "Executive Briefing",
                        "summary": str(exec_summary).strip(),
                        "ai_recommendation": "Review the full strategic package below and prioritize the top 2 quick wins.",
                        "severity": "high",
                        "created_at": timestamp
                    })
                
                scorecard = ai_response.get('competitive_scorecard', {})
                if scorecard and isinstance(scorecard, dict):
                    scorecard_text = " | ".join([
                        f"{k.replace('_', ' ').title()}: {v.get('score', 0)}/10 - {str(v.get('rationale', ''))[:100]}"
                        for k, v in scorecard.items() if isinstance(v, dict)
                    ])
                    insights.append({
                        "competitor_id": comp_id,
                        "type": "scorecard",
                        "title": "Competitive Scorecard",
                        "summary": scorecard_text,
                        "ai_recommendation": "Focus on the lowest-scoring area for immediate competitive advantage.",
                        "severity": "medium",
                        "created_at": timestamp
                    })
                
                for i, insight in enumerate(raw_insights[:8]):
                    if not isinstance(insight, dict):
                        continue
                    insight_type = str(insight.get('type', 'general')).lower()
                    if insight_type not in valid_types:
                        insight_type = "general"
                    severity = str(insight.get('severity', 'medium')).lower()
                    if severity not in {"critical", "high", "medium", "low"}:
                        severity = "medium"
                    insights.append({
                        "competitor_id": comp_id,
                        "type": insight_type,
                        "title": str(insight.get('title', f'Insight #{i+1}')).strip()[:200],
                        "summary": str(insight.get('summary', '')).strip(),
                        "ai_recommendation": str(insight.get('ai_recommendation', '')).strip(),
                        "severity": severity,
                        "created_at": timestamp
                    })
                
                financial_blueprint = ai_response.get('financial_execution_blueprint', '')
                if financial_blueprint:
                    insights.append({
                        "competitor_id": comp_id,
                        "type": "financial_blueprint",
                        "title": "Financial Execution Blueprint",
                        "summary": "Detailed rollout plan",
                        "ai_recommendation": str(financial_blueprint).strip(),
                        "severity": "critical",
                        "created_at": timestamp
                    })
                
                quick_wins = ai_response.get('quick_wins', [])
                if quick_wins and isinstance(quick_wins, list):
                    insights.append({
                        "competitor_id": comp_id,
                        "type": "quick_wins",
                        "title": "Quick Wins (Execute in 7 Days)",
                        "summary": "\n".join([f"- {w}" for w in quick_wins[:5]]),
                        "ai_recommendation": "Assign these to your growth team immediately.",
                        "severity": "high",
                        "created_at": timestamp
                    })
                
                strategic_timeline = ai_response.get('strategic_timeline', {})
                if strategic_timeline and isinstance(strategic_timeline, dict):
                    timeline_text = "\n".join([
                        f"- {label.replace('_', ' ').title()}: {milestone}"
                        for label, milestone in strategic_timeline.items() if milestone
                    ])
                    if timeline_text:
                        insights.append({
                            "competitor_id": comp_id,
                            "type": "strategic_timeline",
                            "title": "Strategic Timeline (30-60-90 Day)",
                            "summary": timeline_text,
                            "ai_recommendation": "Assign an owner and a check-in date to each milestone above.",
                            "severity": "medium",
                            "created_at": timestamp
                        })
                
                risk = ai_response.get('risk_assessment', '')
                if risk:
                    insights.append({
                        "competitor_id": comp_id,
                        "type": "risk_assessment",
                        "title": "Risk Assessment",
                        "summary": str(risk).strip(),
                        "ai_recommendation": "Treat this as a 30-day warning window. Begin mitigation immediately.",
                        "severity": "high",
                        "created_at": timestamp
                    })
            
            self.logger.info(f"[AI] Generated {len(insights)} insights for tier: {self.tier}")
            return insights
        except json.JSONDecodeError as e:
            self.logger.error(f"[WARN] JSON parse failed: {e}")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"[WARN] Error parsing response: {e}")
            return self._generate_fallback_insights()

    @rate_limit(calls_per_minute=8)
    def _generate_advanced_insights(self) -> List[Dict[str, Any]]:
        try:
            print(f"\n[ANALYZE] Analyzing market positioning for {self.name} (tier: {self.tier})...")
            analysis_data = self._analyze_competitor_data()
            if "error" in analysis_data:
                return self._generate_fallback_insights()
            
            system_prompt, user_prompt, max_tokens = self._build_strategic_prompt(analysis_data)
            print(f"\n[AI] Generating {self.tier.upper()} strategic package...")
            print("[WAIT] Deep market analysis in progress...")
            
            ai_text = self._call_ai_provider(system_prompt, user_prompt, max_tokens)
            if ai_text:
                return self._parse_ai_response(ai_text, analysis_data)
            
            self.logger.warning("[WARN] All AI providers failed - using fallback template")
            return self._generate_fallback_insights()
        except Exception as e:
            self.logger.error(f"[ERR] AI generation failed: {e}")
            return self._generate_fallback_insights()

    def _generate_fallback_insights(self) -> List[Dict[str, Any]]:
        timestamp = datetime.now(timezone.utc).isoformat()
        prices = [p.get("current_price") for p in self.products if p.get("current_price")]
        insights = []
        comp_id = self.competitor.get('id')
        
        if prices:
            avg_price = sum(prices) / len(prices)
            summary = f"Scanned {len(self.products)} products from {self.name}. Average price: ${avg_price:.2f} across {len(prices)} priced items."
        else:
            avg_price = 0
            summary = f"Scanned {len(self.products)} products from {self.name}. No priced items were detected in this scan."

        insights.append({
            "competitor_id": comp_id,
            "type": "executive_summary",
            "title": "Executive Briefing (Baseline)",
            "summary": summary,
            "ai_recommendation": "AI providers were temporarily unavailable or returned incompatible formats. Baseline analysis generated. Re-scan later for full strategic package.",
            "severity": "medium",
            "created_at": timestamp
        })
        
        if prices:
            insights.append({
                "competitor_id": comp_id,
                "type": "pricing_warfare",
                "title": "Baseline Pricing Intelligence",
                "summary": f"Average market price: ${avg_price:.2f} across {len(prices)} products. Range: ${min(prices):.2f} to ${max(prices):.2f}.",
                "ai_recommendation": "Position core competing products within 10% of this average to maintain market parity.",
                "severity": "medium",
                "created_at": timestamp
            })
        
        self.logger.info(f"[WARN] Generated {len(insights)} fallback insights")
        return insights

# ===================================================================
# Scraper Engine
# ===================================================================
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
                self.logger.info(f"[SCRAPE] Using {platform} scraper (attempt {attempt + 1}/{max_retries})...")
                products = asyncio.run(scraper_func(url)) if inspect.iscoroutinefunction(scraper_func) else scraper_func(url)

                if products and len(products) > 0:
                    if len(products) > max_products:
                        products = products[:max_products]
                        self.logger.info(f"[SKIP] Trimmed to {max_products} products (tier limit)")
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

# ===================================================================
# Main Application
# ===================================================================
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
        print_header("MARKET INTELLIGENCE BRIEFING")
        print(f"{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
        print(f"{Colors.BOLD}Target Competitor:{Colors.ENDC} {brief.get('competitor_name')}")
        print(f"{Colors.BOLD}Tier:{Colors.ENDC} {str(brief.get('tier_context', 'free')).upper()}")
        print(f"{Colors.BOLD}Products Analyzed:{Colors.ENDC} {brief.get('products_with_pricing')} / {brief.get('total_products_scanned')}")
        print()
        
        exec_insight = next((i for i in insights if i.get('type') == 'executive_summary'), None)
        if exec_insight:
            print(f"{Colors.BOLD}EXECUTIVE SUMMARY:{Colors.ENDC}\n  {exec_insight.get('summary')}\n")
        
        scorecard_insight = next((i for i in insights if i.get('type') == 'scorecard'), None)
        if scorecard_insight:
            print(f"{Colors.BOLD}COMPETITIVE SCORECARD:{Colors.ENDC}\n  {scorecard_insight.get('summary')}\n")
        
        strategic_types = {
            "pricing_warfare", "product_gap", "competitive_threat", "counter_move",
            "market_timing", "brand_positioning", "customer_psychology", "supply_chain_signal",
            "category_dominance", "financial_blueprint", "strategic_timeline", "quick_wins", "risk_assessment"
        }
        print_header("STRATEGIC INSIGHTS")
        for i, insight in enumerate(insights, 1):
            if insight.get('type') not in strategic_types:
                continue
            severity = str(insight.get('severity', 'medium')).upper()
            severity_color = Colors.WARNING if severity in ['CRITICAL', 'HIGH'] else Colors.OKGREEN
            print(f"\n{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
            print(f"{Colors.BOLD}INSIGHT #{i} [{str(insight.get('type', 'GENERAL')).upper()}] - Severity: {severity_color}{severity}{Colors.ENDC}")
            print(f"{Colors.BOLD}Title:{Colors.ENDC} {insight.get('title')}")
            print(f"\n{Colors.OKBLUE}Situation Summary:{Colors.ENDC}\n  {insight.get('summary')}")
            print(f"\n{Colors.OKGREEN}Strategic Counter-Move:{Colors.ENDC}\n  {insight.get('ai_recommendation')}")

        print(f"\n{Colors.OKGREEN}{'='*80}{Colors.ENDC}\n")

    def scan_competitor(self, competitor: Dict[str, Any], url: str) -> bool:
        competitor_name = competitor.get('name', 'Unknown')
        competitor_id = competitor.get('id')
        tier = competitor.get('_tier', 'free')
        limits = competitor.get('_limits', TIER_LIMITS['free'])
        
        print(f"\n{'='*80}")
        print(f"[TARGET] Target Acquired: {competitor_name}")
        print(f"[URL] {url}")
        print(f"[TIER] {tier.upper()} (max {limits['max_products']} products)")
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
            
            has_history = self.db.has_previous_price_history(competitor_id)
            self.db.save_price_history(cleaned_products, competitor_id)
            previous_scan = self.db.get_previous_scan_data(competitor_id)
            
            if has_history:
                try:
                    self.supabase.table("ai_insights").delete().eq("competitor_id", competitor_id).eq("type", "trend").execute()
                except Exception:
                    pass
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
                    self.logger.error(f"Trend analysis failed: {e}")
            else:
                print_info("[SKIP] First scan - skipping trend analysis (no price history yet)")
            
            intel_engine = MarketIntelligenceEngine(competitor, products, previous_scan)
            insights = intel_engine.generate_all_insights()
            
            brief = intel_engine._analyze_competitor_data()
            if "error" not in brief:
                self.display_intelligence_brief(brief, insights)
            
            if insights:
                self.db.save_insights(insights, competitor_id)
                print_success(f"Saved {len(insights)} strategic insights to database")
            
            self.db.update_competitor_scan_time(competitor_id)
            print_success(f"[DONE] Mission Complete: {competitor_name}")
            print(f"   - Products Mapped: {len(cleaned_products)}")
            print(f"   - Executive Insights Generated: {len(insights)}")
            return True
        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception("Scan failed:")
            return False
    
    def run_dynamic_mode(self, force_all: bool = False):
        print_info("Running in TIER-AWARE DYNAMIC MODE")
        pending = self.db.get_pending_competitors(force_all=force_all)
        if not pending:
            print_success("[DONE] All competitors are up to date!")
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
            print_info(f"[WAIT] Continuous mode: checking every {self.config.scan_interval}s")
            first_run = True
            try:
                while True:
                    self.run_dynamic_mode(force_all=(first_run and force_all))
                    first_run = False
                    time.sleep(self.config.scan_interval)
            except KeyboardInterrupt:
                print_info("\n[STOP] Continuous mode stopped by user")
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
        description="Velora v3.9.0 - Groq API with Bulletproof Response Parser",
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
"""
Velora - Advanced Competitive Market Intelligence Engine
=========================================================
PRODUCTION VERSION v5.0.0 - Logical Rigor + Portfolio Intelligence + Self-Test

100% DETERMINISTIC. Zero paid-AI calls. Zero new tables, columns, env vars or pip deps.

ARCHITECTURE
------------
  [GitHub Actions hourly] -> tier guard (free 24h / pro 6h / pro_plus 3h / enterprise 1h)
      -> ScraperEngine (frozen scraper contracts)
      -> classify_disappearance()   smart stockout guard: stockout | contraction | drift
      -> HistoryIndex               ONE tier-capped, paginated price_history load per scan
      -> PremiumDeterministicMarketIntelligenceEngine
            _analyze_data()  -> every number used in any insight string
            insight builders -> _mk() stamps confidence (0-1) + directive/hypothesis voice
            _enforce_tier_gate() -> server-side TYPE-based wall (the security boundary)
      -> DatabaseManager (writes ONLY frozen columns; rows without a real competitor_id are refused)
      -> Resend digests (SKIP_TYPES is the single source of truth)

WEIGHTED VULNERABILITY RUBRIC (replaces the flat bonus-sum of v4.5.0)
---------------------------------------------------------------------
  score = round( sum_i  weight_i * sub_i ),  sum(weight_i) = 100,  sub_i in [0,1]
  Factors: concentration 22 | pricing inconsistency 18 | promo rigidity 12 | ladder gaps 16 |
           bestseller dependence 8 | thin catalog 8 | delisting churn 16.
  Each factor exposes (weight, sub-score, points, justification) inside the paid
  'vulnerability_analysis' summary, so the client sees why the score is what it is.

RLS-SAFE PORTFOLIO DESIGN (portfolio_map, delta summary)
--------------------------------------------------------
  * ONE pre-load query per user per run (ai_insights chart_bundle rows joined to competitors)
    returns every watched competitor's latest headline metrics. It is cached for the run and
    refreshed after each scan.
  * The portfolio insight is emitted ATTACHED TO THE SCANNED COMPETITOR'S REAL competitor_id.
    The shared map rides inside that row and in the additive chart_bundle key 'portfolio_map'.
    competitor_id is NEVER NULL: DatabaseManager.save_insights refuses rows without one.
  * Each competitor's row refreshes when that competitor is scanned (hourly guard cadence).
  * The "delta since last scan" insight reuses the existing type 'market_timing', so the Flutter
    app renders it for every tier with ZERO Dart changes.

CONFIDENCE (every insight, 0-1)
-------------------------------
  confidence = sum(w_k * s_k) / sum(w_k) over data-sufficiency components (sample size,
  history depth, signal consistency). >=0.75 DIRECTIVE | >=0.50 RECOMMENDED | else HYPOTHESIS.
  The score lives in the in-memory dict, in a trailing summary tag and in chart_bundle
  ('confidence' key). It is NOT a DB column (schema frozen); the optional 'detailed_analysis'
  column is written only when VELORA_WRITE_DETAILED_ANALYSIS=1 (optional env, off by default).

--selftest CONTRACT (no network, no DB)
---------------------------------------
  python main.py --selftest
  Runs the engine on hardcoded synthetic data for all four tiers and asserts:
    (a) chart_bundle decodes with all 7 frozen keys of the right types
    (b) every emitted type is in the allowed vocabulary
    (c) FREE output has zero pro-only / new-premium types (server gate proven)
    (d) vulnerability rubric stays in [0,100] and its breakdown sums to the score
    (e) no insight string holds an unbound placeholder, 'None', 'nan' or 'Infinity'
    (f) every row carries a non-empty competitor_id
  plus extra logic checks. Prints PASS/FAIL per check, exits NONZERO on any failure.
"""

import os
import sys
import time
import json
import math
import logging
import argparse
import re
import inspect
import asyncio
import statistics
from pathlib import Path
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse
from typing import List, Dict, Optional, Any, Tuple, Iterator
from functools import wraps
from collections import Counter
from dataclasses import dataclass, field
from enum import Enum

VERSION = "5.0.0"
SELFTEST_MODE = "--selftest" in sys.argv

SCRAPERS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRAPERS_DIR))
# Make `ai/` importable from the project root
sys.path.insert(0, str(SCRAPERS_DIR.parent))

try:
    import requests
except ImportError:  # selftest must run even on a bare interpreter
    requests = None

try:
    from dotenv import load_dotenv
    load_dotenv(SCRAPERS_DIR / '.env')
except ImportError:
    if not SELFTEST_MODE:
        raise

try:
    from supabase import create_client, Client
except ImportError:
    if not SELFTEST_MODE:
        raise
    create_client = None
    Client = Any  # type: ignore

try:
    from core.platform_detector import detect_platform
    from platforms.shopify_scraper import scrape_shopify
    from platforms.woocommerce_scraper import scrape_woocommerce
    from platforms.generic_scraper import scrape_generic
    from core.trend_analyzer import TrendAnalyzer
except ImportError:
    if not SELFTEST_MODE:
        raise
    detect_platform = scrape_shopify = scrape_woocommerce = scrape_generic = TrendAnalyzer = None  # type: ignore

# ===================================================================
# RESEND EMAIL SERVICE (graceful fallback if unavailable)
# ===================================================================
try:
    from ai.email_sender import EmailService
    _EMAIL_SERVICE_AVAILABLE = True
except ImportError as _import_err:
    _EMAIL_SERVICE_AVAILABLE = False
    _EMAIL_IMPORT_ERROR = str(_import_err)

_HTTP_ERROR_TYPES: Tuple[type, ...] = (requests.exceptions.HTTPError,) if requests is not None else ()


# ===================================================================
# Custom Exceptions
# ===================================================================
class ScraperBlockedError(Exception):
    def __init__(self, status_code: Optional[int], reason: str = "") -> None:
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
    if status_code in (403, 404):
        return f"HTTP {status_code}"
    lowered = (body_text or "").lower()
    for phrase in BLOCK_SIGNAL_PHRASES:
        if phrase in lowered:
            return f"Bot-protection signal detected: '{phrase}'"
    return None


# ===================================================================
# TIER SYSTEM  (TIER_LIMITS frozen by PART 1)
# ===================================================================
TIER_LIMITS: Dict[str, Dict[str, int]] = {
    'free':       {'max_competitors': 3,    'scan_interval_hours': 24, 'max_products': 300},
    'pro':        {'max_competitors': 10,   'scan_interval_hours': 6,  'max_products': 1000},
    'pro_plus':   {'max_competitors': 25,   'scan_interval_hours': 3,  'max_products': 2500},
    'enterprise': {'max_competitors': 9999, 'scan_interval_hours': 1,  'max_products': 9999},
}
TIER_RANK: Dict[str, int] = {'free': 0, 'pro': 1, 'pro_plus': 2, 'enterprise': 3}

# Tier-aware data caps (v5): truncation is logged with WARN, never silent.
TIER_DATA_CAPS: Dict[str, Dict[str, int]] = {
    'free':       {'max_insights': 40,  'history_rows': 1000},
    'pro':        {'max_insights': 100, 'history_rows': 3000},
    'pro_plus':   {'max_insights': 200, 'history_rows': 6000},
    'enterprise': {'max_insights': 400, 'history_rows': 12000},
}
HISTORY_PAGE_SIZE = 1000  # PostgREST default max-rows; we paginate instead of trusting .limit()

DB_CHUNK_SIZE = 500
PRICE_STABLE_THRESHOLD_PCT = 0.5
MAX_PLAUSIBLE_STOCKOUT_RATIO = 0.4

# ----- Analytical thresholds (documented parameters; every insight number traces to these) -----
HHI_HIGH = 2500.0              # >2500 highly concentrated
HHI_MODERATE = 1500.0          # <=1500 diversified
HHI_SUB_CEILING = 5000.0       # concentration sub-score saturates here
COV_DISCIPLINED = 0.15         # CoV below this = disciplined
COV_OPPORTUNISTIC = 0.40       # CoV above this = inconsistent
COV_SUB_CEILING = 0.60         # inconsistency sub-score saturates here
PRICE_GAP_AVG_RATIO = 0.25     # a gap is a jump > 25% of the average price
BUDGET_RATIO = 0.6             # budget < 0.6 x avg
PREMIUM_RATIO = 1.5            # premium > 1.5 x avg
CHARM_ENDING_CENTS = frozenset({99, 95, 97, 49, 90, 88})
PSYCH_HIGH = 60.0              # % of prices with charm endings => heavy
PSYCH_LOW = 30.0               # % => light
ZERO_SIGNAL_EPS = 1.0          # signal <= 1.0% of titles counts as silent
LOUD_SIGNAL_MEAN = 15.0        # mean of 4 signals >= 15% => loud

# ----- Policy parameters (client-tunable levers, shown in the text next to the price they produce) -----
FLASH_DISCOUNT = 0.15          # flash-sale depth under competitor median
FLASH_HOURS = 48               # flash-sale window
SPECIALIST_UNDERCUT = 0.10     # specialist line priced this far under competitor median
HERO_UNDERCUT = 0.05           # hero product placed this far under competitor median
PRICE_TEST_BAND = 0.05         # +/- band for own dynamic-price tests
BUNDLE_PRICE_FACTOR = 1.6      # 2 mid-tier SKUs sold as one bundle at 1.6 x median
PREMIUM_ALT_MULT = 1.2         # premium alternative priced at 1.2 x reference
ACTION_WINDOW = "48-72 hours"  # stockout response window

# ----- Margin scenario simulator (PART 3.D) -----
BASE_MARGIN = 0.45
MARGIN_GRID = (0.35, 0.45, 0.55)
UNIT_GRID = (500, 1000, 2000)
BASE_RUN_UNITS = 1000
LAUNCH_COST_RATIO = 0.25       # assumption: launch cost F = 25% of first-run revenue at 1,000 units

# ----- Confidence voice -----
CONF_DIRECTIVE = 0.75
CONF_WORKING = 0.50
VOICE_PREFIX = {"directive": "Directive:", "working": "Recommended:", "hypothesis": "Hypothesis to test:"}

# ----- Contraction detector (PART 2.4) -----
CONTRACTION_MIN_ITEMS = 3
CONTRACTION_MIN_OBS = 3
CONTRACTION_STABLE_RANGE = 0.05    # (max-min)/mean <= 5% = stable price
CONTRACTION_STABLE_SHARE = 0.70
CONTRACTION_TOGETHER_SHARE = 0.80
CONTRACTION_MAX_REPLACEMENT = 0.50  # new SKUs / vanished SKUs above this = replacement (drift), not retirement

# ----- Seasonality / pressure -----
SEASON_MIN_TRANSITIONS = 20
SEASON_MIN_SPAN_DAYS = 3.0
SEASON_MIN_BUCKET_OBS = 10
SEASON_MIN_BUCKET_CUTS = 3
SEASON_LIFT = 2.0
SKU_MIN_TRANSITIONS = 2
SKU_PRESSURE_TOP_N = 5

# ===================================================================
# TYPE VOCABULARY & TIER GATING  (0.D / 0.E / 0.G)
# ===================================================================
VOCAB_BASE = frozenset({
    "executive_summary", "product_gap", "category_dominance", "competitive_threat", "pricing_warfare",
    "market_timing", "price_architecture", "quick_wins", "strategic_timeline", "cross_reference",
    "vulnerability_analysis", "financial_blueprint", "out_of_stock_signal", "stockout_signal_teaser",
    "scan_blocked", "trend", "chart_bundle", "dashboard_summary",
})
PRO_ONLY_TYPES = frozenset({
    "out_of_stock_signal", "vulnerability_analysis", "financial_blueprint",
    "quick_wins", "strategic_timeline", "cross_reference",
})
TEASER_TYPE = "stockout_signal_teaser"
NEW_PREMIUM_MIN_TIER: Dict[str, str] = {
    "catalog_contraction": "pro",
    "competitive_response": "pro",
    "sku_pressure_index": "pro",
    "language_fingerprint": "pro",
    "seasonality_cycle": "pro",
    "portfolio_map": "pro_plus",
}
NEW_PREMIUM_TYPES = frozenset(NEW_PREMIUM_MIN_TIER)
ALLOWED_TYPES = VOCAB_BASE | NEW_PREMIUM_TYPES
PAID_ONLY_TYPES = PRO_ONLY_TYPES | NEW_PREMIUM_TYPES
MIN_TIER_BY_TYPE: Dict[str, str] = {**{t: "pro" for t in PRO_ONLY_TYPES}, **NEW_PREMIUM_MIN_TIER}
# 0.G: single source of truth for non-strategic machine payloads (excluded from digests)
SKIP_TYPES = frozenset({"chart_bundle", "dashboard_summary"})
EMAIL_INSIGHT_KEYS = ("type", "title", "summary", "ai_recommendation", "severity")
DB_INSIGHT_COLUMNS = ("competitor_id", "type", "title", "summary", "ai_recommendation", "severity", "created_at")
CHART_FROZEN_KEYS = ("price_distribution", "segments", "categories", "price_history", "signals", "headlines")
WRITE_DETAILED_ANALYSIS = os.getenv("VELORA_WRITE_DETAILED_ANALYSIS", "0") == "1"  # optional env, default off


def normalize_tier(tier: Optional[str]) -> str:
    t = str(tier or "free").strip().lower()
    return t if t in TIER_RANK else "free"


def type_allowed(insight_type: str, tier: str) -> bool:
    """Server-side security wall. Type-based, never index-based."""
    tier = normalize_tier(tier)
    if insight_type == TEASER_TYPE:
        return tier == "free"
    min_tier = MIN_TIER_BY_TYPE.get(insight_type)
    if min_tier is None:
        return True
    return TIER_RANK[tier] >= TIER_RANK[min_tier]


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
    print(f"{Colors.OKBLUE} Velora v{VERSION} - Logical Rigor + Portfolio Intelligence{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Weighted Vulnerability Rubric | Confidence-Scored Insights | Portfolio Map{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   + Auto Email Alerts (Resend) | --selftest{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")


def print_success(msg: str) -> None: print(f"{Colors.OKGREEN}[OK] {msg}{Colors.ENDC}")
def print_error(msg: str) -> None: print(f"{Colors.FAIL}[ERR] {msg}{Colors.ENDC}")
def print_warning(msg: str) -> None: print(f"{Colors.WARNING}[WARN] {msg}{Colors.ENDC}")
def print_info(msg: str) -> None: print(f"{Colors.OKBLUE}[INFO] {msg}{Colors.ENDC}")
def print_header(msg: str) -> None: print(f"\n{Colors.BOLD}{Colors.OKCYAN}{msg}{Colors.ENDC}")


# ===================================================================
# Pure helpers
# ===================================================================
_WS_RE = re.compile(r"\s+")


def normalize_text(text: Optional[str]) -> str:
    if not text:
        return ""
    cleaned = text.replace("\xa0", " ").replace("\u2019", "'").replace("\u2018", "'")
    cleaned = _WS_RE.sub(" ", cleaned)
    return cleaned.strip().lower()


def normalize_product_url(url: Optional[str]) -> str:
    if not url:
        return ""
    u = url.strip().lower()
    u = re.sub(r'^https?://', '', u)
    u = re.sub(r'^www\.', '', u)
    u = u.split('?')[0].split('#')[0]
    u = u.rstrip('/')
    return u


def _chunked(items: List[Any], size: int) -> List[List[Any]]:
    return [items[i:i + size] for i in range(0, len(items), size)]


def _num(x: Any, default: float = 0.0) -> float:
    """Finite float or default. Guards every number that reaches an insight string."""
    try:
        v = float(x)
    except (TypeError, ValueError):
        return default
    return v if math.isfinite(v) else default


def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def usd(x: Any) -> str:
    return f"${_num(x):,.2f}"


def pct(x: Any, nd: int = 1) -> str:
    return f"{_num(x):.{nd}f}%"


def wconf(pairs: List[Tuple[float, float]]) -> float:
    """confidence = sum(w*s)/sum(w), s clamped to [0,1], rounded to 2 dp."""
    total_w = sum(w for w, _ in pairs)
    if total_w <= 0:
        return 0.0
    return round(clamp(sum(w * clamp(_num(s)) for w, s in pairs) / total_w), 2)


def voice_label(conf: float) -> str:
    if conf >= CONF_DIRECTIVE:
        return "directive"
    if conf >= CONF_WORKING:
        return "working"
    return "hypothesis"


def percentile(sorted_vals: List[float], q: float) -> float:
    if not sorted_vals:
        return 0.0
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    pos = clamp(q) * (len(sorted_vals) - 1)
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (pos - lo)


def price_delta_phrase(pct_change: float) -> str:
    if abs(pct_change) < PRICE_STABLE_THRESHOLD_PCT:
        return "remained essentially flat"
    direction = "risen" if pct_change > 0 else "fallen"
    return f"{direction} {abs(pct_change)}%"


_TS_FRAC_RE = re.compile(r"\.(\d+)")
_TS_SHORT_OFFSET_RE = re.compile(r"([+-]\d{2})$")


def parse_ts(value: Any) -> Optional[datetime]:
    """Robust ISO8601 -> aware UTC datetime (handles Z, short offsets, odd fractional digits)."""
    if isinstance(value, datetime):
        dt = value
    else:
        if not value:
            return None
        s = str(value).strip().replace('Z', '+00:00')
        if ' ' in s and 'T' not in s:
            s = s.replace(' ', 'T', 1)
        s = _TS_FRAC_RE.sub(lambda m: "." + (m.group(1) + "000000")[:6], s, count=1)
        if _TS_SHORT_OFFSET_RE.search(s) and 'T' in s and s.count(':') == 2:
            s = s + ":00"
        try:
            dt = datetime.fromisoformat(s)
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


_BAD_TOKEN_RE = re.compile(r"\bNone\b|\bnan\b|\bNaN\b|Infinity|\binf\b|\{[A-Za-z_][A-Za-z0-9_]*\}")


def scrub(text: str) -> str:
    """Final safety net: no unbound placeholder / None / nan / Infinity may reach a client."""
    return _BAD_TOKEN_RE.sub("n/a", text)


def _jsonable(obj: Any) -> Any:
    if isinstance(obj, float):
        return obj if math.isfinite(obj) else 0.0
    if isinstance(obj, dict):
        return {str(k): _jsonable(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_jsonable(v) for v in obj]
    return obj


def _kw_regex(words: List[str]) -> "re.Pattern[str]":
    alts = "|".join(re.escape(w) for w in sorted(words, key=len, reverse=True))
    return re.compile(r"(?<![a-z0-9])(?:" + alts + r")(?:s|es)?(?![a-z0-9])")


# ===================================================================
# Margin scenario simulator (PART 3.D)
# ===================================================================
def margin_scenarios(price: float) -> Dict[str, Any]:
    """
    launch_cost F      = LAUNCH_COST_RATIO * price * BASE_RUN_UNITS
    unit_profit(m)     = price * m
    breakeven_units(m) = ceil(F / unit_profit(m))
    profit(m, U)       = U * unit_profit(m) - F
    """
    price = _num(price)
    launch_cost = LAUNCH_COST_RATIO * price * BASE_RUN_UNITS
    rows: List[Dict[str, Any]] = []
    for m in MARGIN_GRID:
        unit_profit = price * m
        be = int(math.ceil(launch_cost / unit_profit)) if unit_profit > 0 else 0
        cells = [{"units": u, "profit": round(u * unit_profit - launch_cost, 2)} for u in UNIT_GRID]
        rows.append({"margin": m, "breakeven_units": be, "cells": cells})
    base = next(r for r in rows if abs(r["margin"] - BASE_MARGIN) < 1e-9)
    return {"price": round(price, 2), "launch_cost": round(launch_cost, 2), "rows": rows, "base": base}


def render_margin_matrix(sc: Dict[str, Any]) -> str:
    lines = []
    for r in sc["rows"]:
        cells = " | ".join(
            f"{c['units']:,}u: {'+' if c['profit'] >= 0 else '-'}{usd(abs(c['profit']))}" for c in r["cells"]
        )
        lines.append(f"Margin {int(round(r['margin'] * 100))}%: break-even {r['breakeven_units']:,} units | {cells}")
    return "\n".join(lines)


# ===================================================================
# Weighted vulnerability rubric (PART 2.2)
# ===================================================================
VULN_FACTORS: Tuple[Tuple[str, str, float], ...] = (
    ("concentration", "Category concentration", 22.0),
    ("pricing_inconsistency", "Pricing inconsistency", 18.0),
    ("promo_rigidity", "Promotional rigidity", 12.0),
    ("ladder_gaps", "Price-ladder gaps", 16.0),
    ("bestseller_dependence", "Bestseller dependence", 8.0),
    ("thin_catalog", "Thin catalog", 8.0),
    ("delisting_churn", "Delisting churn", 16.0),
)


def compute_vulnerability(hhi: float, cov: float, promo_pct: float, n_gaps: int,
                          velocity_pct: float, n_priced: int, n_disappeared: int) -> Dict[str, Any]:
    """
    score = round(sum(weight_i * sub_i)), weights sum to 100, sub_i in [0,1].
      concentration         = clamp((HHI - 1500) / (5000 - 1500))
      pricing_inconsistency = clamp((CoV - 0.15) / (0.60 - 0.15))
      promo_rigidity        = clamp(1 - promo% / 10)
      ladder_gaps           = clamp(n_gaps / 6)
      bestseller_dependence = clamp(velocity% / 40)
      thin_catalog          = clamp(1 - n_priced / 100)
      delisting_churn       = clamp(n_disappeared / 5)
    """
    hhi, cov, promo_pct, velocity_pct = _num(hhi), _num(cov), _num(promo_pct), _num(velocity_pct)
    subs = {
        "concentration": (
            clamp((hhi - HHI_MODERATE) / (HHI_SUB_CEILING - HHI_MODERATE)),
            f"HHI {hhi:,.0f} against a diversified ceiling of {HHI_MODERATE:,.0f}"),
        "pricing_inconsistency": (
            clamp((cov - COV_DISCIPLINED) / (COV_SUB_CEILING - COV_DISCIPLINED)),
            f"CoV {cov:.2f} against a disciplined ceiling of {COV_DISCIPLINED:.2f}"),
        "promo_rigidity": (
            clamp(1.0 - promo_pct / 10.0),
            f"promotional share {promo_pct:.1f}% (flexibility is full at 10%)"),
        "ladder_gaps": (
            clamp(n_gaps / 6.0),
            f"{n_gaps} uncovered price jump(s) above {int(PRICE_GAP_AVG_RATIO * 100)}% of the average price"),
        "bestseller_dependence": (
            clamp(velocity_pct / 40.0),
            f"{velocity_pct:.1f}% of titles carry bestseller or popularity tags"),
        "thin_catalog": (
            clamp(1.0 - n_priced / 100.0),
            f"{n_priced} priced products (a deep catalog starts at 100)"),
        "delisting_churn": (
            clamp(n_disappeared / 5.0),
            f"{n_disappeared} product(s) vanished since the last scan"),
    }
    factors = []
    for key, label, weight in VULN_FACTORS:
        sub, why = subs[key]
        factors.append({"key": key, "label": label, "weight": weight, "sub": round(sub, 3),
                        "points": round(weight * sub, 2), "justification": why})
    raw = round(sum(f["points"] for f in factors), 2)
    score = int(round(clamp(raw, 0.0, 100.0)))
    return {"score": score, "raw": raw, "factors": factors}


# ===================================================================
# Price-history index (one load, many analytics)
# ===================================================================
class HistoryIndex:
    def __init__(self, rows: Optional[List[Dict[str, Any]]]) -> None:
        self.by_scan: Dict[datetime, List[float]] = {}
        self.by_url: Dict[str, Dict[datetime, float]] = {}
        self.titles: Dict[str, str] = {}
        for r in rows or []:
            dt = parse_ts(r.get("recorded_at"))
            price = _num(r.get("price"), 0.0)
            if dt is None or price <= 0:
                continue
            self.by_scan.setdefault(dt, []).append(price)
            key = normalize_product_url(r.get("product_url"))
            if key:
                self.by_url.setdefault(key, {})[dt] = price
                if r.get("product_title"):
                    self.titles[key] = str(r.get("product_title"))
        self.scans: List[datetime] = sorted(self.by_scan)
        self._series: Dict[str, List[Tuple[datetime, float]]] = {
            k: sorted(v.items()) for k, v in self.by_url.items()
        }

    @property
    def n_scans(self) -> int:
        return len(self.scans)

    @property
    def span_days(self) -> float:
        if len(self.scans) < 2:
            return 0.0
        return (self.scans[-1] - self.scans[0]).total_seconds() / 86400.0

    def series(self, key: str) -> List[Tuple[datetime, float]]:
        return self._series.get(key, [])

    def transitions(self) -> Iterator[Tuple[str, datetime, float, datetime, float]]:
        for key, series in self._series.items():
            for i in range(1, len(series)):
                (d0, p0), (d1, p1) = series[i - 1], series[i]
                yield key, d0, p0, d1, p1

    def price_delta(self) -> Optional[Dict[str, Any]]:
        if len(self.scans) < 2:
            return None
        latest, prior = self.scans[-1], self.scans[-2]
        latest_avg = sum(self.by_scan[latest]) / len(self.by_scan[latest])
        prior_avg = sum(self.by_scan[prior]) / len(self.by_scan[prior])
        if prior_avg <= 0:
            return None
        both = [(d[prior], d[latest]) for d in self.by_url.values() if prior in d and latest in d]
        lfl = 0.0
        if len(both) >= 3:
            p_sum = sum(a for a, _ in both)
            if p_sum > 0:
                lfl = round((sum(b for _, b in both) - p_sum) / p_sum * 100, 1)
        return {
            "prior_avg": round(prior_avg, 2), "latest_avg": round(latest_avg, 2),
            "pct_change": round((latest_avg - prior_avg) / prior_avg * 100, 1),
            "like_for_like_pct": lfl, "overlap_n": len(both),
            "latest_n": len(self.by_scan[latest]),
            "prior_scan_date": prior.isoformat(), "latest_scan_date": latest.isoformat(),
        }

    def daily_avgs(self) -> List[Dict[str, Any]]:
        per_day: Dict[str, List[float]] = {}
        for dt in self.scans:
            vals = self.by_scan[dt]
            per_day.setdefault(dt.date().isoformat(), []).append(sum(vals) / len(vals))
        return [{"date": d, "avg": round(sum(v) / len(v), 2)} for d, v in sorted(per_day.items())]


# ===================================================================
# Smart stockout guard (PART 2.4)
# ===================================================================
def classify_disappearance(raw_disappeared: List[Dict[str, Any]], previous_products: List[Dict[str, Any]],
                           current_urls: set, history: HistoryIndex) -> Dict[str, Any]:
    """
    ratio <= 0.4                      -> stockout (normal path)
    ratio >  0.4 and pattern holds    -> contraction (collection retirement)
    ratio >  0.4 otherwise            -> drift (discard, as v4.5.0 did)
    Contraction requires ALL of:
      count >= 3
      stable_share   >= 0.70  (share of vanished SKUs with >=3 prior observations and
                               (max-min)/mean <= 5%)
      together_share >= 0.80  (share of vanished SKUs last seen in the same prior scan)
      replacement    <= 0.50  (new SKUs / vanished SKUs; above that = URL replacement, not shrinkage)
    """
    result: Dict[str, Any] = {"mode": "none", "stockouts": [], "contraction": None, "ratio": 0.0, "reason": ""}
    n = len(raw_disappeared)
    if n == 0:
        return result
    prev_n = max(len(previous_products), 1)
    ratio = n / prev_n
    result["ratio"] = ratio
    if ratio <= MAX_PLAUSIBLE_STOCKOUT_RATIO:
        result["mode"] = "stockout"
        result["stockouts"] = list(raw_disappeared)
        return result

    prev_urls = {normalize_product_url(p.get("product_url")) for p in previous_products}
    prev_urls.discard("")
    replacement = len(set(current_urls) - prev_urls) / n

    obs_counts: List[int] = []
    last_seen: List[datetime] = []
    last_prices: List[float] = []
    stable = 0
    for p in raw_disappeared:
        series = history.series(normalize_product_url(p.get("product_url")))
        obs_counts.append(len(series))
        last_prices.append(_num(p.get("current_price")))
        if series:
            last_seen.append(series[-1][0])
        if len(series) >= CONTRACTION_MIN_OBS:
            vals = [v for _, v in series]
            mean = sum(vals) / len(vals)
            if mean > 0 and (max(vals) - min(vals)) / mean <= CONTRACTION_STABLE_RANGE:
                stable += 1
    stable_share = stable / n
    together = (max(Counter(last_seen).values()) / n) if last_seen else 0.0
    mean_obs = sum(obs_counts) / n
    result["reason"] = (f"stable_share={stable_share:.0%} together={together:.0%} "
                        f"replacement={replacement:.0%} mean_obs={mean_obs:.1f}")

    if (n >= CONTRACTION_MIN_ITEMS and stable_share >= CONTRACTION_STABLE_SHARE
            and together >= CONTRACTION_TOGETHER_SHARE and replacement <= CONTRACTION_MAX_REPLACEMENT):
        priced = [x for x in last_prices if x > 0]
        ranked = sorted(raw_disappeared, key=lambda p: -_num(p.get("current_price")))
        result["mode"] = "contraction"
        result["contraction"] = {
            "count": n, "prev_count": len(previous_products), "ratio": round(ratio, 3),
            "stable_share": round(stable_share, 3), "together_share": round(together, 3),
            "mean_obs": round(mean_obs, 1), "replacement": round(replacement, 3),
            "confidence": wconf([(0.4, mean_obs / 6.0), (0.3, stable_share), (0.3, together)]),
            "avg_last_price": round(sum(priced) / len(priced), 2) if priced else 0.0,
            "price_low": round(min(priced), 2) if priced else 0.0,
            "price_high": round(max(priced), 2) if priced else 0.0,
            "pool": round(sum(priced), 2),
            "examples": [str(p.get("title", "")).strip()[:80] for p in ranked[:3] if p.get("title")],
        }
    else:
        result["mode"] = "drift"
    return result


# ===================================================================
# Portfolio market map (PART 3.A)
# ===================================================================
_QUADRANTS = {
    (True, True): "Premium specialists",
    (True, False): "Premium generalists",
    (False, True): "Value specialists",
    (False, False): "Value generalists",
}


def build_portfolio_map(entries: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """
    x = average price, y = HHI concentration.
    x_mid / y_mid = medians across the watchlist; 'high' means strictly above the median.
    White space = point on a 9x9 grid (window = observed range +/-25%) maximizing the minimum
    normalized Euclidean distance to every tracked competitor.
    """
    pts = [e for e in entries if _num(e.get("avg")) > 0 and _num(e.get("hhi"), -1) >= 0]
    if len(pts) < 2:
        return None
    xs = [_num(e["avg"]) for e in pts]
    ys = [_num(e["hhi"]) for e in pts]
    x_mid, y_mid = statistics.median(xs), statistics.median(ys)
    x_lo, x_hi, y_lo, y_hi = min(xs), max(xs), min(ys), max(ys)
    span_x = (x_hi - x_lo) or max(x_hi * 0.25, 1.0)
    span_y = (y_hi - y_lo) or max(y_hi * 0.25, 100.0)

    points = []
    quad_counts: Counter = Counter()
    for e, x, y in zip(pts, xs, ys):
        label = _QUADRANTS[(x > x_mid, y > y_mid)]
        quad_counts[label] += 1
        points.append({"name": str(e.get("name", "Competitor")), "x": round(x, 2), "y": round(y, 1), "quadrant": label})

    win_x0, win_x1 = max(x_lo - 0.25 * span_x, 0.01), x_hi + 0.25 * span_x
    win_y0, win_y1 = max(y_lo - 0.25 * span_y, 0.0), min(y_hi + 0.25 * span_y, 10000.0)
    best = (-1.0, x_mid, y_mid)
    steps = 9
    for i in range(steps):
        cx = win_x0 + (win_x1 - win_x0) * i / (steps - 1)
        for j in range(steps):
            cy = win_y0 + (win_y1 - win_y0) * j / (steps - 1)
            dmin = min(math.hypot((cx - x) / span_x, (cy - y) / span_y) for x, y in zip(xs, ys))
            if dmin > best[0]:
                best = (dmin, cx, cy)
    d, wx, wy = best
    white = {
        "avg_price": round(wx, 2), "hhi": round(wy, 1), "min_distance": round(d, 2),
        "quadrant": _QUADRANTS[(wx > x_mid, wy > y_mid)],
    }
    empty = [label for label in _QUADRANTS.values() if quad_counts.get(label, 0) == 0]
    return {"points": points, "x_mid": round(x_mid, 2), "y_mid": round(y_mid, 1),
            "white_space": white, "empty_quadrants": empty,
            "quadrant_counts": {k: int(v) for k, v in quad_counts.items()}}


# ===================================================================
# Zero-signal interpretation (PART 2.3)
# ===================================================================
def interpret_signals(vel: float, scar: float, fresh: float, promo: float) -> Dict[str, Any]:
    vals = {"velocity": _num(vel), "scarcity": _num(scar), "freshness": _num(fresh), "promo": _num(promo)}
    per = {k: ("silent" if v <= ZERO_SIGNAL_EPS else "heavy" if v > 20.0 else "active") for k, v in vals.items()}
    active = [k for k, s in per.items() if s != "silent"]
    silent = [k for k, s in per.items() if s == "silent"]
    mean_sig = sum(vals.values()) / 4.0
    if not active:
        return {
            "state": "silent", "per_signal": per,
            "headline": "No urgency signaling detected",
            "detail": ("Velocity, scarcity, freshness and promo are all at or below "
                       f"{ZERO_SIGNAL_EPS:.1f}% of titles. This competitor competes on brand equity, not on "
                       "discounts or scarcity language. Attack with value, positioning and guarantees; "
                       "price pressure is the wrong lever against this buyer."),
        }
    state = "loud" if mean_sig >= LOUD_SIGNAL_MEAN else "mixed"
    parts = ", ".join(f"{k} {vals[k]:.1f}%" for k in active)
    if state == "loud":
        head = "Heavy urgency signaling"
        meaning = ("The competitor leans on urgency to move volume, which usually reflects inventory pressure "
                   "or an acquisition push. Counter with value-added bundles instead of matching their cuts.")
    else:
        head = "Selective urgency signaling"
        meaning = ("The competitor uses urgency selectively. Contest the channels where it is active "
                   "and compete on positioning where it is silent.")
    silent_txt = f" Silent signals: {', '.join(silent)}." if silent else ""
    return {"state": state, "per_signal": per, "headline": head,
            "detail": f"Active signals: {parts}.{silent_txt} {meaning}"}


# ===================================================================
# Config / DB
# ===================================================================
class Config:
    def __init__(self) -> None:
        self.supabase_url: Optional[str] = os.getenv("SUPABASE_URL")
        self.supabase_key: Optional[str] = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        self.scan_interval: int = int(os.getenv("SCAN_INTERVAL", "86400"))
        self.max_retries: int = int(os.getenv("MAX_RETRIES", "3"))
        self.resend_api_key: Optional[str] = os.getenv("RESEND_API_KEY")
        self.emails_enabled: bool = bool(self.resend_api_key) and _EMAIL_SERVICE_AVAILABLE

    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials in .env")
            return False
        print_info("[ENGINE] Deterministic Analytics Engine - zero external AI cost")
        if self.emails_enabled:
            print_success("[EMAIL] Resend auto-alerts ENABLED (stockout + scan digest)")
        else:
            if not _EMAIL_SERVICE_AVAILABLE:
                print_warning(f"[EMAIL] Disabled: ai.email_sender could not be imported ({_EMAIL_IMPORT_ERROR})")
            else:
                print_warning("[EMAIL] Disabled: RESEND_API_KEY not found in .env")
        return True


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
                tiers = {u['id']: normalize_tier(u.get('tier')) for u in (ures.data or [])}

            now = datetime.now(timezone.utc)
            pending: List[Dict[str, Any]] = []
            per_user: Dict[Optional[str], int] = {}

            for row in rows:
                uid = row.get('user_id')
                tier = tiers.get(uid, 'free') if uid else 'free'
                limits = TIER_LIMITS.get(tier, TIER_LIMITS['free'])

                per_user[uid] = per_user.get(uid, 0) + 1
                if per_user[uid] > limits['max_competitors']:
                    self.logger.info(f"[SKIP] {row.get('name')} (User: {uid}): tier '{tier}' cap reached")
                    continue

                if not force_all:
                    last = row.get('last_scan_at')
                    last_dt = parse_ts(last) if last else None
                    if last_dt is not None:
                        hours_since_scan = (now - last_dt).total_seconds() / 3600
                        required_hours = limits['scan_interval_hours']
                        if hours_since_scan < required_hours:
                            self.logger.info(f"[SKIP] {row.get('name')} (Tier: {tier}): scanned {hours_since_scan:.1f}h ago")
                            continue
                        else:
                            self.logger.info(f"[SCAN] {row.get('name')} (Tier: {tier}): READY! ({hours_since_scan:.1f}h >= {required_hours}h)")
                    else:
                        self.logger.info(f"[SCAN] {row.get('name')} (Tier: {tier}): READY! (Never scanned)")

                row['_tier'] = tier
                row['_limits'] = limits
                pending.append(row)

            self.logger.info(f"Found {len(pending)} competitor(s) to scan (tier-aware)")
            return pending
        except Exception as e:
            self.logger.error(f"Failed to fetch competitors: {e}")
            return []

    def get_user_tier(self, user_id: Optional[str]) -> str:
        if not user_id:
            return 'free'
        try:
            res = self.supabase.table("users").select("tier").eq("id", user_id).limit(1).execute()
            if res.data:
                return normalize_tier(res.data[0].get("tier"))
        except Exception as e:
            self.logger.warning(f"Could not fetch tier for user {user_id}: {e}")
        return 'free'

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

    def get_previous_products(self, competitor_id: str) -> List[Dict[str, Any]]:
        try:
            res = (
                self.supabase.table("products")
                .select("product_url, title, current_price")
                .eq("competitor_id", competitor_id)
                .execute()
            )
            return res.data or []
        except Exception as e:
            self.logger.warning(f"Could not fetch previous products for {competitor_id}: {e}")
            return []

    def upsert_products(self, products: List[Dict[str, Any]], chunk_size: int = DB_CHUNK_SIZE) -> int:
        total = 0
        batches = _chunked(products, chunk_size)
        for idx, batch in enumerate(batches, 1):
            try:
                response = self.supabase.table("products").upsert(batch, on_conflict="competitor_id,product_url").execute()
                count = len(response.data) if response.data else len(batch)
                total += count
            except Exception as e:
                self.logger.error(f"Failed to upsert product batch {idx}/{len(batches)}: {e}")
        self.logger.info(f"Upserted {total}/{len(products)} products total across {len(batches)} batch(es)")
        return total

    @staticmethod
    def build_history_rows(products: List[Dict[str, Any]], competitor_id: str, recorded_at: str) -> List[Dict[str, Any]]:
        rows = []
        for p in products:
            price = _num(p.get("current_price"))
            if price > 0:
                rows.append({
                    "competitor_id": competitor_id,
                    "product_url": str(p.get("product_url", ""))[:500],
                    "product_title": str(p.get("title", ""))[:200],
                    "price": float(price),
                    "recorded_at": recorded_at,
                })
        return rows

    def save_price_history(self, products: List[Dict[str, Any]], competitor_id: str,
                           chunk_size: int = DB_CHUNK_SIZE, recorded_at: Optional[str] = None) -> int:
        now = recorded_at or datetime.now(timezone.utc).isoformat()
        history_rows = self.build_history_rows(products, competitor_id, now)
        if not history_rows:
            return 0
        total = 0
        batches = _chunked(history_rows, chunk_size)
        for idx, batch in enumerate(batches, 1):
            try:
                self.supabase.table("price_history").insert(batch).execute()
                total += len(batch)
            except Exception as e:
                self.logger.warning(f"price_history insert failed for batch {idx}/{len(batches)}: {e}")
        self.logger.info(f"Saved {total}/{len(history_rows)} price history records")
        return total

    def has_previous_price_history(self, competitor_id: str) -> bool:
        try:
            res = self.supabase.table("price_history").select("id").eq("competitor_id", competitor_id).limit(1).execute()
            return len(res.data or []) > 0
        except Exception as e:
            self.logger.warning(f"Could not check price history for {competitor_id}: {e}")
            return False

    def load_price_history(self, competitor_id: str, tier: str) -> Tuple[List[Dict[str, Any]], bool]:
        """
        Tier-capped, PAGINATED load (newest first, returned oldest first).
        Returns (rows, truncated). Truncation drops the partial oldest scan and logs a WARN.
        """
        cap = TIER_DATA_CAPS[normalize_tier(tier)]['history_rows']
        rows: List[Dict[str, Any]] = []
        truncated = False
        try:
            offset = 0
            while len(rows) < cap:
                want = min(HISTORY_PAGE_SIZE, cap - len(rows))
                res = (
                    self.supabase.table("price_history")
                    .select("product_url, product_title, price, recorded_at")
                    .eq("competitor_id", competitor_id)
                    .order("recorded_at", desc=True)
                    .order("product_url", desc=False)
                    .range(offset, offset + want - 1)
                    .execute()
                )
                batch = res.data or []
                rows.extend(batch)
                if len(batch) < want:
                    break
                offset += want
            if len(rows) >= cap:
                probe = (
                    self.supabase.table("price_history").select("recorded_at")
                    .eq("competitor_id", competitor_id)
                    .order("recorded_at", desc=True).order("product_url", desc=False)
                    .range(cap, cap).execute()
                )
                truncated = bool(probe.data)
        except Exception as e:
            self.logger.warning(f"Could not load price history for {competitor_id}: {e}")
            return [], False
        if truncated and rows:
            oldest = rows[-1].get("recorded_at")
            rows = [r for r in rows if r.get("recorded_at") != oldest]
            msg = (f"[ENGINE] WARN price_history truncated at {cap} rows for tier '{tier}' "
                   f"(competitor {competitor_id}); oldest partial scan dropped")
            self.logger.warning(msg)
            print_warning(msg)
        rows.reverse()
        return rows, truncated

    def get_price_delta(self, competitor_id: str, tier: str = 'free') -> Optional[Dict[str, Any]]:
        rows, _ = self.load_price_history(competitor_id, tier)
        return HistoryIndex(rows).price_delta()

    def load_portfolio_snapshots(self, user_id: Optional[str]) -> Dict[str, Dict[str, Any]]:
        """
        RLS-SAFE portfolio pre-load: ONE query returns the latest chart_bundle of every competitor the
        user owns (headline metrics live inside it). No new table, no NULL competitor_id rows.
        """
        out: Dict[str, Dict[str, Any]] = {}
        if not user_id:
            return out
        rows: List[Dict[str, Any]] = []
        try:
            res = (
                self.supabase.table("ai_insights")
                .select("competitor_id, summary, created_at, competitors!inner(name, user_id)")
                .eq("type", "chart_bundle")
                .eq("competitors.user_id", user_id)
                .order("created_at", desc=True)
                .limit(500)
                .execute()
            )
            rows = res.data or []
        except Exception as e:
            self.logger.warning(f"Joined portfolio query failed ({e}); falling back to two-step load")
            try:
                comps = self.supabase.table("competitors").select("id, name").eq("user_id", user_id).execute()
                names = {c['id']: c.get('name') for c in (comps.data or [])}
                if names:
                    res = (
                        self.supabase.table("ai_insights")
                        .select("competitor_id, summary, created_at")
                        .eq("type", "chart_bundle").in_("competitor_id", list(names))
                        .order("created_at", desc=True).limit(500).execute()
                    )
                    rows = res.data or []
                    for r in rows:
                        r['competitors'] = {'name': names.get(r.get('competitor_id'))}
            except Exception as e2:
                self.logger.warning(f"Could not load portfolio snapshots for {user_id}: {e2}")
                return out
        for r in rows:
            cid = r.get("competitor_id")
            if not cid or cid in out:
                continue
            joined = r.get("competitors")
            if isinstance(joined, list):
                joined = joined[0] if joined else {}
            name = (joined or {}).get("name") or "Competitor"
            entry = self.parse_snapshot(r.get("summary"), str(name), r.get("created_at"))
            if entry:
                out[cid] = entry
        return out

    @staticmethod
    def parse_snapshot(summary: Any, name: str, created_at: Any) -> Optional[Dict[str, Any]]:
        try:
            bundle = json.loads(summary) if isinstance(summary, str) else {}
            heads = bundle.get("headlines") or {}
            snap = bundle.get("portfolio_snapshot") or {}
            if _num(heads.get("avg")) <= 0:
                return None
            return {
                "name": name,
                "avg": _num(heads.get("avg")), "median": _num(heads.get("median")),
                "hhi": _num(heads.get("hhi")), "cov": _num(heads.get("cov")),
                "vulnerability": _num(heads.get("vulnerability")),
                "n_products": int(_num(snap.get("n_products"))),
                "gap_size": _num(snap.get("gap_size")),
                "gap_from": _num(snap.get("gap_from")), "gap_to": _num(snap.get("gap_to")),
                "avg_drift_pct": _num(snap.get("avg_drift_pct")),
                "drift_known": bool(snap.get("drift_known", False)),
                "scan_at": str(created_at or ""),
            }
        except Exception:
            return None

    def save_insights(self, insights: List[Dict[str, Any]], competitor_id: Optional[str] = None) -> bool:
        try:
            comp_id = competitor_id or (insights[0].get('competitor_id') if insights else None)
            if not comp_id:
                self.logger.error("Refusing to save insights without a real competitor_id (0.C RLS rule)")
                return False
            try:
                self.supabase.table("ai_insights").delete().eq("competitor_id", comp_id).neq("type", "trend").execute()
            except Exception as e:
                self.logger.warning(f"Could not clear prior insights for {comp_id}: {e}")
            now = datetime.now(timezone.utc).isoformat()
            rows = []
            for insight in insights:
                row = {k: insight.get(k) for k in DB_INSIGHT_COLUMNS if k in insight}
                row['competitor_id'] = comp_id
                row['created_at'] = now
                if WRITE_DETAILED_ANALYSIS:
                    row['detailed_analysis'] = str(insight.get('detailed_analysis', ''))
                rows.append(row)
            self.supabase.table("ai_insights").insert(rows).execute()
            self.logger.info(f"Saved {len(rows)} deterministic insights")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save insights: {e}")
            return False

    def save_blocked_insight(self, competitor_id: str, competitor_name: str,
                              status_code: Optional[int], reason: str) -> None:
        timestamp = datetime.now(timezone.utc).isoformat()
        status_part = f" (HTTP {status_code})" if status_code else ""
        insight = {
            "competitor_id": competitor_id,
            "type": "scan_blocked",
            "title": "Scan Blocked - Site Protection Detected",
            "summary": f"We were unable to retrieve pricing data for {competitor_name} this cycle because the site is actively blocking automated requests{status_part}. Reason: {reason}.",
            "ai_recommendation": "No action needed - we'll automatically retry on the next scheduled scan.",
            "severity": "medium",
            "created_at": timestamp,
        }
        try:
            self.supabase.table("ai_insights").delete().eq("competitor_id", competitor_id).eq("type", "scan_blocked").execute()
        except Exception:
            pass
        try:
            self.supabase.table("ai_insights").insert(insight).execute()
            self.logger.info(f"Recorded 'scan_blocked' insight for {competitor_name}")
        except Exception as e:
            self.logger.error(f"Failed to save blocked insight: {e}")

    def save_trend_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
            formatted = [{
                "competitor_id": i.get("competitor_id"), "type": "trend", "title": i.get("title", "Trend Analysis"),
                "summary": i.get("summary", ""), "ai_recommendation": i.get("recommendation", ""),
                "severity": str(i.get("severity", "medium")).lower(), "created_at": datetime.now(timezone.utc).isoformat()
            } for i in insights if i.get("competitor_id")]
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
            return True
        except Exception as e:
            self.logger.error(f"Failed to update timestamp: {e}")
            return False

    def get_watching_users(self, competitor_id: str) -> List[Dict[str, Any]]:
        """Return all users who own this competitor, with their email + tier."""
        try:
            comp_res = self.supabase.table("competitors").select("user_id").eq("id", competitor_id).execute()
            if not comp_res.data:
                return []
            user_ids = list({row["user_id"] for row in comp_res.data if row.get("user_id")})
            if not user_ids:
                return []
            user_res = self.supabase.table("users").select("id, email, tier").in_("id", user_ids).execute()
            return [u for u in (user_res.data or []) if u.get("email")]
        except Exception as e:
            self.logger.warning(f"Could not fetch watching users for {competitor_id}: {e}")
            return []


# ===================================================================
# THE ENGINE
# ===================================================================
_TECH_WORDS = frozenset({"pro", "max", "ultra", "series", "gen", "spec", "tech", "technical", "performance",
                         "waterproof", "breathable", "mm", "cm", "kg", "oz", "ml", "gb", "hz", "mah"})
_EMOTIVE_WORDS = frozenset({"love", "dream", "joy", "soul", "wild", "bliss", "cozy", "magic", "happy",
                            "beautiful", "heart", "golden", "sunset", "whisper", "dawn", "paradise",
                            "bloom", "serene", "spirit", "muse", "enchanted", "ritual", "cherish", "devotion"})
_WORD_RE = re.compile(r"[a-z0-9][a-z0-9'\-]*")
_WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
_VOICE_BLURB = {
    "technical": "spec-led titles built on measurable attributes (materials, dimensions, model codes)",
    "emotional": "benefit-led, feeling-first naming that sells an outcome instead of a spec",
    "minimalist": "short, noun-only names that let the product and the price speak",
}


class PremiumDeterministicMarketIntelligenceEngine:
    CATEGORY_KEYWORDS: List[str] = [
        "shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock",
        "accessory", "sweater", "hoodie", "short", "skirt", "coat", "boot",
        "sandal", "sneaker", "scarf", "belt", "watch", "jewelry", "legging",
        "tank", "bra", "jogger", "tee", "backpack",
        "oil", "balm", "kit", "underwear", "boxer", "glove", "strap"
    ]
    PROMOTION_KEYWORDS: List[str] = ["sale", "off", "discount", "limited", "new", "bestseller", "clearance", "final sale"]
    VELOCITY_KEYWORDS: List[str] = ["bestseller", "best selling", "popular", "top rated", "favorite", "trending", "most loved"]
    SCARCITY_KEYWORDS: List[str] = ["low stock", "selling fast", "limited", "final sale", "clearance", "last chance", "only a few left"]
    FRESHNESS_KEYWORDS: List[str] = ["new in", "just dropped", "new arrival", "fresh", "launch"]

    _CAT_RE: Dict[str, "re.Pattern[str]"] = {}
    _PROMO_RE = _kw_regex(PROMOTION_KEYWORDS)
    _VEL_RE = _kw_regex(VELOCITY_KEYWORDS)
    _SCAR_RE = _kw_regex(SCARCITY_KEYWORDS)
    _FRESH_RE = _kw_regex(FRESHNESS_KEYWORDS)

    def __init__(self, competitor: Dict[str, Any], products: List[Dict[str, Any]],
                 db: Optional[DatabaseManager] = None,
                 disappeared_products: Optional[List[Dict[str, Any]]] = None,
                 history_rows: Optional[List[Dict[str, Any]]] = None,
                 portfolio: Optional[Dict[str, Dict[str, Any]]] = None,
                 contraction: Optional[Dict[str, Any]] = None,
                 scan_diff: Optional[Dict[str, Any]] = None) -> None:
        self.competitor = competitor
        self.products = list(products or [])
        self.db = db
        self.disappeared_products = disappeared_products or []
        self.name: str = str(competitor.get('name') or 'Unknown')
        self.tier: str = normalize_tier(competitor.get('_tier'))
        self.rank: int = TIER_RANK[self.tier]
        self.limits: Dict[str, int] = competitor.get('_limits', TIER_LIMITS[self.tier])
        self.comp_id = competitor.get('id')
        self.logger = logging.getLogger('PremiumDeterministicEngine')
        self.portfolio: Dict[str, Dict[str, Any]] = dict(portfolio or {})
        self.contraction = contraction
        self.scan_diff = scan_diff or {}
        if not self._CAT_RE:
            type(self)._CAT_RE = {kw: _kw_regex([kw]) for kw in self.CATEGORY_KEYWORDS}

        if history_rows is None and db is not None and self.comp_id:
            history_rows, _ = db.load_price_history(self.comp_id, self.tier)
        self.hist = HistoryIndex(history_rows)

        self.items: List[Dict[str, Any]] = []
        for p in self.products:
            raw = str(p.get("title") or "").strip()
            self.items.append({
                "raw": raw, "norm": normalize_text(raw), "price": _num(p.get("current_price")),
                "url": str(p.get("product_url") or ""),
            })
        self.rows = [i for i in self.items if i["price"] > 0]
        self._data: Optional[Dict[str, Any]] = None
        self.snapshot_entry: Dict[str, Any] = {}

    # ---------------- generic helpers ----------------
    def generate_all_insights(self) -> List[Dict[str, Any]]:
        return self._generate_premium_insights()

    def get_data(self) -> Dict[str, Any]:
        if self._data is None:
            self._data = self._analyze_data()
        return self._data

    def _title_near_price(self, target_price: float) -> str:
        best_title, best_diff = "an unnamed product", float("inf")
        for r in self.rows:
            diff = abs(r["price"] - target_price)
            if diff < best_diff:
                best_diff = diff
                best_title = r["raw"] or best_title
        return best_title

    @staticmethod
    def _format_sample_titles(samples: List[str], max_show: int = 2) -> str:
        shown = [f"'{t}'" for t in samples[:max_show] if t]
        if not shown:
            return ""
        if len(shown) == 1:
            return shown[0]
        return f"{shown[0]} and {shown[1]}"

    def _psychological_stats(self) -> Dict[str, Any]:
        """
        psych%  = 100 * (# prices whose cents in {99,95,97,49,90,88}) / # priced
        round%  = 100 * (# whole-dollar prices) / # priced
        """
        if not self.rows:
            return {"psych_pct": 0.0, "round_pct": 0.0, "top_ending": ""}
        cents = [int(round(r["price"] * 100)) % 100 for r in self.rows]
        n = len(cents)
        charm = Counter(c for c in cents if c in CHARM_ENDING_CENTS)
        top_ending = f".{charm.most_common(1)[0][0]:02d}" if charm else ""
        return {"psych_pct": round(sum(charm.values()) / n * 100, 1),
                "round_pct": round(sum(1 for c in cents if c == 0) / n * 100, 1),
                "top_ending": top_ending}

    # ---------------- analysis (every number in every insight traces here) ----------------
    def _analyze_data(self) -> Dict[str, Any]:
        prices = [r["price"] for r in self.rows]
        if not prices:
            return {"error": "No pricing data available"}
        n = len(prices)
        avg_price = sum(prices) / n
        median_price = statistics.median(prices)
        try:
            stdev_price = statistics.stdev(prices) if n > 1 else 0.0
        except statistics.StatisticsError:
            stdev_price = 0.0

        budget_threshold = avg_price * BUDGET_RATIO
        premium_threshold = avg_price * PREMIUM_RATIO
        budget_n = sum(1 for p in prices if p < budget_threshold)
        premium_n = sum(1 for p in prices if p > premium_threshold)
        mid_n = n - budget_n - premium_n
        sorted_rows = sorted(self.rows, key=lambda r: r["price"], reverse=True)

        category_counts: Counter = Counter()
        category_samples: Dict[str, List[str]] = {}
        categorized = 0
        for r in self.rows:
            hit = False
            for kw, rx in self._CAT_RE.items():
                if rx.search(r["norm"]):
                    hit = True
                    category_counts[kw] += 1
                    samples = category_samples.setdefault(kw, [])
                    if r["raw"] and r["raw"] not in samples and len(samples) < 2:
                        samples.append(r["raw"])
            categorized += 1 if hit else 0

        velocity_samples: List[str] = []
        scarcity_samples: List[str] = []
        freshness_samples: List[str] = []
        promotion_count = budget_promo_count = premium_promo_count = 0
        velocity_count = scarcity_count = freshness_count = 0
        for it in self.items:
            title = it["norm"]
            promo_title = title.replace("off-white", "").replace("off white", "")
            if self._PROMO_RE.search(promo_title):
                promotion_count += 1
                if 0 < it["price"] < budget_threshold:
                    budget_promo_count += 1
                elif it["price"] > premium_threshold:
                    premium_promo_count += 1
            if self._VEL_RE.search(title):
                velocity_count += 1
                if it["raw"] and len(velocity_samples) < 2:
                    velocity_samples.append(it["raw"])
            if self._SCAR_RE.search(title):
                scarcity_count += 1
                if it["raw"] and len(scarcity_samples) < 2:
                    scarcity_samples.append(it["raw"])
            if self._FRESH_RE.search(title):
                freshness_count += 1
                if it["raw"] and len(freshness_samples) < 2:
                    freshness_samples.append(it["raw"])

        top_categories = category_counts.most_common(5)
        total_cat = sum(category_counts.values())
        hhi = sum((c / total_cat) ** 2 for c in category_counts.values()) if total_cat > 0 else 0.0
        hhi_score = round(hhi * 10000, 1)
        hhi_interp = "highly concentrated" if hhi_score > HHI_HIGH else "moderately concentrated" if hhi_score > HHI_MODERATE else "diversified"

        sorted_prices = sorted(prices)
        price_gaps: List[Dict[str, float]] = []
        for i in range(len(sorted_prices) - 1):
            gap = sorted_prices[i + 1] - sorted_prices[i]
            if gap > avg_price * PRICE_GAP_AVG_RATIO:
                price_gaps.append({"from": round(sorted_prices[i], 2), "to": round(sorted_prices[i + 1], 2), "size": round(gap, 2)})
        # v4.5.0 bug fix: pick the actual LARGEST gap, not the first (lowest-priced) one
        biggest = max(price_gaps, key=lambda g: g["size"]) if price_gaps else None
        largest_gap = ({"from": biggest["from"], "to": biggest["to"], "size": biggest["size"],
                        "ratio_to_avg": round(biggest["size"] / avg_price, 2)}
                       if biggest else {"from": 0.0, "to": 0.0, "size": 0.0, "ratio_to_avg": 0.0})

        cov = round(stdev_price / avg_price, 2) if avg_price > 0 else 0.0
        cov_interp = "inconsistent/opportunistic" if cov > COV_OPPORTUNISTIC else "disciplined/confident" if cov < COV_DISCIPLINED else "moderate"

        total_items = max(len(self.items), 1)
        promo_pct = round(promotion_count / total_items * 100, 1)
        velocity_pct = round(velocity_count / total_items * 100, 1)
        scarcity_pct = round(scarcity_count / total_items * 100, 1)
        freshness_pct = round(freshness_count / total_items * 100, 1)

        top_cat = top_categories[0] if top_categories else ("unknown", 0)
        top_cat_pct = round(top_cat[1] / n * 100, 1)

        price_delta = self.hist.price_delta()
        vuln = compute_vulnerability(hhi_score, cov, promo_pct, len(price_gaps), velocity_pct, n, len(self.disappeared_products))

        psych = self._psychological_stats()
        seg = {"budget": round(budget_n / n * 100, 1), "mid": round(mid_n / n * 100, 1), "premium": round(premium_n / n * 100, 1)}
        n_scans = self.hist.n_scans
        return {
            "competitor_name": self.name,
            "tier_context": self.tier,
            "total_products_scanned": len(self.items),
            "products_with_pricing": n,
            "avg_price": round(avg_price, 2),
            "median_price": round(median_price, 2),
            "stdev_price": round(stdev_price, 2),
            "min_price": round(min(prices), 2),
            "max_price": round(max(prices), 2),
            "p10_price": round(percentile(sorted_prices, 0.10), 2),
            "p90_price": round(percentile(sorted_prices, 0.90), 2),
            "cov": cov, "cov_interp": cov_interp,
            "hhi_score": hhi_score, "hhi_interp": hhi_interp,
            "top_cat": top_cat[0], "top_cat_count": top_cat[1], "top_cat_pct": top_cat_pct,
            "top_cat_samples": category_samples.get(top_cat[0], []),
            "promo_pct": promo_pct,
            "budget_promo_count": budget_promo_count, "premium_promo_count": premium_promo_count,
            "n_gaps": len(price_gaps),
            "largest_gap_from": largest_gap['from'], "largest_gap_to": largest_gap['to'],
            "largest_gap_size": largest_gap['size'], "largest_gap_ratio": largest_gap['ratio_to_avg'],
            "budget_pct": seg["budget"], "mid_pct": seg["mid"], "premium_pct": seg["premium"],
            "dominant_segment": max(seg, key=lambda k: seg[k]),
            "price_delta": price_delta,
            "velocity_count": velocity_count, "velocity_pct": velocity_pct, "velocity_samples": velocity_samples,
            "scarcity_count": scarcity_count, "scarcity_pct": scarcity_pct, "scarcity_samples": scarcity_samples,
            "freshness_count": freshness_count, "freshness_pct": freshness_pct, "freshness_samples": freshness_samples,
            "psych_pct": psych["psych_pct"], "round_pct": psych["round_pct"], "top_ending": psych["top_ending"],
            "vulnerability_score": vuln["score"], "vulnerability": vuln,
            "n_scans": n_scans, "history_span_days": round(self.hist.span_days, 1),
            # confidence components
            "cs": clamp(n / 60.0), "cd": clamp((n_scans - 1) / 5.0),
            "cc": round(categorized / n, 3),
        }

    # ---------------- insight factory ----------------
    def _basis(self, d: Dict[str, Any]) -> str:
        return f"basis: {d['products_with_pricing']} priced products, {d['n_scans']} scan(s) of history"

    def _mk(self, typ: str, title: str, summary: str, rec: str, severity: str, conf: float,
            ts: str, basis: str = "", tag: bool = True) -> Dict[str, Any]:
        conf = round(clamp(_num(conf)), 2)
        label = voice_label(conf)
        if tag:
            suffix = f"; {basis}" if basis else ""
            summary = f"{summary}\n[Confidence {conf:.2f} - {label.upper()}{suffix}]"
            rec = f"{VOICE_PREFIX[label]} {rec}"
        return {
            "competitor_id": self.comp_id, "type": typ, "title": title, "summary": summary,
            "ai_recommendation": rec, "severity": severity, "created_at": ts, "confidence": conf,
            "detailed_analysis": f"confidence={conf:.2f}; voice={label}; {basis}".strip("; "),
        }

    def _launch_plan(self, d: Dict[str, Any]) -> Tuple[float, str]:
        if d['largest_gap_size'] > 0:
            price = round((d['largest_gap_from'] + d['largest_gap_to']) / 2, 2)
            return price, f"Gap-filler priced at {usd(price)}"
        anchor = d['top_cat_samples'][0] if d['top_cat_samples'] else f"the {d['top_cat']} line"
        price = round(d['avg_price'] * PREMIUM_ALT_MULT, 2)
        return price, f"Premium alternative to '{anchor}' at {usd(price)}"

    # ---------------- text builders ----------------
    def _price_architecture_rec(self, d: Dict[str, Any]) -> str:
        psych, med = d['psych_pct'], d['median_price']
        if psych >= PSYCH_HIGH:
            ending = d['top_ending'] or ".99"
            return (
                f"Match their charm endings so you never read expensive on comparison pages: {psych}% of their prices "
                f"use charm endings, led by {ending}. Price your competing SKUs on the same {ending} family and place "
                f"your hero product at {usd(round(med * (1 - HERO_UNDERCUT), 2))} ({int(HERO_UNDERCUT * 100)}% under their "
                f"{usd(med)} median) to win the 'cheaper than typical' perception."
            )
        if psych <= PSYCH_LOW:
            return (
                f"Do NOT use charm endings. Only {psych}% of their prices use them ({d['round_pct']}% are whole-dollar), "
                "so a .95/.97 ladder would make you look like the discounter in a premium frame. Price on whole-dollar "
                f"points, hold the hero product at or above their {usd(med)} median, and win on value: bundle, guarantee, "
                "or service wrap instead of price signalling."
            )
        return (
            f"Their pricing is mixed ({psych}% charm endings). Use charm endings only on SKUs below their {usd(med)} "
            "median, where shoppers compare price, and whole-dollar prices above it, where shoppers compare quality."
        )

    def _cross_reference_text(self, d: Dict[str, Any]) -> Tuple[str, str]:
        hhi, top_pct, cov, gap, top_cat = d['hhi_score'], d['top_cat_pct'], d['cov'], d['largest_gap_size'], d['top_cat']
        has_gap = gap > 0
        spec_price = usd(round(d['median_price'] * (1 - SPECIALIST_UNDERCUT), 2))
        if hhi > HHI_HIGH and top_pct > 20:
            if has_gap:
                summary = (
                    f"Connecting the dots: this competitor's highly concentrated catalog (HHI {hhi}) combined with "
                    f"{d['cov_interp']} pricing (CoV {cov}) creates a structurally exposed position. Their "
                    f"{usd(gap)} price gap sits beside the '{top_cat}' category ({top_pct}% of their catalog) - the "
                    "category they depend on most is also the one with the uncovered price band."
                )
                rec = (
                    f"Exploit the intersection directly: launch a premium product inside the {usd(gap)} price gap, "
                    f"targeting the '{top_cat}' category where they are both most concentrated and least defended on "
                    "price. This attacks their core revenue stream at its weakest point."
                )
            else:
                summary = (
                    f"Connecting the dots: this competitor's highly concentrated catalog (HHI {hhi}, '{top_cat}' at "
                    f"{top_pct}%) is priced densely with no exploitable gap - but that density is itself the weakness: "
                    f"{d['cov_interp']} pricing (CoV {cov}) across a narrow category means one demand shock hits everything."
                )
                rec = (
                    f"Don't look for a price gap - there isn't one. Attack the concentration: build a '{top_cat}' "
                    f"specialist line at {spec_price} ({int(SPECIALIST_UNDERCUT * 100)}% under their {usd(d['median_price'])} "
                    "median) and market it as the focused option. A narrow catalog cannot defend breadth and price at once."
                )
        elif hhi <= HHI_MODERATE:
            summary = (
                f"Connecting the dots: this competitor's diversified catalog (HHI {hhi}, top category '{top_cat}' "
                f"at {top_pct}%) combined with {d['cov_interp']} pricing (CoV {cov}) leaves no single category "
                "concentration to attack - their risk is spread thin rather than concentrated."
            )
            rec = (
                "Don't attack a single category - there is no concentrated weak point. Build a differentiated brand "
                "story around depth in ONE category rather than breadth across many; specialists out-convert "
                "generalists with comparison shoppers."
            )
        else:
            zone = d['hhi_interp']
            if has_gap:
                summary = (
                    f"Connecting the dots: this competitor sits in a {zone} zone (HHI {hhi}), with '{top_cat}' at "
                    f"{top_pct}% of catalog and {d['cov_interp']} pricing (CoV {cov}). Their {usd(gap)} price gap is a "
                    "real opportunity, but it is not tied to a single over-exposed category."
                )
                rec = (
                    f"Use the {usd(gap)} price gap as the primary lever, but don't over-index the messaging on "
                    f"'{top_cat}' alone - a single-category attack has a shorter shelf life against this spread."
                )
            else:
                summary = (
                    f"Connecting the dots: this competitor sits in a {zone} zone (HHI {hhi}, '{top_cat}' at "
                    f"{top_pct}%) with {d['cov_interp']} pricing (CoV {cov}) and NO exploitable price gap - their "
                    "price ladder is dense and deliberate, so a gap-filling attack will fail."
                )
                rec = (
                    "With no price gap to fill and no single category to attack, compete on value-add: "
                    f"bundle their core '{top_cat}' items with complementary accessories to raise perceived value "
                    "without touching price. Dense pricing beats head-on price cuts; bundling beats both."
                )
        return summary, rec

    def _build_quick_wins(self, d: Dict[str, Any]) -> List[str]:
        wins: List[str] = []
        med = d['median_price']
        if d['promo_pct'] < 5:
            wins.append(
                f"Run a {FLASH_HOURS}-hour flash sale at {usd(round(med * (1 - FLASH_DISCOUNT), 2))} "
                f"({int(FLASH_DISCOUNT * 100)}% under their {usd(med)} median) to capture the price-sensitive shoppers "
                f"their {d['promo_pct']}% promotional share ignores."
            )
        if d['largest_gap_size'] > 0:
            wins.append(
                f"Launch a gap-filler priced at {usd(round((d['largest_gap_from'] + d['largest_gap_to']) / 2, 2))} "
                f"to occupy the {usd(d['largest_gap_size'])} whitespace they leave open."
            )
        else:
            wins.append(
                f"No price gap exists - bundle two mid-tier SKUs (~{usd(med)} each) into a "
                f"{usd(round(med * BUNDLE_PRICE_FACTOR, 2))} bundle to lift basket value without discounting."
            )
        if self.disappeared_products:
            wins.append(
                f"Bid on search keywords for their {len(self.disappeared_products)} stocked-out item(s) this week "
                "to capture orphaned demand before they restock."
            )
        if d['velocity_samples']:
            wins.append(f"Publish comparison content against their bestseller '{d['velocity_samples'][0]}' to intercept high-intent shoppers.")
        if d['top_cat_samples']:
            wins.append(f"Add a complementary accessory to '{d['top_cat_samples'][0]}' to raise basket value.")
        return wins[:4]

    def _build_timeline(self, d: Dict[str, Any], be_units: int) -> str:
        if d['largest_gap_size'] > 0:
            price = round((d['largest_gap_from'] + d['largest_gap_to']) / 2, 2)
            d30 = f"30 Days: Launch the {usd(price)} gap-filler and validate against its break-even volume of {be_units:,} units."
        else:
            anchor = d['top_cat_samples'][0] if d['top_cat_samples'] else d['top_cat']
            d30 = f"30 Days: No price gap exists - launch a bundled offer around '{anchor}' and validate against {be_units:,} break-even units."
        d60 = (f"60 Days: Press on their concentration (HHI {d['hhi_score']}) by adding SKUs adjacent to "
               f"'{d['top_cat']}' ({d['top_cat_pct']}% of their catalog).")
        d90 = (f"90 Days: Keep your own price spread (CoV) at or below {min(d['cov'], COV_DISCIPLINED)} "
               f"against their {d['cov']} and convert the captured segment into repeat purchases.")
        return f"{d30}\n{d60}\n{d90}"

    # ---------------- PART 3 analytics ----------------
    def _response_model(self, d: Dict[str, Any]) -> Dict[str, Any]:
        """
        Evidence (all from price_history + titles):
          sku_cut_share   = SKUs with >=1 cut / SKUs with >=1 interval
          sku_move_share  = SKUs with >=1 move / SKUs with >=1 interval
        Propensities:
          e_hold  = (1 - clamp(cov/0.40)) * (1 - clamp(sku_move_share/0.50))     [no history: cov term only]
          e_promo = clamp(promo% / 20)
          e_cut   = 0.6*clamp(sku_cut_share/0.25) + 0.4*clamp(cov/0.60)          [no history: cov term only]
          p_i     = (e_i + 0.1) / (sum(e) + 0.3)
        """
        thr = PRICE_STABLE_THRESHOLD_PCT
        per: Dict[str, Dict[str, int]] = {}
        n_tr = 0
        for key, _d0, p0, _d1, p1 in self.hist.transitions():
            rec = per.setdefault(key, {"cuts": 0, "moves": 0})
            n_tr += 1
            move = (p1 - p0) / p0 * 100 if p0 > 0 else 0.0
            if abs(move) >= thr:
                rec["moves"] += 1
                if move < 0:
                    rec["cuts"] += 1
        tracked = len(per)
        cut_skus = sum(1 for r in per.values() if r["cuts"] > 0)
        move_skus = sum(1 for r in per.values() if r["moves"] > 0)
        have_hist = tracked > 0
        cut_share = cut_skus / tracked if have_hist else 0.0
        move_share = move_skus / tracked if have_hist else 0.0
        cov_hold = 1 - clamp(d['cov'] / COV_OPPORTUNISTIC)
        e_hold = cov_hold * (1 - clamp(move_share / 0.50)) if have_hist else cov_hold
        e_promo = clamp(d['promo_pct'] / 20.0)
        cov_cut = clamp(d['cov'] / COV_SUB_CEILING)
        e_cut = (0.6 * clamp(cut_share / 0.25) + 0.4 * cov_cut) if have_hist else cov_cut
        total = e_hold + e_promo + e_cut + 0.3
        probs = {"hold": (e_hold + 0.1) / total, "promo": (e_promo + 0.1) / total, "cut": (e_cut + 0.1) / total}
        conf = wconf([(0.3, d['cs']), (0.4, n_tr / 200.0), (0.3, (d['n_scans'] - 1) / 4.0)])
        return {"probs": probs, "tracked": tracked, "cut_skus": cut_skus, "move_skus": move_skus,
                "cut_share": cut_share, "move_share": move_share, "n_tr": n_tr, "have_hist": have_hist, "conf": conf}

    def _sku_pressure(self, d: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        PI = 100 * (moves/transitions) * (0.5 + 0.5 * clamp(mean_abs_move% / 20)), in [0,100]
        qualifying SKU: >= 2 transitions (3 observations)
        """
        thr = PRICE_STABLE_THRESHOLD_PCT
        per: Dict[str, Dict[str, float]] = {}
        for key, _d0, p0, _d1, p1 in self.hist.transitions():
            rec = per.setdefault(key, {"trans": 0, "moves": 0, "abs_sum": 0.0})
            rec["trans"] += 1
            move = (p1 - p0) / p0 * 100 if p0 > 0 else 0.0
            if abs(move) >= thr:
                rec["moves"] += 1
                rec["abs_sum"] += abs(move)
        ranked = []
        qualifying = 0
        for key, r in per.items():
            if r["trans"] < SKU_MIN_TRANSITIONS:
                continue
            qualifying += 1
            if r["moves"] == 0:
                continue
            freq = r["moves"] / r["trans"]
            mean_abs = r["abs_sum"] / r["moves"]
            pi = 100.0 * freq * (0.5 + 0.5 * clamp(mean_abs / 20.0))
            series = self.hist.series(key)
            net = (series[-1][1] - series[0][1]) / series[0][1] * 100 if series and series[0][1] > 0 else 0.0
            ranked.append({"key": key, "title": self.hist.titles.get(key, key), "pi": round(pi, 1),
                           "moves": int(r["moves"]), "trans": int(r["trans"]),
                           "mean_abs": round(mean_abs, 1), "net": round(net, 1)})
        if not ranked:
            return None
        ranked.sort(key=lambda x: -x["pi"])
        conf = wconf([(0.4, qualifying / 15.0), (0.6, (d['n_scans'] - 1) / 5.0)])
        return {"top": ranked[:SKU_PRESSURE_TOP_N], "qualifying": qualifying, "volatile": len(ranked), "conf": conf}

    def _language_fingerprint(self, d: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        titles = [r["norm"] for r in self.rows if r["norm"]]
        if len(titles) < 10:
            return None
        n = len(titles)
        words_per = []
        tech_n = emo_n = mini_n = long_n = 0
        all_tokens: List[str] = []
        for t in titles:
            toks = _WORD_RE.findall(t)
            words_per.append(len(toks))
            all_tokens.extend(toks)
            if any(re.search(r"\d", w) or w in _TECH_WORDS for w in toks):
                tech_n += 1
            if any(w in _EMOTIVE_WORDS for w in toks):
                emo_n += 1
            if len(toks) <= 3:
                mini_n += 1
            if len(toks) >= 8:
                long_n += 1
        shares = {"technical": round(tech_n / n * 100, 1), "emotional": round(emo_n / n * 100, 1),
                  "minimalist": round(mini_n / n * 100, 1)}
        ordered = sorted(shares, key=lambda k: -shares[k])
        top, second, gap_voice = ordered[0], ordered[1], ordered[-1]
        voice = "plain descriptive" if shares[top] < 15.0 else top
        margin = clamp((shares[top] - shares[second]) / 50.0)
        sw = sorted(words_per)
        diversity = round(len(set(all_tokens)) / len(all_tokens), 2) if all_tokens else 0.0
        return {
            "n": n, "shares": shares, "voice": voice, "gap_voice": gap_voice,
            "mean_words": round(sum(words_per) / n, 1), "median_words": round(statistics.median(words_per), 1),
            "p25": round(percentile([float(x) for x in sw], 0.25), 1), "p75": round(percentile([float(x) for x in sw], 0.75), 1),
            "long_pct": round(long_n / n * 100, 1), "diversity": diversity,
            "conf": wconf([(0.6, n / 40.0), (0.4, margin)]),
        }

    def _seasonality(self, d: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        cut_rate(bucket) = price cuts landing in bucket / SKU-intervals landing in bucket
        flag weekday when cut_rate >= 2.0 x overall (>=10 intervals, >=3 cuts in the bucket)
        """
        trans = list(self.hist.transitions())
        if len(trans) < SEASON_MIN_TRANSITIONS or self.hist.span_days < SEASON_MIN_SPAN_DAYS:
            return None
        thr = PRICE_STABLE_THRESHOLD_PCT
        obs: Counter = Counter()
        cuts: Counter = Counter()
        total_cuts = 0
        for _k, _d0, p0, d1, p1 in trans:
            move = (p1 - p0) / p0 * 100 if p0 > 0 else 0.0
            is_cut = move <= -thr
            buckets = [("dow", d1.weekday()), ("wk", "weekend" if d1.weekday() >= 5 else "weekday"),
                       ("mo", "start" if d1.day <= 5 else "end" if d1.day >= 26 else "mid")]
            for b in buckets:
                obs[b] += 1
                if is_cut:
                    cuts[b] += 1
            total_cuts += 1 if is_cut else 0
        n_tr = len(trans)
        overall = total_cuts / n_tr
        patterns: List[str] = []
        if overall > 0:
            for dow in range(7):
                key = ("dow", dow)
                if obs[key] >= SEASON_MIN_BUCKET_OBS and cuts[key] >= SEASON_MIN_BUCKET_CUTS:
                    rate = cuts[key] / obs[key]
                    if rate >= SEASON_LIFT * overall:
                        patterns.append(f"discounts concentrate on {_WEEKDAYS[dow]}s ({rate * 100:.1f}% of repricing intervals are cuts vs {overall * 100:.1f}% overall)")
            for lbl, label in (("weekend", "weekends"), ("weekday", "weekdays")):
                key = ("wk", lbl)
                if obs[key] >= SEASON_MIN_BUCKET_OBS and cuts[key] >= SEASON_MIN_BUCKET_CUTS:
                    rate = cuts[key] / obs[key]
                    if rate >= SEASON_LIFT * overall and not any("concentrate on" in p for p in patterns):
                        patterns.append(f"cuts cluster on {label} ({rate * 100:.1f}% vs {overall * 100:.1f}% overall)")
            for lbl, label in (("start", "month-start (days 1-5)"), ("end", "month-end (day 26+)")):
                key = ("mo", lbl)
                if obs[key] >= SEASON_MIN_BUCKET_OBS and cuts[key] >= SEASON_MIN_BUCKET_CUTS:
                    rate = cuts[key] / obs[key]
                    if rate >= SEASON_LIFT * overall:
                        patterns.append(f"cuts cluster at {label} ({rate * 100:.1f}% vs {overall * 100:.1f}% overall)")
        conf = wconf([(0.4, total_cuts / 20.0), (0.6, self.hist.span_days / 28.0)])
        return {"patterns": patterns, "n_tr": n_tr, "total_cuts": total_cuts, "overall": overall,
                "span_days": round(self.hist.span_days, 1), "conf": conf}

    def _portfolio_view(self, d: Dict[str, Any]) -> List[Dict[str, Any]]:
        entries = [dict(v) for k, v in self.portfolio.items() if k != self.comp_id]
        entries.append({"name": self.name, "avg": d['avg_price'], "hhi": d['hhi_score']})
        return entries

    def _snapshot(self, d: Dict[str, Any]) -> Dict[str, Any]:
        pdv = d['price_delta']
        return {
            "n_products": d['products_with_pricing'], "avg": d['avg_price'], "median": d['median_price'],
            "hhi": d['hhi_score'], "cov": d['cov'], "vulnerability": d['vulnerability_score'],
            "gap_size": d['largest_gap_size'], "gap_from": d['largest_gap_from'], "gap_to": d['largest_gap_to'],
            "avg_drift_pct": pdv['pct_change'] if pdv else 0.0, "drift_known": bool(pdv),
        }

    # ---------------- generation ----------------
    def _generate_premium_insights(self) -> List[Dict[str, Any]]:
        d = self.get_data()
        if "error" in d:
            return self._generate_fallback_insights()

        ts = datetime.now(timezone.utc).isoformat()
        paid = self.rank >= TIER_RANK['pro']
        deep = self.rank >= TIER_RANK['pro_plus']
        basis = self._basis(d)
        cs, cd, cc = d['cs'], d['cd'], d['cc']
        vuln = d['vulnerability']
        score = d['vulnerability_score']
        pdv = d['price_delta']
        launch_price, launch_label = self._launch_plan(d)
        sc = margin_scenarios(launch_price)
        base_be = sc['base']['breakeven_units']
        out: List[Dict[str, Any]] = []

        # ---- executive_summary ----
        vuln_level = "HIGH" if score > 70 else "MEDIUM" if score > 40 else "LOW"
        seg = d['dominant_segment']
        exec_summary = (
            f"{d['competitor_name']} operates with {d['products_with_pricing']} priced products averaging {usd(d['avg_price'])}, "
            f"with the {seg} tier dominant ({d[seg + '_pct']}% of priced products). "
            f"The top category, '{d['top_cat']}', accounts for {d['top_cat_pct']}% of the priced catalog "
            f"with an HHI of {d['hhi_score']} ({d['hhi_interp']}). "
            f"Price discipline is {d['cov_interp']} (CoV: {d['cov']}). "
            f"Vulnerability Score: {score}/100 ({vuln_level})."
        )
        if pdv:
            exec_summary += f" Average prices have {price_delta_phrase(pdv['pct_change'])} since the last scan."
        if score > 70:
            exec_rec = f"With a vulnerability score of {score}/100, this competitor has critical weaknesses. Review the strategic insights below for data-backed counter-moves."
        elif score > 40:
            exec_rec = f"With a vulnerability score of {score}/100, this competitor has notable weaknesses in specific areas. Review the strategic insights below for data-backed counter-moves."
        else:
            exec_rec = f"With a vulnerability score of {score}/100, this competitor shows limited exploitable weakness. Compete on differentiation rather than attack."
        out.append(self._mk("executive_summary", "Market Overview", exec_summary, exec_rec,
                            "high" if score > 70 else "medium", wconf([(0.7, cs), (0.3, cc)]), ts, basis))

        # ---- stockout teaser (free only) ----
        if self.disappeared_products and self.tier == 'free':
            out.append(self._mk(
                TEASER_TYPE, "Stockout Signal Detected",
                (f"We detected {len(self.disappeared_products)} product(s) that were in this competitor's catalog last "
                 "scan but are no longer listed - a possible stockout or delisting."),
                "Upgrade to Pro to see exactly which products went out of stock, their last known prices, and a targeted action plan while the window is open.",
                "medium", wconf([(0.5, (self.scan_diff.get('prev_count', 0)) / 60.0), (0.5, 1.0)]), ts, basis, tag=False))

        # ---- product_gap ----
        if d['largest_gap_size'] > 0:
            lower_title = self._title_near_price(d['largest_gap_from'])
            upper_title = self._title_near_price(d['largest_gap_to'])
            out.append(self._mk(
                "product_gap", "Critical Price Gap Identified",
                (f"A significant whitespace exists between {usd(d['largest_gap_from'])} ('{lower_title}') and "
                 f"{usd(d['largest_gap_to'])} ('{upper_title}') - a gap of {usd(d['largest_gap_size'])} "
                 f"({d['largest_gap_ratio']}x the average price). The competitor lists no priced product in this "
                 "range, leaving an unmonetized segment of buyers."),
                (f"Launch a flagship product priced at {usd(launch_price)}, positioned between '{lower_title}' and "
                 f"'{upper_title}'. At the base case ({int(BASE_MARGIN * 100)}% margin, {BASE_RUN_UNITS:,}-unit run) it breaks even at {base_be:,} units."),
                "high", wconf([(0.7, cs), (0.3, d['largest_gap_ratio'])]), ts, basis))
        else:
            out.append(self._mk(
                "product_gap", "Dense Price Coverage - No Gap To Fill",
                (f"No exploitable price gap detected: their price ladder from {usd(d['min_price'])} to "
                 f"{usd(d['max_price'])} is continuous (largest jump under {int(PRICE_GAP_AVG_RATIO * 100)}% of the "
                 f"{usd(d['avg_price'])} average). A gap-filling entry strategy would fail here."),
                (f"Don't chase a price gap that isn't there. Compete on bundle value, subscription, or service wrap "
                 f"around their {usd(d['median_price'])} median item instead - win on perceived value, not on an empty price band."),
                "medium", wconf([(1.0, cs)]), ts, basis))

        # ---- category_dominance ----
        cat_phrase = f", such as '{d['top_cat_samples'][0]}'" if d['top_cat_samples'] else ""
        if d['hhi_score'] > HHI_HIGH:
            cat_rec = (f"Their dependence on '{d['top_cat']}' is the exposure. Build a deeper '{d['top_cat']}' line "
                       f"than theirs and bundle kits around it to compete where {d['top_cat_pct']}% of their catalog sits.")
        elif d['hhi_score'] <= HHI_MODERATE:
            cat_rec = ("Their catalog is spread across categories, so there is no concentrated weak point. "
                       f"Differentiate with depth in one category instead of matching their breadth.")
        else:
            cat_rec = (f"Their catalog is moderately concentrated around '{d['top_cat']}'. Contest that category with "
                       "a focused line while watching for their diversification.")
        out.append(self._mk(
            "category_dominance", "Category Concentration Risk",
            (f"The catalog is {d['hhi_interp']} (HHI Index: {d['hhi_score']}). The top category "
             f"'{d['top_cat']}'{cat_phrase} represents {d['top_cat_pct']}% of priced products "
             f"({d['top_cat_count']} of {d['products_with_pricing']})."),
            cat_rec, "high" if d['hhi_score'] > HHI_HIGH else "medium", wconf([(0.6, cs), (0.4, cc)]), ts, basis))

        # ---- competitive_threat: promotional intensity ----
        low_promo = d['promo_pct'] < 10
        out.append(self._mk(
            "competitive_threat", "Promotional Intensity Analysis",
            (f"Promotional intensity is at {d['promo_pct']}%, with {d['budget_promo_count']} promos in the "
             f"budget segment and {d['premium_promo_count']} in the premium segment. "
             + ("The limited discounting indicates pricing confidence." if low_promo
                else "High promotional activity suggests inventory pressure or an aggressive acquisition strategy.")),
            (f"Run a targeted {int(FLASH_DISCOUNT * 100)}% flash campaign on mid-tier staples (about {usd(round(d['median_price'] * (1 - FLASH_DISCOUNT), 2))} "
             "against their median) to capture price-sensitive shoppers." if low_promo
             else "Counter their promotional blitz with value-added bundles rather than price cuts."),
            "medium", wconf([(1.0, cs)]), ts, basis))

        # ---- pricing_warfare ----
        out.append(self._mk(
            "pricing_warfare", "Pricing Discipline Assessment",
            (f"The Price Coefficient of Variation (CoV) is {d['cov']}, indicating {d['cov_interp']} pricing. "
             f"The price spread ranges from {usd(d['min_price'])} to {usd(d['max_price'])}."),
            (f"Make predictability your edge: hold your own CoV under {COV_DISCIPLINED} against their {d['cov']}, so buyers can trust your price ladder." if d['cov'] > COV_OPPORTUNISTIC
             else "Study their pricing discipline as a benchmark and use targeted promotions in peripheral categories to drive traffic."),
            "high" if d['cov'] > COV_OPPORTUNISTIC else "medium", wconf([(1.0, cs)]), ts, basis))

        # ---- market_timing: historical shift ----
        if pdv and abs(pdv['pct_change']) >= PRICE_STABLE_THRESHOLD_PCT:
            rose = pdv['pct_change'] > 0
            overlap_share = pdv['overlap_n'] / max(pdv['latest_n'], 1)
            out.append(self._mk(
                "market_timing", "Historical Price Shift Detected",
                (f"Since the last scan, the competitor's average price has {price_delta_phrase(pdv['pct_change'])} "
                 f"(from {usd(pdv['prior_avg'])} to {usd(pdv['latest_avg'])}). On the {pdv['overlap_n']} SKUs present in both scans "
                 f"the like-for-like change is {pdv['like_for_like_pct']}%."),
                ("Prices rose: position your alternatives as the smart value choice while the gap is fresh." if rose
                 else "Prices fell: emphasize superior quality and brand equity instead of chasing the cut."),
                "high", wconf([(0.4, cs), (0.6, overlap_share)]), ts, basis))
        elif pdv:
            out.append(self._mk(
                "market_timing", "Price Stability Confirmed",
                (f"Since the last scan, the competitor's average price has {price_delta_phrase(pdv['pct_change'])} at "
                 f"{usd(pdv['latest_avg'])}, indicating confidence in their current margin structure."),
                (f"Use this stability window to test your own pricing in a +/-{int(PRICE_TEST_BAND * 100)}% band on "
                 "comparable products and find your conversion-maximizing price point without triggering a price war."),
                "medium", wconf([(0.4, cs), (0.6, pdv['overlap_n'] / max(pdv['latest_n'], 1))]), ts, basis))

        # ---- competitive_threat: velocity ----
        if d['velocity_pct'] > 0 or d['scarcity_pct'] > 0:
            vel_phrase = f", including {self._format_sample_titles(d['velocity_samples'])}" if d['velocity_samples'] else ""
            anchor = d['velocity_samples'][0] if d['velocity_samples'] else (d['top_cat_samples'][0] if d['top_cat_samples'] else d['top_cat'])
            out.append(self._mk(
                "competitive_threat", "Sales Velocity & Scarcity Signals",
                (f"Title analysis shows {d['velocity_pct']}% of products carry bestseller or popularity tags"
                 f"{vel_phrase}, while {d['scarcity_pct']}% show scarcity signals."),
                (f"Don't price-war items like '{anchor}'. Launch a complementary cross-sell or a premium alternative "
                 f"near {usd(round(d['median_price'] * PREMIUM_ALT_MULT, 2))} ({PREMIUM_ALT_MULT}x their median)."),
                "high", wconf([(0.5, cs), (0.5, (d['velocity_count'] + d['scarcity_count']) / 10.0)]), ts, basis))

        # ---- market_timing: freshness ----
        if d['freshness_pct'] > 0:
            fresh_phrase = f", such as {self._format_sample_titles(d['freshness_samples'])}" if d['freshness_samples'] else ""
            out.append(self._mk(
                "market_timing", "Assortment Freshness & Rapid Drops",
                (f"The competitor is actively pushing new inventory, with {d['freshness_pct']}% of the "
                 f"catalog tagged 'New In' or 'Just Dropped'{fresh_phrase}."),
                "Counter not by matching their speed, but by establishing an 'evergreen' staple with a lifetime guarantee.",
                "medium", wconf([(0.5, cs), (0.5, d['freshness_count'] / 10.0)]), ts, basis))

        # ---- price_architecture (charm-pricing logic fixed) ----
        psych = d['psych_pct']
        spread = round(d['max_price'] - d['min_price'], 2)
        spread_x = round(spread / d['avg_price'], 1) if d['avg_price'] else 0.0
        psych_word = 'heavy' if psych > PSYCH_HIGH else 'moderate' if psych > PSYCH_LOW else 'light'
        position = ('value-oriented, conversion-focused' if psych > PSYCH_HIGH
                    else 'premium, brand-led' if psych < PSYCH_LOW else 'balanced')
        gap_mm = d['avg_price'] - d['median_price']
        if abs(gap_mm) <= d['avg_price'] * 0.005:
            shape = "the mean and median coincide, so the average describes the typical buy"
        elif gap_mm > 0:
            shape = "the mean is pulled up by a few premium outliers, so real volume sits lower than the average suggests"
        else:
            shape = "the distribution skews toward higher prices, so the average understates the typical buy"
        out.append(self._mk(
            "price_architecture", "Price Architecture & Psychological Pricing Deep Dive",
            (f"{d['competitor_name']}'s price ladder spans {usd(d['min_price'])} to {usd(d['max_price'])} (a {usd(spread)} spread, "
             f"{spread_x}x the {usd(d['avg_price'])} average), anchored near {usd(d['p90_price'])} at the top (90th percentile) "
             f"and {usd(d['p10_price'])} at the entry (10th percentile). {psych}% of prices end in a charm ending "
             f"(.99/.95/.97/.49/.90/.88) and {d['round_pct']}% are whole-dollar - a {psych_word} use of charm pricing that signals "
             f"a {position} positioning. With a {usd(d['median_price'])} median against the {usd(d['avg_price'])} mean, {shape} - "
             "this tells you where their volume lives versus where their margin lives."),
            self._price_architecture_rec(d), "medium", wconf([(1.0, cs)]), ts, basis))

        # ---- H: delta since last scan (reuses 'market_timing': Flutter-safe for every tier) ----
        delta = self._delta_insight(d, ts, basis, deep)
        if delta:
            out.append(delta)

        # ---- paid tier insights ----
        if paid:
            if self.disappeared_products:
                shown = self.disappeared_products[:3]
                titles_prices = "; ".join(
                    f"'{p.get('title', 'Unnamed product')}' (was {usd(p.get('current_price', 0))})" for p in shown)
                prev_count = self.scan_diff.get('prev_count', 0)
                out.append(self._mk(
                    "out_of_stock_signal", "Competitor Stockout/Delisting Detected",
                    (f"{len(self.disappeared_products)} product(s) that were in the competitor's catalog on the last "
                     f"scan are no longer listed, including: {titles_prices}. This typically signals either a stockout "
                     "or a deliberate delisting - both represent a narrow, time-sensitive window."),
                    (f"Launch a targeted ad campaign within {ACTION_WINDOW} bidding on keywords tied to "
                     f"'{shown[0].get('title', 'the missing product')}' and similar missing items."),
                    "critical", wconf([(0.5, prev_count / 60.0), (0.5, d['n_scans'] / 3.0)]), ts, basis))

            vuln_lines = "\n".join(
                f"- {f['label']}: {f['points']:.1f}/{f['weight']:.0f} pts (sub-score {f['sub']:.2f}; {f['justification']})"
                for f in vuln['factors'])
            verdict = ("This competitor has critical strategic weaknesses you can exploit immediately." if score > 70
                       else "This competitor has notable vulnerabilities in specific areas." if score > 40
                       else "This competitor is relatively well-positioned.")
            top_factors = sorted(vuln['factors'], key=lambda f: -f['points'])[:2]
            out.append(self._mk(
                "vulnerability_analysis", "Vulnerability Score: Deep Dive",
                (f"Vulnerability Score: {score}/100 (weighted rubric, weights sum to 100). {verdict}\n{vuln_lines}\n"
                 f"Sum of points: {vuln['raw']:.2f} -> {score}/100."),
                ((f"Immediate action: target the two heaviest factors ({top_factors[0]['label']}, {top_factors[1]['label']}) with coordinated campaigns this quarter." if score > 70
                  else f"Strategic approach: focus on the two heaviest factors ({top_factors[0]['label']}, {top_factors[1]['label']}) and build a differentiated value proposition." if score > 40
                  else "Differentiation strategy: compete on brand storytelling or niche specialization.")),
                "critical" if score > 70 else "high" if score > 40 else "medium",
                wconf([(0.5, cs), (0.3, cd), (0.2, cc)]), ts, basis))

            # financial_blueprint + margin scenario simulator (3.D)
            if d['largest_gap_size'] > 0:
                bp_summary = (f"Detailed rollout plan to fill the {usd(d['largest_gap_size'])} whitespace between "
                              f"{usd(d['largest_gap_from'])} and {usd(d['largest_gap_to'])}.")
            else:
                anchor_line = d['top_cat_samples'][0] if d['top_cat_samples'] else f"the {d['top_cat']} line"
                bp_summary = (f"No exploitable price gap detected - this rollout plan targets a premium alternative "
                              f"to '{anchor_line}' to win on value rather than on an empty price band.")
            if deep:
                matrix = render_margin_matrix(sc)
                bp_rec = (f"Product: {launch_label}. Launch cost assumption F = {usd(sc['launch_cost'])} "
                          f"({int(LAUNCH_COST_RATIO * 100)}% of the {BASE_RUN_UNITS:,}-unit revenue of {usd(launch_price * BASE_RUN_UNITS)}).\n"
                          f"{matrix}\nProfit = units x price x margin - F. Days-to-execute: 30. "
                          f"Success KPI: reach the break-even volume of your chosen margin row within 60 days.")
            else:
                bp_rec = (f"Product: {launch_label}. Base case: {int(BASE_MARGIN * 100)}% gross margin, {BASE_RUN_UNITS:,}-unit run, "
                          f"launch cost F = {usd(sc['launch_cost'])}. Break-even: {base_be:,} units; profit at {BASE_RUN_UNITS:,} units: "
                          f"{usd(sc['base']['cells'][1]['profit'])}. Days-to-execute: 30. Upgrade to Pro+ for the full margin x volume sensitivity matrix.")
            out.append(self._mk("financial_blueprint", "Financial Execution Blueprint", bp_summary, bp_rec, "critical",
                                wconf([(0.6, cs), (0.4, cd)]), ts, basis))

            quick_wins = self._build_quick_wins(d)
            out.append(self._mk(
                "quick_wins", "Quick Wins (Execute in 7 Days)", "\n".join(f"- {w}" for w in quick_wins),
                "Assign an owner to each item today and review results at day 7 against this competitor's next scan.",
                "high", wconf([(0.7, cs), (0.3, cd)]), ts, basis))

            out.append(self._mk(
                "strategic_timeline", "Strategic Timeline (30-60-90 Day)", self._build_timeline(d, base_be),
                "Assign a dedicated owner and check-in date to each milestone above.",
                "medium", wconf([(0.7, cs), (0.3, cd)]), ts, basis))

            cross_summary, cross_rec = self._cross_reference_text(d)
            out.append(self._mk("cross_reference", "Cross-Reference Strategic Analysis", cross_summary, cross_rec,
                                "high", wconf([(0.5, cs), (0.5, cc)]), ts, basis))

            # PART 2.4: catalog contraction
            if self.contraction:
                c = self.contraction
                ex = self._format_sample_titles(c.get('examples', []), 3)
                ex_txt = f" Examples: {ex}." if ex else ""
                out.append(self._mk(
                    "catalog_contraction", "Catalog Contraction Detected",
                    (f"{c['count']} of {c['prev_count']} SKUs ({c['ratio'] * 100:.0f}%) vanished in a single scan. "
                     f"{c['stable_share'] * 100:.0f}% of them held a price range within {int(CONTRACTION_STABLE_RANGE * 100)}% over a mean of "
                     f"{c['mean_obs']} prior observations, and {c['together_share'] * 100:.0f}% were last seen in the same scan. "
                     f"Only {c['replacement'] * 100:.0f}% as many new SKUs appeared. This pattern indicates a collection retirement, not "
                     f"URL drift. Their last-known prices ran from {usd(c['price_low'])} to {usd(c['price_high'])} "
                     f"(average {usd(c['avg_last_price'])}).{ex_txt}"),
                    (f"Treat the vacated {usd(c['price_low'])}-{usd(c['price_high'])} band as open shelf space: place your closest "
                     f"substitute there within {ACTION_WINDOW}, and do not treat this as a temporary stockout."),
                    "high", c['confidence'], ts, basis))

            # 3.B competitive response model
            rm = self._response_model(d)
            out.append(self._response_insight(d, rm, launch_price, ts, basis))

            # 3.C SKU pressure index
            sp = self._sku_pressure(d)
            if sp:
                lines = []
                for r in sp['top']:
                    if r['net'] <= -5:
                        direction = "downward drift (clearance proxy)"
                    elif r['net'] >= 5:
                        direction = "upward drift (demand proxy)"
                    else:
                        direction = "oscillating"
                    lines.append(f"- '{r['title'][:70]}': PI {r['pi']} ({r['moves']} repricings in {r['trans']} intervals, "
                                 f"mean move {r['mean_abs']}%, net {r['net']}%, {direction})")
                top = sp['top'][0]
                out.append(self._mk(
                    "sku_pressure_index", "SKU-Level Pressure Index",
                    (f"{sp['volatile']} of {sp['qualifying']} SKUs with enough history have been repriced. Most volatile first "
                     f"(PI = 100 x repricing frequency x magnitude factor):\n" + "\n".join(lines)),
                    (f"Watch '{top['title'][:70]}' as the leading indicator (PI {top['pi']}): repricing frequency precedes "
                     "category-wide moves and marks where they are clearing stock or testing demand."),
                    "medium", sp['conf'], ts, basis))

            # 3.E language fingerprint
            lf = self._language_fingerprint(d)
            if lf:
                sh = lf['shares']
                voice_line = (f"dominant voice: {lf['voice']}" if lf['voice'] != "plain descriptive"
                              else "no dominant voice (every voice below 15%): plain descriptive naming")
                out.append(self._mk(
                    "language_fingerprint", "Positioning Language Fingerprint",
                    (f"Across {lf['n']} titles: technical {sh['technical']}%, emotional {sh['emotional']}%, minimalist {sh['minimalist']}% "
                     f"(titles of 3 words or fewer). Title length averages {lf['mean_words']} words (median {lf['median_words']}, "
                     f"interquartile {lf['p25']}-{lf['p75']}; {lf['long_pct']}% run 8+ words). Lexical diversity is {lf['diversity']}. "
                     f"Inferred brand voice - {voice_line}."),
                    (f"The least-occupied voice is {lf['gap_voice']} ({sh[lf['gap_voice']]}% of their titles). "
                     f"Name your line with {_VOICE_BLURB[lf['gap_voice']]} to own the space they leave empty."),
                    "medium", lf['conf'], ts, basis))

            # 3.F seasonality
            se = self._seasonality(d)
            if se:
                if se['patterns']:
                    finding = "; ".join(se['patterns'])
                    rec = "Launch your counter-offer 24 hours before the flagged window so it is live when their cuts land."
                elif se['total_cuts'] == 0:
                    finding = "no price cuts were observed at all"
                    rec = "Their prices do not follow a calendar rhythm. Time your promotions on your own demand curve."
                else:
                    finding = "no calendar bucket shows cut activity at twice the overall rate"
                    rec = "No recurring discount cycle is visible. Time your promotions on your own demand curve."
                out.append(self._mk(
                    "seasonality_cycle", "Discount Cycle & Seasonality Detector",
                    (f"Across {se['n_tr']} SKU-intervals over {se['span_days']} days, {se['total_cuts']} were price cuts "
                     f"({se['overall'] * 100:.1f}%). Finding: {finding}."),
                    rec, "medium", se['conf'], ts, basis))

            # 3.A portfolio map (pro_plus / enterprise)
            pmap = build_portfolio_map(self._portfolio_view(d)) if deep else None
            if pmap:
                self._pmap = pmap
                ws = pmap['white_space']
                counts = ", ".join(f"{k}: {v}" for k, v in sorted(pmap['quadrant_counts'].items()))
                empty = ", ".join(pmap['empty_quadrants']) if pmap['empty_quadrants'] else "every quadrant is occupied"
                focus = "a focused catalog (high HHI)" if ws['hhi'] > pmap['y_mid'] else "a broad catalog (low HHI)"
                n_pts = len(pmap['points'])
                out.append(self._mk(
                    "portfolio_map", "Portfolio Market Map",
                    (f"{n_pts} tracked competitors positioned on average price (x) against HHI concentration (y); "
                     f"watchlist medians are {usd(pmap['x_mid'])} and HHI {pmap['y_mid']}. Quadrants - {counts}. "
                     f"Unoccupied: {empty}. Largest white space: average price near {usd(ws['avg_price'])} with HHI near {ws['hhi']} "
                     f"({ws['quadrant']}), {ws['min_distance']} normalized units from the nearest tracked competitor."),
                    (f"Enter at roughly {usd(ws['avg_price'])} with {focus}: no tracked competitor sits within "
                     f"{ws['min_distance']} normalized units of that point."),
                    "high", wconf([(0.6, n_pts / 5.0), (0.4, cs)]), ts, basis))

        # ---- server-side type gate (the security boundary) ----
        out = self._enforce_tier_gate(out)

        # ---- chart bundle ----
        conf_map: Dict[str, List[float]] = {}
        for i in out:
            conf_map.setdefault(i['type'], []).append(i['confidence'])
        by_type = {k: round(sum(v) / len(v), 2) for k, v in conf_map.items()}
        overall_conf = round(sum(by_type.values()) / len(by_type), 2) if by_type else 0.0
        chart = self._build_chart_data(d, by_type, overall_conf)
        out.append(self._mk("chart_bundle", "Market Visualizations",
                            json.dumps(_jsonable(chart), allow_nan=False), "Render as interactive charts.",
                            "low", overall_conf, ts, tag=False))

        # ---- executive dashboard (always index 0) ----
        critical_high = sum(1 for i in out if i.get('severity') in ('critical', 'high'))
        if d['largest_gap_size'] > 0:
            opp_label = f"{usd(launch_price * BASE_RUN_UNITS)} Modeled Price-Gap Revenue ({BASE_RUN_UNITS:,}-unit run)"
        elif self.disappeared_products:
            pool = sum(_num(p.get('current_price')) for p in self.disappeared_products)
            opp_label = f"{usd(pool)} Stockout-Capture Pool (last known prices)"
        else:
            opp_label = "$0.00 Immediate Gap Opportunity (compete on differentiation instead)"
        dash_rec = ("These three numbers summarize the full report below. Start with the highest-leverage insight for this competitor's specific structure."
                    if paid else "Upgrade to Pro for the full vulnerability breakdown, financial execution blueprint, and stockout monitoring.")
        out.insert(0, self._mk(
            "dashboard_summary", "Executive Dashboard",
            f"{critical_high} Critical/High-Priority Findings | {opp_label} | Vulnerability Score: {score}/100",
            dash_rec, "critical" if score > 70 else "high" if score > 40 else "medium", overall_conf, ts, tag=False))

        out = self._finalize(out)
        self.snapshot_entry = {"name": self.name, **self._snapshot(d)}
        self.logger.info(f"[ENGINE] Generated {len(out)} insights for tier: {self.tier}")
        return out

    def _response_insight(self, d: Dict[str, Any], rm: Dict[str, Any], launch_price: float,
                          ts: str, basis: str) -> Dict[str, Any]:
        probs = rm['probs']
        cost_floor = round(launch_price * (1 - BASE_MARGIN), 2)
        if rm['have_hist']:
            evidence_hist = (f"{rm['cut_skus']} of {rm['tracked']} tracked SKUs ({rm['cut_share'] * 100:.0f}%) were cut at least once and "
                             f"{rm['move_skus']} ({rm['move_share'] * 100:.0f}%) were repriced at all across {d['n_scans']} scans")
        else:
            evidence_hist = "no repricing history yet (first scan), so structure-only evidence is used"
        scen = {
            "hold": (f"Holds price and ignores the launch - evidence: CoV {d['cov']} ({d['cov_interp']}); {evidence_hist}.",
                     f"Launch at {usd(launch_price)}; no defensive repricing is needed."),
            "promo": (f"Answers with a promotion or bundle rather than a list-price cut - evidence: promotional share {d['promo_pct']}% of titles.",
                      "Pre-empt with a bundle or guarantee and do not match the discount."),
            "cut": (f"Matches or undercuts with a list-price cut - evidence: {evidence_hist}; CoV {d['cov']}.",
                    f"Hold {usd(launch_price)} and set a walk-away floor at cost basis ({usd(cost_floor)} = price x (1 - {int(BASE_MARGIN * 100)}% margin))."),
        }
        order = sorted(probs, key=lambda k: -probs[k])
        lines = [f"{i + 1}. {probs[k] * 100:.0f}% - {scen[k][0]}" for i, k in enumerate(order)]
        summary = (f"If you launch at {usd(launch_price)}, the three modeled reactions (propensity-normalized, "
                   f"weights from observed behavior) are:\n" + "\n".join(lines))
        rec = f"Plan for the most likely reaction first: {scen[order[0]][1]} Then cover #2: {scen[order[1]][1]}"
        return self._mk("competitive_response", "Competitive Response Model", summary, rec,
                        "medium", rm['conf'], ts, basis)

    def _delta_insight(self, d: Dict[str, Any], ts: str, basis: str, deep: bool) -> Optional[Dict[str, Any]]:
        pdv = d['price_delta']
        prior = self.portfolio.get(self.comp_id) if self.comp_id else None
        diff = self.scan_diff
        has_diff = bool(diff.get('prev_count'))
        if not (pdv or prior or has_diff):
            return None
        parts: List[str] = []
        if has_diff:
            parts.append(f"{diff.get('new', 0)} new SKU(s) and {diff.get('removed_raw', 0)} removed SKU(s) against {diff['prev_count']} tracked last scan")
        if pdv:
            parts.append(f"average price has {price_delta_phrase(pdv['pct_change'])} ({usd(pdv['prior_avg'])} to {usd(pdv['latest_avg'])})")
        if deep or self.rank >= TIER_RANK['pro']:
            if prior and prior.get('gap_size') is not None and (prior.get('scan_at') or prior.get('avg')):
                pg, ng = _num(prior.get('gap_size')), d['largest_gap_size']
                if pg == 0 and ng > 0:
                    parts.append(f"a {usd(ng)} price gap OPENED ({usd(d['largest_gap_from'])} to {usd(d['largest_gap_to'])})")
                elif pg > 0 and ng == 0:
                    parts.append(f"the prior {usd(pg)} price gap CLOSED")
                elif pg > 0 and ng > 0 and abs(ng - pg) >= 0.01:
                    parts.append(f"the largest price gap {'widened' if ng > pg else 'narrowed'} from {usd(pg)} to {usd(ng)}")
                pv = _num(prior.get('vulnerability'))
                if abs(d['vulnerability_score'] - pv) >= 1:
                    parts.append(f"vulnerability moved from {pv:.0f} to {d['vulnerability_score']}/100")
        others = [v for k, v in self.portfolio.items() if k != self.comp_id and v.get('drift_known')] if self.rank >= TIER_RANK['pro'] else []
        watch = ""
        if others:
            drifts = [_num(o.get('avg_drift_pct')) for o in others]
            rising = sum(1 for x in drifts if x >= PRICE_STABLE_THRESHOLD_PCT)
            falling = sum(1 for x in drifts if x <= -PRICE_STABLE_THRESHOLD_PCT)
            mean_drift = round(sum(drifts) / len(drifts), 2)
            watch = (f" Across your {len(others) + 1} watched competitors, the other {len(others)} moved {mean_drift}% on average "
                     f"({rising} rising, {falling} falling).")
        if not parts and not watch:
            return None
        move = abs(pdv['pct_change']) if pdv else 0.0
        sev = "high" if (move >= 5 or diff.get('removed_raw', 0) >= 5) else "medium"
        overlap = (pdv['overlap_n'] / max(pdv['latest_n'], 1)) if pdv else 0.3
        conf = wconf([(0.6, overlap), (0.4, diff.get('prev_count', 0) / 30.0)])
        summary = f"Since the last scan of {d['competitor_name']}: " + "; ".join(parts) + "." + watch
        rec = ("Review the moves above before touching your own pricing: act on gaps that opened and ignore noise below "
               f"{PRICE_STABLE_THRESHOLD_PCT}% average drift.")
        return self._mk("market_timing", "Watchlist Delta Since Last Scan", summary, rec, sev, conf, ts, basis)

    # ---------------- chart bundle ----------------
    def _build_chart_data(self, d: Dict[str, Any], conf_by_type: Dict[str, float], overall_conf: float) -> Dict[str, Any]:
        prices = [r["price"] for r in self.rows]
        hist: List[Dict[str, Any]] = []
        if prices:
            lo, hi = min(prices), max(prices)
            buckets = 6
            if hi > lo:
                step = (hi - lo) / buckets
                edges = [lo + step * i for i in range(buckets + 1)]
                counts = [0] * buckets
                for pr in prices:
                    counts[min(int((pr - lo) / step), buckets - 1)] += 1
                hist = [{"range": f"${round(edges[i])}-${round(edges[i + 1])}", "count": counts[i]} for i in range(buckets)]
            else:
                hist = [{"range": f"${round(lo)}", "count": len(prices)}]

        cat_stats: Dict[str, List[float]] = {}
        for r in self.rows:
            for kw, rx in self._CAT_RE.items():
                if rx.search(r["norm"]):
                    cat_stats.setdefault(kw, []).append(r["price"])
        cats = [{"name": k, "count": len(v), "avg_price": round(sum(v) / len(v), 2)}
                for k, v in sorted(cat_stats.items(), key=lambda x: -len(x[1]))[:5]]

        chart: Dict[str, Any] = {
            "price_distribution": hist,
            "segments": {"budget": d['budget_pct'], "mid": d['mid_pct'], "premium": d['premium_pct']},
            "categories": cats,
            "price_history": self.hist.daily_avgs()[-12:],
            "signals": {"velocity": d['velocity_pct'], "scarcity": d['scarcity_pct'],
                        "freshness": d['freshness_pct'], "promo": d['promo_pct']},
            "headlines": {"avg": d['avg_price'], "median": d['median_price'], "hhi": d['hhi_score'],
                          "cov": d['cov'], "vulnerability": d['vulnerability_score']},
            # ---- additive keys (v5) ----
            "signals_interpretation": interpret_signals(d['velocity_pct'], d['scarcity_pct'], d['freshness_pct'], d['promo_pct']),
            "confidence": {"overall": overall_conf, "by_type": conf_by_type},
            "portfolio_snapshot": {**self._snapshot(d), "scan_at": datetime.now(timezone.utc).isoformat()},
        }
        pmap = getattr(self, "_pmap", None)
        if pmap and self.rank >= TIER_RANK['pro_plus']:
            chart["portfolio_map"] = {**pmap, "confidence": conf_by_type.get("portfolio_map", 0.0)}
        return chart

    # ---------------- gate / cap / scrub ----------------
    def _enforce_tier_gate(self, insights: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        kept = [i for i in insights if type_allowed(i.get('type', ''), self.tier)]
        dropped = len(insights) - len(kept)
        if dropped:
            self.logger.warning(f"[ENGINE] Tier gate removed {dropped} insight(s) not allowed for tier '{self.tier}'")
        return kept

    def _finalize(self, insights: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        for i in insights:
            if i['type'] == 'chart_bundle':
                continue
            for field_name in ("title", "summary", "ai_recommendation", "detailed_analysis"):
                before = str(i.get(field_name, ""))
                after = scrub(before)
                if after != before:
                    self.logger.warning(f"[ENGINE] WARN scrubbed unsafe token in {i['type']}.{field_name}")
                i[field_name] = after
        cap = TIER_DATA_CAPS[self.tier]['max_insights']
        if len(insights) > cap:
            protected = {"dashboard_summary", "chart_bundle", "executive_summary"}
            keep = [i for i in insights if i['type'] in protected]
            room = max(cap - len(keep), 0)
            rest = [i for i in insights if i['type'] not in protected][:room]
            kept_ids = {id(x) for x in keep + rest}
            dropped = [i['type'] for i in insights if id(i) not in kept_ids]
            msg = f"[ENGINE] WARN insight truncation for tier '{self.tier}': cap {cap}, dropped {len(dropped)} ({', '.join(dropped)})"
            self.logger.warning(msg)
            print_warning(msg)
            insights = [i for i in insights if id(i) in kept_ids]
        return insights

    def _generate_fallback_insights(self) -> List[Dict[str, Any]]:
        timestamp = datetime.now(timezone.utc).isoformat()
        return [{
            "competitor_id": self.comp_id, "type": "executive_summary", "title": "Data Insufficient",
            "summary": f"Scanned {len(self.products)} products, but no valid pricing data was detected.",
            "ai_recommendation": "Ensure the scraper is correctly extracting 'current_price' fields from product pages.",
            "severity": "medium", "created_at": timestamp, "confidence": 0.0,
        }]


class ScraperEngine:
    def __init__(self) -> None:
        self.scrapers = {'shopify': scrape_shopify, 'woocommerce': scrape_woocommerce, 'generic': scrape_generic}
        self.logger = logging.getLogger('ScraperEngine')

    def scrape(self, url: str, platform: Optional[str] = None, max_retries: int = 3,
               max_products: int = 9999) -> Tuple[List[Dict[str, Any]], Optional[ScraperBlockedError]]:
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

                self.logger.warning(f"[EMPTY] {platform} scraper returned 0 products on attempt {attempt + 1}")

            except ScraperBlockedError as be:
                self.logger.warning(f"[BLOCKED] {platform} scraper blocked for {url}: {be.reason}")
                return [], be

            except _HTTP_ERROR_TYPES as he:
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

        self.logger.error(f"Failed to scrape {url} after {max_retries} attempts")
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
    emails_sent: int = 0
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
            f"  {Colors.OKCYAN}Emails sent to users   : {self.emails_sent}{Colors.ENDC}\n"
            f"  Elapsed time           : {elapsed:.1f}s\n"
            f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n"
        )


class VeloraScraper:
    def __init__(self) -> None:
        self.config = Config()
        self.supabase: Optional[Client] = None
        self.db: Optional[DatabaseManager] = None
        self.scraper: Optional[ScraperEngine] = None
        self.email_service: Optional[Any] = None
        self.logger = logging.getLogger('VeloraScraper')
        self._portfolio_cache: Dict[str, Dict[str, Dict[str, Any]]] = {}

    def initialize(self) -> bool:
        print_banner()
        if not self.config.validate():
            return False
        try:
            self.supabase = create_client(self.config.supabase_url, self.config.supabase_key)
            self.db = DatabaseManager(self.supabase)
            self.scraper = ScraperEngine()
            print_success("Connected to Supabase")

            if self.config.emails_enabled:
                try:
                    self.email_service = EmailService(api_key=self.config.resend_api_key)
                    print_success("Resend EmailService initialized")
                except Exception as e:
                    print_warning(f"[EMAIL] EmailService init failed: {e} - emails will be skipped")
                    self.email_service = None
            return True
        except Exception as e:
            print_error(f"Failed to connect to Supabase: {e}")
            return False

    def _portfolio_for(self, user_id: Optional[str]) -> Dict[str, Dict[str, Any]]:
        """ONE pre-load query per user per run; refreshed in-memory after each scan."""
        if not user_id:
            return {}
        if user_id not in self._portfolio_cache:
            self._portfolio_cache[user_id] = self.db.load_portfolio_snapshots(user_id)
            self.logger.info(f"[ENGINE] Portfolio pre-load for user {user_id}: {len(self._portfolio_cache[user_id])} competitor snapshot(s)")
        return self._portfolio_cache[user_id]

    def _send_stockout_alerts(self, competitor_id: str, competitor_name: str,
                              disappeared_products: List[Dict[str, Any]]) -> int:
        """Sends a stockout alert email to every user who owns this competitor."""
        if not self.email_service or not self.db or not disappeared_products:
            return 0

        users = self.db.get_watching_users(competitor_id)
        if not users:
            self.logger.info(f"[EMAIL] No watching users for {competitor_name} - skipping stockout alert")
            return 0

        products_for_email = [
            {"name": str(p.get("title", "Unnamed product"))[:80],
             "price": f"${_num(p.get('current_price')):.2f}"}
            for p in disappeared_products
        ]

        sent = 0
        for user in users:
            user_email = user.get("email")
            user_tier = (user.get("tier") or "free").lower()
            if not user_email:
                continue
            try:
                ok = self.email_service.send_stockout_alert(
                    email=user_email, competitor_name=competitor_name,
                    products=products_for_email, tier=user_tier,
                )
                if ok:
                    sent += 1
            except Exception as e:
                self.logger.warning(f"[EMAIL] Failed to send stockout alert to {user_email}: {e}")

        if sent:
            print_success(f"[EMAIL] Stockout alert sent to {sent} user(s) watching {competitor_name}")
        return sent

    def _send_scan_digest(self, competitor_id: str, competitor_name: str,
                          insights: List[Dict[str, Any]]) -> int:
        """Sends the strategic (human-readable) insights; SKIP_TYPES is the single source of truth."""
        if not self.email_service or not self.db or not insights:
            return 0

        digest_insights = [
            {k: i.get(k) for k in EMAIL_INSIGHT_KEYS}
            for i in insights if i.get("type") not in SKIP_TYPES
        ]
        if not digest_insights:
            return 0

        users = self.db.get_watching_users(competitor_id)
        if not users:
            return 0

        sent = 0
        for user in users:
            user_email = user.get("email")
            user_tier = (user.get("tier") or "free").lower()
            if not user_email:
                continue
            try:
                ok = self.email_service.send_insights_digest(
                    email=user_email, insights=digest_insights,
                    competitor_name=competitor_name, tier=user_tier,
                )
                if ok:
                    sent += 1
            except Exception as e:
                self.logger.warning(f"[EMAIL] Failed to send digest to {user_email}: {e}")

        if sent:
            print_success(f"[EMAIL] Scan digest sent to {sent} user(s) watching {competitor_name}")
        return sent

    def display_intelligence_brief(self, brief: Dict[str, Any], insights: List[Dict[str, Any]]) -> None:
        print_header("PREMIUM MARKET INTELLIGENCE BRIEFING")
        print(f"{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
        print(f"{Colors.BOLD}Target Competitor:{Colors.ENDC} {brief.get('competitor_name')}")
        print(f"{Colors.BOLD}Tier:{Colors.ENDC} {str(brief.get('tier_context', 'free')).upper()}")
        print(f"{Colors.BOLD}Products Analyzed:{Colors.ENDC} {brief.get('products_with_pricing')} / {brief.get('total_products_scanned')}")
        if brief.get('price_delta'):
            dl = brief['price_delta']
            print(f"{Colors.BOLD}Price Delta vs Last Scan:{Colors.ENDC} {price_delta_phrase(dl['pct_change'])} (${dl['prior_avg']} -> ${dl['latest_avg']})")
        print()

        dashboard = next((i for i in insights if i.get('type') == 'dashboard_summary'), None)
        if dashboard:
            print(f"{Colors.BOLD}EXECUTIVE DASHBOARD:{Colors.ENDC}\n  {dashboard.get('summary')}\n")

        exec_insight = next((i for i in insights if i.get('type') == 'executive_summary'), None)
        if exec_insight:
            print(f"{Colors.BOLD}EXECUTIVE SUMMARY:{Colors.ENDC}\n  {exec_insight.get('summary')}\n")

        strategic_types = {
            "pricing_warfare", "product_gap", "competitive_threat", "counter_move", "market_timing",
            "brand_positioning", "customer_psychology", "supply_chain_signal", "category_dominance",
            "financial_blueprint", "strategic_timeline", "quick_wins", "risk_assessment",
            "vulnerability_analysis", "cross_reference", "out_of_stock_signal", "stockout_signal_teaser",
            "price_architecture",
        } | set(NEW_PREMIUM_TYPES)

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

    def scan_competitor(self, competitor: Dict[str, Any], url: str, stats: Optional[RunStats] = None) -> ScanResult:
        competitor_name = competitor.get('name', 'Unknown')
        competitor_id = competitor.get('id')
        tier = normalize_tier(competitor.get('_tier', 'free'))
        limits = competitor.get('_limits', TIER_LIMITS[tier])

        print(f"\n{'='*80}\n[TARGET] Target Acquired: {competitor_name}\n[URL] {url}\n[TIER] {tier.upper()} (max {limits['max_products']} products)\n{'='*80}\n")

        try:
            previous_products = self.db.get_previous_products(competitor_id)

            products, blocked_error = self.scraper.scrape(url, max_products=limits['max_products'])

            if blocked_error:
                print_warning(f"[BLOCKED] {competitor_name}: {blocked_error.reason}")
                self.db.save_blocked_insight(competitor_id, competitor_name, blocked_error.status_code, blocked_error.reason)
                self.db.update_competitor_scan_time(competitor_id)
                return ScanResult.BLOCKED

            if not products:
                print_warning(f"No products found for {competitor_name}")
                return ScanResult.NO_PRODUCTS

            timestamp = datetime.now(timezone.utc).isoformat()
            cleaned_products = [self.scraper.clean_product_data(p, competitor_id, timestamp) for p in products]

            # ONE tier-capped, paginated history load (prior scans only); current rows are appended in memory.
            prior_history, _truncated = self.db.load_price_history(competitor_id, tier)
            prior_index = HistoryIndex(prior_history)

            disappeared_products: List[Dict[str, Any]] = []
            contraction: Optional[Dict[str, Any]] = None
            scan_diff: Dict[str, Any] = {}
            if previous_products:
                current_urls = {normalize_product_url(p.get('product_url')) for p in cleaned_products}
                current_urls.discard("")
                current_titles = {normalize_text(p.get('title')) for p in cleaned_products}
                current_titles.discard("")
                prev_urls = {normalize_product_url(p.get('product_url')) for p in previous_products}
                prev_urls.discard("")

                raw_disappeared = [
                    p for p in previous_products
                    if normalize_product_url(p.get('product_url')) not in current_urls
                    and normalize_text(p.get('title')) not in current_titles
                ]
                scan_diff = {"prev_count": len(previous_products), "new": len(current_urls - prev_urls),
                             "removed_raw": len(raw_disappeared)}

                if raw_disappeared:
                    verdict = classify_disappearance(raw_disappeared, previous_products, current_urls, prior_index)
                    ratio = verdict['ratio']
                    if verdict['mode'] == 'stockout':
                        disappeared_products = verdict['stockouts']
                        print_warning(f"[STOCKOUT] {len(disappeared_products)} product(s) disappeared since last scan for {competitor_name}")
                    elif verdict['mode'] == 'contraction':
                        contraction = verdict['contraction']
                        self.logger.warning(
                            f"[STOCKOUT-GUARD] {len(raw_disappeared)}/{len(previous_products)} ({ratio:.0%}) vanished for "
                            f"{competitor_name} - consistent collection retirement ({verdict['reason']}). Emitting catalog_contraction.")
                    else:
                        self.logger.warning(
                            f"[STOCKOUT-GUARD] {len(raw_disappeared)}/{len(previous_products)} "
                            f"({ratio:.0%}) products appear to have disappeared for {competitor_name} - "
                            f"exceeds plausible ratio and the retirement pattern failed ({verdict['reason']}), likely URL/schema drift. Discarding.")

            if self.db.upsert_products(cleaned_products) == 0:
                print_error(f"Failed to save any products for {competitor_name}")
                return ScanResult.FAILED

            has_history = bool(prior_history) or self.db.has_previous_price_history(competitor_id)
            self.db.save_price_history(cleaned_products, competitor_id, recorded_at=timestamp)
            history_rows = prior_history + DatabaseManager.build_history_rows(cleaned_products, competitor_id, timestamp)

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
                            for _t in moving:
                                _t.setdefault("competitor_id", competitor_id)
                            self.db.save_trend_insights(moving)
                            print_success(f"Saved {len(moving)} real price-movement trends")
                        else:
                            print_info("[SKIP] No real price movements detected")
                except Exception as e:
                    self.logger.error(f"Trend analysis failed for {competitor_name}: {e}")
            else:
                print_info("[SKIP] First scan - skipping trend analysis")

            user_id = competitor.get('user_id')
            portfolio = self._portfolio_for(user_id)

            intel_engine = PremiumDeterministicMarketIntelligenceEngine(
                competitor, products, db=self.db, disappeared_products=disappeared_products,
                history_rows=history_rows, portfolio=portfolio, contraction=contraction, scan_diff=scan_diff,
            )
            insights = intel_engine.generate_all_insights()

            brief = intel_engine.get_data()
            if "error" not in brief and insights:
                self.display_intelligence_brief(brief, insights)

            if insights:
                saved = self.db.save_insights(insights, competitor_id)
                if saved:
                    print_success(f"Saved {len(insights)} premium strategic insights to database")
                    if user_id and intel_engine.snapshot_entry:
                        self._portfolio_cache.setdefault(user_id, {})[competitor_id] = {
                            **intel_engine.snapshot_entry, "scan_at": datetime.now(timezone.utc).isoformat()}

            self.db.update_competitor_scan_time(competitor_id)

            emails_this_scan = 0
            try:
                if disappeared_products:
                    emails_this_scan += self._send_stockout_alerts(competitor_id, competitor_name, disappeared_products)
                if insights:
                    emails_this_scan += self._send_scan_digest(competitor_id, competitor_name, insights)
            except Exception as email_err:
                self.logger.warning(f"[EMAIL] Auto-alert step errored (scan still succeeded): {email_err}")

            if stats is not None:
                stats.emails_sent += emails_this_scan

            print_success(f"[DONE] Mission Complete: {competitor_name}")
            print(f"   - Products Mapped: {len(cleaned_products)}\n   - Insights Generated: {len(insights)}\n   - Emails Sent: {emails_this_scan}")
            return ScanResult.SUCCESS

        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception(f"Unhandled exception scanning {competitor_name} ({url}):")
            return ScanResult.FAILED

    def run_dynamic_mode(self, force_all: bool = False) -> RunStats:
        stats = RunStats()
        print_info("Running in TIER-AWARE DYNAMIC MODE")
        self._portfolio_cache = {}
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
            result = self.scan_competitor(comp, url, stats=stats)
            stats.record(result)
            if i < len(pending):
                time.sleep(5)

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
                tier = self.db.get_user_tier(comp.get('user_id'))
                comp['_tier'] = tier
                comp['_limits'] = TIER_LIMITS[tier]
                stats = RunStats()
                stats.scanned = 1
                result = self.scan_competitor(comp, url, stats=stats)
                stats.record(result)
                print(stats.summary())
                print_info(f"Result: {result.value.upper()}")
        elif force_all:
            self.run_dynamic_mode(force_all=True)
        else:
            self.run_dynamic_mode(force_all=False)


# ===================================================================
# --selftest  (no network, no DB)
# ===================================================================
_ST_COMP_ID = "comp-synth-001"
_ST_BAD_RE = re.compile(r"\bNone\b|\bnan\b|\bNaN\b|Infinity|\binf\b|\{[A-Za-z_][A-Za-z0-9_]*\}")


def _st_products(style: str) -> List[Dict[str, Any]]:
    cats = ["Merino Sweater", "Canvas Backpack", "Leather Belt", "Wool Scarf",
            "Denim Jacket", "Linen Shirt", "Trail Boot", "Cotton Sock"]
    items = []
    for i in range(64):
        base = 24 + (i % 8) * 6 + (i // 8) * 3
        if i >= 60:
            base = 240 + (i - 60) * 10
        if style == "charm":
            price = base + 0.99
            tag = "Bestseller " if i % 16 == 0 else ""
            if i % 20 == 7:
                tag += "Sale "
            title = f"{tag}Model {100 + i} {cats[i % 8]}"
        else:
            price = float(base)
            title = f"Atelier {cats[i % 8]} {chr(65 + i % 26)}{chr(65 + (i // 3) % 26)}"
        items.append({"title": title, "product_url": f"https://example-store.test/products/p{i}",
                      "current_price": price, "image_url": f"https://example-store.test/img/{i}.jpg"})
    return items


def _st_history(products: List[Dict[str, Any]], scans: int = 14) -> List[Dict[str, Any]]:
    start = datetime(2026, 9, 28, 3, 0, tzinfo=timezone.utc)  # a Monday
    rows = []
    for k in range(scans):
        dt = start + timedelta(days=k)
        ts = dt.isoformat()
        for i, p in enumerate(products):
            price = float(p["current_price"])
            if i % 10 == 0 and dt.weekday() == 6:
                price = round(price * 0.85, 2)
            rows.append({"product_url": p["product_url"], "product_title": p["title"], "price": price, "recorded_at": ts})
    return rows


def run_selftest() -> int:
    results: List[Tuple[str, bool, str]] = []

    def check(name: str, cond: bool, detail: str = "") -> None:
        results.append((name, bool(cond), detail))
        print(f"[{'PASS' if cond else 'FAIL'}] {name}" + (f" - {detail}" if detail and not cond else ""))

    logging.getLogger().setLevel(logging.WARNING)
    charm = _st_products("charm")
    premium = _st_products("premium")
    hist_charm = _st_history(charm)
    hist_prem = _st_history(premium)
    portfolio = {
        "comp-synth-002": {"name": "Rival Alpha", "avg": 38.0, "hhi": 3100.0, "vulnerability": 40.0, "gap_size": 0.0,
                           "avg_drift_pct": 1.5, "drift_known": True, "scan_at": "2026-10-13T00:00:00+00:00"},
        "comp-synth-003": {"name": "Rival Beta", "avg": 95.0, "hhi": 1200.0, "vulnerability": 55.0, "gap_size": 40.0,
                           "avg_drift_pct": -2.0, "drift_known": True, "scarcity": 0, "scan_at": "2026-10-13T00:00:00+00:00"},
        _ST_COMP_ID: {"name": "Synthetic Store", "avg": 60.0, "hhi": 2000.0, "vulnerability": 30.0, "gap_size": 0.0,
                      "avg_drift_pct": 0.0, "drift_known": True, "scan_at": "2026-10-13T00:00:00+00:00"},
    }
    gone = [{"title": "Retired Cashmere Wrap", "product_url": "https://example-store.test/products/old1", "current_price": 120.0},
            {"title": "Retired Cashmere Cap", "product_url": "https://example-store.test/products/old2", "current_price": 45.0}]

    outputs: Dict[str, List[Dict[str, Any]]] = {}
    for tier in ("free", "pro", "pro_plus", "enterprise"):
        comp = {"id": _ST_COMP_ID, "name": "Synthetic Store", "_tier": tier, "_limits": TIER_LIMITS[tier]}
        eng = PremiumDeterministicMarketIntelligenceEngine(
            comp, charm, db=None, disappeared_products=gone, history_rows=hist_charm, portfolio=portfolio,
            contraction=({"count": 8, "prev_count": 12, "ratio": 0.667, "stable_share": 0.9, "together_share": 1.0,
                          "mean_obs": 6.0, "replacement": 0.0, "confidence": 0.9, "avg_last_price": 55.0,
                          "price_low": 40.0, "price_high": 80.0, "pool": 440.0, "examples": ["Retired Wrap"]}),
            scan_diff={"prev_count": 12, "new": 0, "removed_raw": 8})
        outputs[tier] = eng.generate_all_insights()
    prem_comp = {"id": _ST_COMP_ID, "name": "Atelier Test", "_tier": "pro_plus", "_limits": TIER_LIMITS["pro_plus"]}
    prem_out = PremiumDeterministicMarketIntelligenceEngine(
        prem_comp, premium, db=None, history_rows=hist_prem, portfolio=portfolio).generate_all_insights()
    all_rows = [r for rows in outputs.values() for r in rows] + prem_out

    # (a) chart bundle keys
    def decode_bundle(rows: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        b = next((r for r in rows if r["type"] == "chart_bundle"), None)
        if not b:
            return None

        def _bad(_c: str) -> None:
            raise ValueError("non-finite number in chart_bundle")
        try:
            return json.loads(b["summary"], parse_constant=_bad)
        except Exception:
            return None
    a_ok = True
    a_detail = ""
    for label, rows in list(outputs.items()) + [("premium-style", prem_out)]:
        bundle = decode_bundle(rows)
        if bundle is None:
            a_ok, a_detail = False, f"{label}: bundle missing/undecodable"
            break
        title_ok = next(r for r in rows if r["type"] == "chart_bundle")["title"] == "Market Visualizations"
        shapes = (isinstance(bundle.get("price_distribution"), list) and isinstance(bundle.get("segments"), dict)
                  and all(k in bundle["segments"] for k in ("budget", "mid", "premium"))
                  and isinstance(bundle.get("categories"), list) and isinstance(bundle.get("price_history"), list)
                  and isinstance(bundle.get("signals"), dict) and all(k in bundle["signals"] for k in ("velocity", "scarcity", "freshness", "promo"))
                  and isinstance(bundle.get("headlines"), dict) and all(k in bundle["headlines"] for k in ("avg", "median", "hhi", "cov", "vulnerability")))
        seg_sum = sum(bundle["segments"].values()) if shapes else 0
        if not (title_ok and shapes and 99.0 <= seg_sum <= 101.0):
            a_ok, a_detail = False, f"{label}: keys/shape/segments-sum invalid ({seg_sum})"
            break
        if any(k not in bundle for k in CHART_FROZEN_KEYS):
            a_ok, a_detail = False, f"{label}: frozen key missing"
            break
    check("(a) chart_bundle decodes with all frozen keys (additive-only)", a_ok, a_detail)

    # (b) vocabulary
    bad_types = sorted({r["type"] for r in all_rows} - ALLOWED_TYPES)
    check("(b) every emitted type is in the allowed vocabulary", not bad_types, str(bad_types))

    # (c) free-tier gate
    free_types = {r["type"] for r in outputs["free"]}
    leaked = sorted(free_types & PAID_ONLY_TYPES)
    check("(c) FREE tier has zero pro-only / new-premium types", not leaked, str(leaked))
    check("(c2) FREE tier receives the teaser, paid tiers do not",
          TEASER_TYPE in free_types and all(TEASER_TYPE not in {r['type'] for r in outputs[t]} for t in ("pro", "pro_plus", "enterprise")))
    inj_eng = PremiumDeterministicMarketIntelligenceEngine(
        {"id": _ST_COMP_ID, "name": "X", "_tier": "free"}, charm, history_rows=[])
    injected = inj_eng._enforce_tier_gate([{"type": "vulnerability_analysis"}, {"type": "portfolio_map"}, {"type": "executive_summary"}])
    check("(c3) gate strips injected premium types from FREE (not index-based)", [i["type"] for i in injected] == ["executive_summary"])
    check("(c4) portfolio_map only for pro_plus/enterprise",
          "portfolio_map" not in {r["type"] for r in outputs["pro"]}
          and "portfolio_map" in {r["type"] for r in outputs["pro_plus"]}
          and "portfolio_map" in {r["type"] for r in outputs["enterprise"]})
    pro_types = {r["type"] for r in outputs["pro"]}
    check("(c5) pro tier carries all six pro-only types and new pro insights",
          {"out_of_stock_signal", "vulnerability_analysis", "financial_blueprint", "quick_wins", "strategic_timeline",
           "cross_reference", "catalog_contraction", "competitive_response", "sku_pressure_index",
           "language_fingerprint", "seasonality_cycle"} <= pro_types, str(sorted(pro_types)))
    check("(c6) unknown tier falls back to free gating",
          all(not type_allowed(t, "platinum-hacker") for t in PAID_ONLY_TYPES))

    # (c7) delta watch sentence is tier-gated (absence for free / presence for paid)
    def _delta_row(rows: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        return next((r for r in rows if r["type"] == "market_timing" and "Watchlist Delta" in r["title"]), None)
    free_clean = all("watched competitors" not in r["summary"] and "Across your" not in r["summary"]
                     for r in outputs["free"] if r["type"] == "market_timing")
    paid_missing = []
    for t in ("pro", "pro_plus", "enterprise"):
        row = _delta_row(outputs[t])
        if row is None or "watched competitors" not in row["summary"]:
            paid_missing.append(t)
    check("(c7) delta watch sentence is tier-gated", free_clean and not paid_missing,
          f"free_clean={free_clean} paid_missing={paid_missing}")

    # (d) vulnerability rubric
    cases = [(10000, 5, 0, 99, 100, 0, 99), (0, 0, 50, 0, 0, 500, 0), (2600, 0.5, 2, 5, 35, 20, 3), (1500, 0.15, 10, 0, 0, 100, 0)]
    d_ok, d_detail = True, ""
    for args in cases:
        v = compute_vulnerability(*args)
        wsum = sum(f["weight"] for f in v["factors"])
        if not (0 <= v["score"] <= 100 and abs(sum(f["points"] for f in v["factors"]) - v["score"]) <= 0.5 + 1e-9
                and abs(wsum - 100.0) < 1e-9 and all(0.0 <= f["sub"] <= 1.0 for f in v["factors"])):
            d_ok, d_detail = False, f"case {args}: {v['score']}"
            break
    maxed = compute_vulnerability(10000, 5, 0, 99, 100, 0, 99)
    check("(d) vulnerability rubric within [0,100], weights sum 100, breakdown sums to score", d_ok and maxed["score"] == 100, d_detail)

    # (e) unsafe strings
    e_bad = []
    for r in all_rows:
        if r["type"] == "chart_bundle":
            continue
        for fld in ("title", "summary", "ai_recommendation"):
            if _ST_BAD_RE.search(str(r.get(fld, ""))):
                e_bad.append(f"{r['type']}.{fld}")
    check("(e) no unbound placeholder / None / nan / Infinity in any insight string", not e_bad, str(e_bad))

    # (f) competitor_id
    f_bad = [r["type"] for r in all_rows if not r.get("competitor_id") or r["competitor_id"] != _ST_COMP_ID]
    check("(f) every row carries a real, non-empty competitor_id", not f_bad, str(f_bad))

    # extras
    check("dashboard_summary is at index 0 for every tier", all(rows[0]["type"] == "dashboard_summary" for rows in outputs.values()))
    conf_bad = [r["type"] for r in all_rows if not (0.0 <= _num(r.get("confidence"), -1) <= 1.0)]
    check("every insight has a confidence in [0,1]", not conf_bad, str(conf_bad))
    sev_bad = [r["type"] for r in all_rows if r.get("severity") not in ("low", "medium", "high", "critical")]
    check("severity vocabulary is valid", not sev_bad, str(sev_bad))
    pa_charm = next(r for r in outputs["pro"] if r["type"] == "price_architecture")["ai_recommendation"]
    pa_prem = next(r for r in prem_out if r["type"] == "price_architecture")["ai_recommendation"]
    check("charm-pricing logic: high psych% -> MATCH endings", "Match their charm endings" in pa_charm and "Do NOT" not in pa_charm, pa_charm[:80])
    check("charm-pricing logic: ~0 psych% -> AVOID charm endings (no .95/.97 advice)",
          "Do NOT use charm endings" in pa_prem and "Mirror" not in pa_prem and ".95/.97 ladder would" in pa_prem, pa_prem[:80])
    prem_bundle = decode_bundle(prem_out) or {}
    interp = (prem_bundle.get("signals_interpretation") or {})
    check("zero-signals brand gets a strategic interpretation", interp.get("state") == "silent" and "brand equity" in interp.get("detail", ""), str(interp)[:80])
    fb = next(r for r in outputs["pro_plus"] if r["type"] == "financial_blueprint")["ai_recommendation"]
    check("margin matrix renders 3 margins in pro_plus, base case only in pro",
          fb.count("Margin ") == 3 and "Margin " not in next(r for r in outputs["pro"] if r["type"] == "financial_blueprint")["ai_recommendation"])
    vuln_txt = next(r for r in outputs["pro"] if r["type"] == "vulnerability_analysis")["summary"]
    check("vulnerability insight shows per-factor breakdown", vuln_txt.count("pts (sub-score") == 7)
    # smart stockout guard
    prev = [{"product_url": f"https://s.test/p{i}", "title": f"Old {i}", "current_price": 50.0 + i} for i in range(10)]
    stable_hist = HistoryIndex([{"product_url": p["product_url"], "product_title": p["title"], "price": p["current_price"],
                                 "recorded_at": f"2026-10-0{k + 1}T03:00:00+00:00"} for p in prev for k in range(5)])
    keep_urls = {normalize_product_url(prev[0]["product_url"]), normalize_product_url(prev[1]["product_url"])}
    verdict = classify_disappearance(prev[2:], prev, keep_urls, stable_hist)
    check("stockout guard: stable + vanished together -> contraction", verdict["mode"] == "contraction" and verdict["contraction"]["count"] == 8, str(verdict["mode"]))
    drift = classify_disappearance(prev[2:], prev, keep_urls | {f"s.test/new{i}" for i in range(20)}, stable_hist)
    check("stockout guard: replaced URLs -> drift (discarded)", drift["mode"] == "drift", str(drift["mode"]))
    blind = classify_disappearance(prev[2:], prev, keep_urls, HistoryIndex([]))
    check("stockout guard: no history -> drift (never guess retirement)", blind["mode"] == "drift", str(blind["mode"]))
    small = classify_disappearance(prev[:2], prev, {normalize_product_url(p["product_url"]) for p in prev[2:]}, stable_hist)
    check("stockout guard: small disappearance -> normal stockout path", small["mode"] == "stockout")
    pm = build_portfolio_map([{"name": "A", "avg": 30.0, "hhi": 3000.0}, {"name": "B", "avg": 90.0, "hhi": 1000.0}, {"name": "C", "avg": 35.0, "hhi": 2800.0}])
    check("portfolio map builds quadrants and a white-space point", bool(pm) and pm["white_space"]["min_distance"] > 0 and len(pm["points"]) == 3)
    check("portfolio map needs >=2 competitors", build_portfolio_map([{"name": "A", "avg": 30.0, "hhi": 3000.0}]) is None)
    check("scrub() neutralizes unsafe tokens", "n/a" in scrub("price None and {oops}") and "None" not in scrub("price None"))

    failed = [n for n, ok, _ in results if not ok]
    print(f"\nSELFTEST RESULT: {len(results) - len(failed)}/{len(results)} checks passed")
    if failed:
        print("FAILED: " + "; ".join(failed))
        return 1
    print("ALL CHECKS PASSED")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=f"Velora v{VERSION} - Logical Rigor + Portfolio Intelligence + Auto Email Alerts",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('url', nargs='?', help='Store URL to scan (optional)')
    parser.add_argument('--continuous', '-c', action='store_true', help='Run continuously')
    parser.add_argument('--force-all', '-f', action='store_true', help='Force scan all competitors')
    parser.add_argument('--selftest', action='store_true', help='Run offline self-test (no network, no DB) and exit')
    args = parser.parse_args()

    if args.selftest:
        sys.exit(run_selftest())

    scraper = VeloraScraper()
    scraper.run(url=args.url, continuous=args.continuous, force_all=args.force_all)


if __name__ == "__main__":
    main()
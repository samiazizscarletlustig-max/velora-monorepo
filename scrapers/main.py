"""
Velora v5.2 — Deterministic Competitive Intelligence Engine
============================================================
Architecture: GitHub Actions (hourly) → Scraper → Math Engine → Supabase → Flutter
Tiers: free(24h) / pro(6h) / pro_plus(3h) / enterprise(1h)
Zero AI cost. Every number traceable to a formula.
"""

import os, sys, time, json, math, logging, argparse, re, inspect, asyncio, statistics
from pathlib import Path
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse
from typing import List, Dict, Optional, Any, Tuple, Iterator
from functools import wraps
from collections import Counter
from dataclasses import dataclass, field
from enum import Enum

# ===================================================================
# VERSION & CONFIGURATION
# ===================================================================
VERSION = "5.2.0"
SELFTEST_MODE = "--selftest" in sys.argv

SCRAPERS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRAPERS_DIR))
sys.path.insert(0, str(SCRAPERS_DIR.parent))

# Optional dependencies (selftest runs without them)
try:
    import requests
except ImportError:
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
    Client = Any

try:
    from core.platform_detector import detect_platform
    from platforms.shopify_scraper import scrape_shopify
    from platforms.woocommerce_scraper import scrape_woocommerce
    from platforms.generic_scraper import scrape_generic
    from core.trend_analyzer import TrendAnalyzer
except ImportError:
    if not SELFTEST_MODE:
        raise
    detect_platform = scrape_shopify = scrape_woocommerce = scrape_generic = TrendAnalyzer = None

try:
    from ai.email_sender import EmailService
    _EMAIL_AVAILABLE = True
except ImportError:
    _EMAIL_AVAILABLE = False

_HTTP_ERRORS = (requests.exceptions.HTTPError,) if requests else ()

# ===================================================================
# TIER SYSTEM (frozen)
# ===================================================================
TIER_LIMITS = {
    'free':       {'max_competitors': 3,    'scan_interval_hours': 24, 'max_products': 300},
    'pro':        {'max_competitors': 10,   'scan_interval_hours': 6,  'max_products': 1000},
    'pro_plus':   {'max_competitors': 25,   'scan_interval_hours': 3,  'max_products': 2500},
    'enterprise': {'max_competitors': 9999, 'scan_interval_hours': 1,  'max_products': 9999},
}
TIER_RANK = {'free': 0, 'pro': 1, 'pro_plus': 2, 'enterprise': 3}

TIER_DATA_CAPS = {
    'free':       {'max_insights': 40,  'history_rows': 1000},
    'pro':        {'max_insights': 100, 'history_rows': 3000},
    'pro_plus':   {'max_insights': 200, 'history_rows': 6000},
    'enterprise': {'max_insights': 400, 'history_rows': 12000},
}

# ===================================================================
# ANALYTICAL THRESHOLDS (documented, every number traces here)
# ===================================================================
HHI_HIGH, HHI_MODERATE, HHI_SUB_CEILING = 2500.0, 1500.0, 5000.0
COV_DISCIPLINED, COV_OPPORTUNISTIC, COV_SUB_CEILING = 0.15, 0.40, 0.60
PRICE_GAP_AVG_RATIO, BUDGET_RATIO, PREMIUM_RATIO = 0.25, 0.6, 1.5
CHARM_ENDINGS = frozenset({99, 95, 97, 49, 90, 88})
PSYCH_HIGH, PSYCH_LOW = 60.0, 30.0
ZERO_SIGNAL_EPS, LOUD_SIGNAL_MEAN = 1.0, 15.0

# v5.1+ parameters
MIN_CAT_SAMPLES = 3
COV_STRUCTURAL_GAP = 0.15
COVERAGE_TRUST_FLOOR = 0.90
HISTORY_MIN_SCANS = 3
CUT_PRIOR_NO_HISTORY = 0.25

# Policy levers
FLASH_DISCOUNT, FLASH_HOURS = 0.15, 48
SPECIALIST_UNDERCUT, HERO_UNDERCUT = 0.10, 0.05
PRICE_TEST_BAND, BUNDLE_PRICE_FACTOR = 0.05, 1.6
PREMIUM_ALT_MULT, ACTION_WINDOW = 1.2, "48-72 hours"

# Margin simulator
BASE_MARGIN, MARGIN_GRID, UNIT_GRID = 0.45, (0.35, 0.45, 0.55), (500, 1000, 2000)
BASE_RUN_UNITS, LAUNCH_COST_RATIO = 1000, 0.25

# Confidence
CONF_DIRECTIVE, CONF_WORKING = 0.75, 0.50
VOICE_PREFIX = {"directive": "Directive:", "working": "Recommended:", "hypothesis": "Hypothesis to test:"}

# Stockout guard
CONTRACTION_MIN_ITEMS, CONTRACTION_MIN_OBS = 3, 3
CONTRACTION_STABLE_RANGE, CONTRACTION_STABLE_SHARE = 0.05, 0.70
CONTRACTION_TOGETHER_SHARE, CONTRACTION_MAX_REPLACEMENT = 0.80, 0.50
MAX_PLAUSIBLE_STOCKOUT_RATIO = 0.4
PRICE_STABLE_THRESHOLD_PCT = 0.5

# Seasonality & pressure
SEASON_MIN_TRANSITIONS, SEASON_MIN_SPAN_DAYS = 20, 3.0
SEASON_MIN_BUCKET_OBS, SEASON_MIN_BUCKET_CUTS = 10, 3
SEASON_LIFT, SKU_MIN_TRANSITIONS, SKU_PRESSURE_TOP_N = 2.0, 2, 5

HISTORY_PAGE_SIZE, DB_CHUNK_SIZE = 1000, 500

# ===================================================================
# TYPE VOCABULARY & TIER GATING
# ===================================================================
VOCAB_BASE = frozenset({
    "executive_summary", "product_gap", "category_dominance", "competitive_threat",
    "pricing_warfare", "market_timing", "price_architecture", "quick_wins",
    "strategic_timeline", "cross_reference", "vulnerability_analysis", "financial_blueprint",
    "out_of_stock_signal", "stockout_signal_teaser", "scan_blocked", "trend",
    "chart_bundle", "dashboard_summary",
})
PRO_ONLY_TYPES = frozenset({
    "out_of_stock_signal", "vulnerability_analysis", "financial_blueprint",
    "quick_wins", "strategic_timeline", "cross_reference",
})
TEASER_TYPE = "stockout_signal_teaser"
NEW_PREMIUM_MIN_TIER = {
    "catalog_contraction": "pro", "competitive_response": "pro",
    "sku_pressure_index": "pro", "language_fingerprint": "pro",
    "seasonality_cycle": "pro", "portfolio_map": "pro_plus",
}
NEW_PREMIUM_TYPES = frozenset(NEW_PREMIUM_MIN_TIER)
ALLOWED_TYPES = VOCAB_BASE | NEW_PREMIUM_TYPES
PAID_ONLY_TYPES = PRO_ONLY_TYPES | NEW_PREMIUM_TYPES
MIN_TIER_BY_TYPE = {**{t: "pro" for t in PRO_ONLY_TYPES}, **NEW_PREMIUM_MIN_TIER}

SKIP_TYPES = frozenset({"chart_bundle", "dashboard_summary"})
EMAIL_INSIGHT_KEYS = ("type", "title", "summary", "ai_recommendation", "severity")
DB_INSIGHT_COLUMNS = ("competitor_id", "type", "title", "summary", "ai_recommendation", "severity", "created_at")
CHART_FROZEN_KEYS = ("price_distribution", "segments", "categories", "price_history", "signals", "headlines")
WRITE_DETAILED_ANALYSIS = os.getenv("VELORA_WRITE_DETAILED_ANALYSIS", "0") == "1"

# ===================================================================
# PURE HELPERS
# ===================================================================
def normalize_tier(tier: Optional[str]) -> str:
    t = str(tier or "free").strip().lower()
    return t if t in TIER_RANK else "free"

def type_allowed(insight_type: str, tier: str) -> bool:
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

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S',
    handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler(SCRAPERS_DIR / 'scraper.log', encoding='utf-8')]
)
logger = logging.getLogger('VeloraScraper')
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

# Colors
class Colors:
    HEADER, OKBLUE, OKCYAN, OKGREEN, WARNING, FAIL, ENDC, BOLD = (
        '\033[95m', '\033[94m', '\033[96m', '\033[92m', '\033[93m', '\033[91m', '\033[0m', '\033[1m'
    )

def print_banner():
    print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.OKBLUE} Velora v{VERSION} — Deterministic Market Intelligence{Colors.ENDC}")
    print(f"{Colors.OKCYAN}   Weighted Rubric | Confidence Scoring | Portfolio Map | Auto-Email{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")

def print_success(msg): print(f"{Colors.OKGREEN}[OK] {msg}{Colors.ENDC}")
def print_error(msg): print(f"{Colors.FAIL}[ERR] {msg}{Colors.ENDC}")
def print_warning(msg): print(f"{Colors.WARNING}[WARN] {msg}{Colors.ENDC}")
def print_info(msg): print(f"{Colors.OKBLUE}[INFO] {msg}{Colors.ENDC}")
def print_header(msg): print(f"\n{Colors.BOLD}{Colors.OKCYAN}{msg}{Colors.ENDC}")

# Text helpers
_WS_RE = re.compile(r"\s+")

def normalize_text(text: Optional[str]) -> str:
    if not text: return ""
    cleaned = text.replace("\xa0", " ").replace("\u2019", "'").replace("\u2018", "'")
    return _WS_RE.sub(" ", cleaned).strip().lower()

def normalize_product_url(url: Optional[str]) -> str:
    if not url: return ""
    u = url.strip().lower()
    u = re.sub(r'^https?://', '', u)
    u = re.sub(r'^www\.', '', u)
    u = u.split('?')[0].split('#')[0].rstrip('/')
    return u

def _chunked(items: List[Any], size: int) -> List[List[Any]]:
    return [items[i:i + size] for i in range(0, len(items), size)]

def _num(x: Any, default: float = 0.0) -> float:
    try:
        v = float(x)
        return v if math.isfinite(v) else default
    except (TypeError, ValueError):
        return default

def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))

def usd(x: Any) -> str:
    return f"${_num(x):,.2f}"

def wconf(pairs: List[Tuple[float, float]]) -> float:
    total_w = sum(w for w, _ in pairs)
    if total_w <= 0: return 0.0
    return round(clamp(sum(w * clamp(_num(s)) for w, s in pairs) / total_w), 2)

def voice_label(conf: float) -> str:
    if conf >= CONF_DIRECTIVE: return "directive"
    if conf >= CONF_WORKING: return "working"
    return "hypothesis"

def percentile(sorted_vals: List[float], q: float) -> float:
    if not sorted_vals: return 0.0
    if len(sorted_vals) == 1: return sorted_vals[0]
    pos = clamp(q) * (len(sorted_vals) - 1)
    lo, hi = int(math.floor(pos)), int(math.ceil(pos))
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (pos - lo)

def price_delta_phrase(pct_change: float) -> str:
    if abs(pct_change) < PRICE_STABLE_THRESHOLD_PCT:
        return "remained essentially flat"
    direction = "risen" if pct_change > 0 else "fallen"
    return f"{direction} {abs(pct_change)}%"

# Timestamp parsing
_TS_FRAC_RE = re.compile(r"\.(\d+)")
_TS_SHORT_OFFSET_RE = re.compile(r"([+-]\d{2})$")

def parse_ts(value: Any) -> Optional[datetime]:
    if isinstance(value, datetime): return value
    if not value: return None
    s = str(value).strip().replace('Z', '+00:00')
    if ' ' in s and 'T' not in s: s = s.replace(' ', 'T', 1)
    s = _TS_FRAC_RE.sub(lambda m: "." + (m.group(1) + "000000")[:6], s, count=1)
    if _TS_SHORT_OFFSET_RE.search(s) and 'T' in s and s.count(':') == 2:
        s = s + ":00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None: dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

# Safety scrub
_BAD_TOKEN_RE = re.compile(r"\bNone\b|\bnan\b|\bNaN\b|Infinity|\binf\b|\{[A-Za-z_][A-Za-z0-9_]*\}")

def scrub(text: str) -> str:
    return _BAD_TOKEN_RE.sub("n/a", text)

def _jsonable(obj: Any) -> Any:
    if isinstance(obj, float): return obj if math.isfinite(obj) else 0.0
    if isinstance(obj, dict): return {str(k): _jsonable(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)): return [_jsonable(v) for v in obj]
    return obj

def _kw_regex(words: List[str]) -> "re.Pattern[str]":
    alts = "|".join(re.escape(w) for w in sorted(words, key=len, reverse=True))
    return re.compile(r"(?<![a-z0-9])(?:" + alts + r")(?:s|es)?(?![a-z0-9])")

# v5.1+ helpers
def coverage_consistency(current_n: int, previous_n: int) -> float:
    if previous_n <= 0: return 1.0
    return round(clamp(1.0 - abs(int(current_n) - int(previous_n)) / max(int(previous_n), 1)), 3)

def within_category_cov(cat_prices: Dict[str, List[float]], raw_cov: float) -> Dict[str, Any]:
    num, den, used = 0.0, 0.0, 0
    for _kw, vals in cat_prices.items():
        if len(vals) < MIN_CAT_SAMPLES: continue
        mean = sum(vals) / len(vals)
        if mean <= 0: continue
        try: sd = statistics.stdev(vals)
        except statistics.StatisticsError: sd = 0.0
        num += len(vals) * (sd / mean)
        den += len(vals)
        used += 1
    if den <= 0: return {"value": round(_num(raw_cov), 2), "n_used": 0, "basis": "raw_fallback"}
    return {"value": round(num / den, 2), "n_used": used, "basis": "category"}

def confidence_path(total_cuts: int, span_days: float, n_scans: int, target: float, max_days: int = 365) -> Optional[Dict[str, int]]:
    if span_days <= 0: return None
    cut_rate, scan_rate = total_cuts / span_days, n_scans / span_days
    for x in range(0, max_days + 1):
        c = wconf([(0.4, (total_cuts + cut_rate * x) / 20.0), (0.6, (span_days + x) / 28.0)])
        if c >= target: return {"days": x, "scans": int(math.ceil(scan_rate * x))}
    return None

# ===================================================================
# EXCEPTIONS & BLOCK DETECTION
# ===================================================================
class ScraperBlockedError(Exception):
    def __init__(self, status_code: Optional[int], reason: str = ""):
        self.status_code = status_code
        self.reason = reason or (f"HTTP {status_code}" if status_code else "Blocked")
        super().__init__(self.reason)

BLOCK_SIGNAL_PHRASES = [
    "security issue", "captcha", "access denied", "unusual traffic",
    "are you a human", "bot detection", "automatically identified",
    "verify you are a human", "request blocked", "cloudflare",
    "perimeterx", "please enable javascript and cookies",
]

def detect_block_signal(status_code: Optional[int], body_text: str = "") -> Optional[str]:
    if status_code in (403, 404): return f"HTTP {status_code}"
    lowered = (body_text or "").lower()
    for phrase in BLOCK_SIGNAL_PHRASES:
        if phrase in lowered: return f"Bot-protection: '{phrase}'"
    return None

# ===================================================================
# MARGIN SCENARIO SIMULATOR
# ===================================================================
def margin_scenarios(price: float) -> Dict[str, Any]:
    price = _num(price)
    launch_cost = LAUNCH_COST_RATIO * price * BASE_RUN_UNITS
    rows = []
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
        cells = " | ".join(f"{c['units']:,}u: {'+' if c['profit'] >= 0 else '-'}{usd(abs(c['profit']))}" for c in r["cells"])
        lines.append(f"Margin {int(round(r['margin'] * 100))}%: break-even {r['breakeven_units']:,} units | {cells}")
    return "\n".join(lines)

# ===================================================================
# VULNERABILITY RUBRIC
# ===================================================================
VULN_FACTORS = (
    ("concentration", "Category concentration", 22.0),
    ("pricing_inconsistency", "Pricing inconsistency", 18.0),
    ("promo_rigidity", "Promotional rigidity", 12.0),
    ("ladder_gaps", "Price-ladder gaps", 16.0),
    ("bestseller_dependence", "Bestseller dependence", 8.0),
    ("thin_catalog", "Thin catalog", 8.0),
    ("delisting_churn", "Delisting churn", 16.0),
)

def compute_vulnerability(hhi, cov, promo_pct, n_gaps, velocity_pct, n_priced, n_disappeared, coverage_consistency=1.0):
    hhi, cov, promo_pct, velocity_pct = _num(hhi), _num(cov), _num(promo_pct), _num(velocity_pct)
    cc = clamp(_num(coverage_consistency, 1.0))
    churn_scale = cc if cc < COVERAGE_TRUST_FLOOR else 1.0
    churn_why = f"{n_disappeared} product(s) vanished"
    if churn_scale < 1.0:
        churn_why += f"; scaled by coverage {cc:.2f}"
    
    subs = {
        "concentration": (clamp((hhi - HHI_MODERATE) / (HHI_SUB_CEILING - HHI_MODERATE)), f"HHI {hhi:,.0f}"),
        "pricing_inconsistency": (clamp((cov - COV_DISCIPLINED) / (COV_SUB_CEILING - COV_DISCIPLINED)), f"within-category CoV {cov:.2f}"),
        "promo_rigidity": (clamp(1.0 - promo_pct / 10.0), f"promo share {promo_pct:.1f}%"),
        "ladder_gaps": (clamp(n_gaps / 6.0), f"{n_gaps} gaps"),
        "bestseller_dependence": (clamp(velocity_pct / 40.0), f"{velocity_pct:.1f}% bestseller tags"),
        "thin_catalog": (clamp(1.0 - n_priced / 100.0), f"{n_priced} products"),
        "delisting_churn": (clamp(n_disappeared / 5.0) * churn_scale, churn_why),
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
# PRICE HISTORY INDEX
# ===================================================================
class HistoryIndex:
    def __init__(self, rows: Optional[List[Dict[str, Any]]]):
        self.by_scan: Dict[datetime, List[float]] = {}
        self.by_url: Dict[str, Dict[datetime, float]] = {}
        self.titles: Dict[str, str] = {}
        for r in rows or []:
            dt = parse_ts(r.get("recorded_at"))
            price = _num(r.get("price"), 0.0)
            if dt is None or price <= 0: continue
            self.by_scan.setdefault(dt, []).append(price)
            key = normalize_product_url(r.get("product_url"))
            if key:
                self.by_url.setdefault(key, {})[dt] = price
                if r.get("product_title"): self.titles[key] = str(r.get("product_title"))
        self.scans = sorted(self.by_scan)
        self._series = {k: sorted(v.items()) for k, v in self.by_url.items()}
    
    @property
    def n_scans(self) -> int: return len(self.scans)
    
    @property
    def span_days(self) -> float:
        if len(self.scans) < 2: return 0.0
        return (self.scans[-1] - self.scans[0]).total_seconds() / 86400.0
    
    def series(self, key: str) -> List[Tuple[datetime, float]]:
        return self._series.get(key, [])
    
    def transitions(self) -> Iterator[Tuple[str, datetime, float, datetime, float]]:
        for key, series in self._series.items():
            for i in range(1, len(series)):
                (d0, p0), (d1, p1) = series[i - 1], series[i]
                yield key, d0, p0, d1, p1
    
    def price_delta(self) -> Optional[Dict[str, Any]]:
        if len(self.scans) < 2: return None
        latest, prior = self.scans[-1], self.scans[-2]
        latest_avg = sum(self.by_scan[latest]) / len(self.by_scan[latest])
        prior_avg = sum(self.by_scan[prior]) / len(self.by_scan[prior])
        if prior_avg <= 0: return None
        both = [(d[prior], d[latest]) for d in self.by_url.values() if prior in d and latest in d]
        lfl = 0.0
        if len(both) >= 3:
            p_sum = sum(a for a, _ in both)
            if p_sum > 0: lfl = round((sum(b for _, b in both) - p_sum) / p_sum * 100, 1)
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
# SMART STOCKOUT GUARD
# ===================================================================
def classify_disappearance(raw_disappeared, previous_products, current_urls, history, coverage=None):
    result = {"mode": "none", "stockouts": [], "contraction": None, "ratio": 0.0, "reason": "", "coverage": 1.0}
    n = len(raw_disappeared)
    if n == 0: return result
    
    prev_n = max(len(previous_products), 1)
    ratio = n / prev_n
    result["ratio"] = ratio
    
    if coverage is None:
        coverage = coverage_consistency(len(current_urls), len(previous_products))
        unexplained_shrink = len(previous_products) - len(current_urls) - n
        drift_pref = coverage < COVERAGE_TRUST_FLOOR and unexplained_shrink > 0
    else:
        drift_pref = coverage < COVERAGE_TRUST_FLOOR
    
    result["coverage"] = coverage
    
    if ratio <= MAX_PLAUSIBLE_STOCKOUT_RATIO and not drift_pref:
        result["mode"] = "stockout"
        result["stockouts"] = list(raw_disappeared)
        return result
    
    prev_urls = {normalize_product_url(p.get("product_url")) for p in previous_products}
    prev_urls.discard("")
    replacement = len(set(current_urls) - prev_urls) / n
    
    obs_counts, last_seen, last_prices, stable = [], [], [], 0
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
    result["reason"] = f"stable={stable_share:.0%} together={together:.0%} replacement={replacement:.0%}"
    if drift_pref: result["reason"] += f" coverage={coverage:.0%}"
    
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
# PORTFOLIO MAP
# ===================================================================
_QUADRANTS = {
    (True, True): "Premium specialists", (True, False): "Premium generalists",
    (False, True): "Value specialists", (False, False): "Value generalists",
}

def build_portfolio_map(entries: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    pts = [e for e in entries if _num(e.get("avg")) > 0 and _num(e.get("hhi"), -1) >= 0]
    if len(pts) < 2: return None
    
    xs, ys = [_num(e["avg"]) for e in pts], [_num(e["hhi"]) for e in pts]
    x_mid, y_mid = statistics.median(xs), statistics.median(ys)
    x_lo, x_hi, y_lo, y_hi = min(xs), max(xs), min(ys), max(ys)
    span_x = (x_hi - x_lo) or max(x_hi * 0.25, 1.0)
    span_y = (y_hi - y_lo) or max(y_hi * 0.25, 100.0)
    
    points, quad_counts = [], Counter()
    for e, x, y in zip(pts, xs, ys):
        label = _QUADRANTS[(x > x_mid, y > y_mid)]
        quad_counts[label] += 1
        points.append({"name": str(e.get("name", "Competitor")), "x": round(x, 2), "y": round(y, 1), "quadrant": label})
    
    win_x0, win_x1 = max(x_lo - 0.25 * span_x, 0.01), x_hi + 0.25 * span_x
    win_y0, win_y1 = max(y_lo - 0.25 * span_y, 0.0), min(y_hi + 0.25 * span_y, 10000.0)
    
    best = (-1.0, x_mid, y_mid)
    for i in range(9):
        cx = win_x0 + (win_x1 - win_x0) * i / 8
        for j in range(9):
            cy = win_y0 + (win_y1 - win_y0) * j / 8
            dmin = min(math.hypot((cx - x) / span_x, (cy - y) / span_y) for x, y in zip(xs, ys))
            if dmin > best[0]: best = (dmin, cx, cy)
    
    d, wx, wy = best
    white = {"avg_price": round(wx, 2), "hhi": round(wy, 1), "min_distance": round(d, 2),
             "quadrant": _QUADRANTS[(wx > x_mid, wy > y_mid)]}
    empty = [label for label in _QUADRANTS.values() if quad_counts.get(label, 0) == 0]
    
    return {"points": points, "x_mid": round(x_mid, 2), "y_mid": round(y_mid, 1),
            "white_space": white, "empty_quadrants": empty,
            "quadrant_counts": {k: int(v) for k, v in quad_counts.items()}}

# ===================================================================
# SIGNALS INTERPRETATION
# ===================================================================
def interpret_signals(vel, scar, fresh, promo):
    vals = {"velocity": _num(vel), "scarcity": _num(scar), "freshness": _num(fresh), "promo": _num(promo)}
    per = {k: ("silent" if v <= ZERO_SIGNAL_EPS else "heavy" if v > 20.0 else "active") for k, v in vals.items()}
    active = [k for k, s in per.items() if s != "silent"]
    silent = [k for k, s in per.items() if s == "silent"]
    mean_sig = sum(vals.values()) / 4.0
    
    if not active:
        return {"state": "silent", "per_signal": per, "headline": "No urgency signaling",
                "detail": "Competes on brand equity, not discounts. Attack with value/positioning."}
    
    state = "loud" if mean_sig >= LOUD_SIGNAL_MEAN else "mixed"
    parts = ", ".join(f"{k} {vals[k]:.1f}%" for k in active)
    
    if state == "loud":
        head, meaning = "Heavy urgency signaling", "Inventory pressure or acquisition push. Counter with bundles."
    else:
        head, meaning = "Selective urgency signaling", "Contest active channels, compete on positioning where silent."
    
    silent_txt = f" Silent: {', '.join(silent)}." if silent else ""
    return {"state": state, "per_signal": per, "headline": head,
            "detail": f"Active: {parts}.{silent_txt} {meaning}"}

# ===================================================================
# CONFIG & DATABASE
# ===================================================================
class Config:
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        self.scan_interval = int(os.getenv("SCAN_INTERVAL", "86400"))
        self.max_retries = int(os.getenv("MAX_RETRIES", "3"))
        self.resend_api_key = os.getenv("RESEND_API_KEY")
        self.emails_enabled = bool(self.resend_api_key) and _EMAIL_AVAILABLE
    
    def validate(self) -> bool:
        if not self.supabase_url or not self.supabase_key:
            print_error("Missing Supabase credentials")
            return False
        print_info("[ENGINE] Deterministic Analytics Engine — zero AI cost")
        if self.emails_enabled:
            print_success("[EMAIL] Resend auto-alerts enabled")
        else:
            print_warning("[EMAIL] Disabled")
        return True

class DatabaseManager:
    def __init__(self, supabase: Client):
        self.supabase = supabase
        self.logger = logging.getLogger('DatabaseManager')
    
    def get_pending_competitors(self, force_all: bool = False) -> List[Dict[str, Any]]:
        try:
            response = self.supabase.table("competitors").select(
                "id, name, website, shopify_store, user_id, last_scan_at"
            ).order("last_scan_at", desc=False, nullsfirst=True).limit(500).execute()
            rows = response.data or []
            if not rows:
                self.logger.info("Found 0 competitors")
                return []
            
            user_ids = list({r.get('user_id') for r in rows if r.get('user_id')})
            tiers = {}
            if user_ids:
                ures = self.supabase.table("users").select("id, tier").in_("id", user_ids).execute()
                tiers = {u['id']: normalize_tier(u.get('tier')) for u in (ures.data or [])}
            
            now = datetime.now(timezone.utc)
            pending, per_user = [], {}
            
            for row in rows:
                uid = row.get('user_id')
                tier = tiers.get(uid, 'free') if uid else 'free'
                limits = TIER_LIMITS.get(tier, TIER_LIMITS['free'])
                per_user[uid] = per_user.get(uid, 0) + 1
                
                if per_user[uid] > limits['max_competitors']:
                    self.logger.info(f"[SKIP] {row.get('name')} (User: {uid}): tier cap")
                    continue
                
                if not force_all:
                    last = row.get('last_scan_at')
                    last_dt = parse_ts(last) if last else None
                    if last_dt is not None:
                        hours = (now - last_dt).total_seconds() / 3600
                        required = limits['scan_interval_hours']
                        if hours < required:
                            self.logger.info(f"[SKIP] {row.get('name')} ({tier}): {hours:.1f}h ago")
                            continue
                        else:
                            self.logger.info(f"[SCAN] {row.get('name')} ({tier}): READY ({hours:.1f}h >= {required}h)")
                    else:
                        self.logger.info(f"[SCAN] {row.get('name')} ({tier}): Never scanned")
                
                row['_tier'] = tier
                row['_limits'] = limits
                pending.append(row)
            
            self.logger.info(f"Found {len(pending)} competitors to scan")
            return pending
        except Exception as e:
            self.logger.error(f"Failed to fetch competitors: {e}")
            return []
    
    def get_user_tier(self, user_id: Optional[str]) -> str:
        if not user_id: return 'free'
        try:
            res = self.supabase.table("users").select("tier").eq("id", user_id).limit(1).execute()
            if res.data: return normalize_tier(res.data[0].get("tier"))
        except Exception as e:
            self.logger.warning(f"Could not fetch tier: {e}")
        return 'free'
    
    def get_or_create_competitor(self, url: str, user_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        try:
            for check_url in [url, url.rstrip("/") + "/" if not url.endswith("/") else url.rstrip("/")]:
                response = self.supabase.table("competitors").select(
                    "id, name, website, user_id"
                ).eq("website", check_url).execute()
                if response.data: return response.data[0]
            
            store_name = urlparse(url).netloc.replace('www.', '').split('.')[0].capitalize()
            if not user_id:
                result = self.supabase.auth.admin.list_users()
                users = result.get('users', []) if isinstance(result, dict) else (getattr(result, 'users', []) or [])
                if not users:
                    print_error("No users found")
                    return None
                user_id = users[0]['id']
            
            response = self.supabase.table("competitors").insert({
                'name': store_name, 'website': url, 'user_id': user_id,
                'created_at': datetime.now(timezone.utc).isoformat()
            }).execute()
            if response.data:
                print_success(f"Created competitor: {store_name}")
            return response.data[0] if response.data else None
        except Exception as e:
            self.logger.error(f"Failed to create competitor: {e}")
            return None
    
    def get_previous_products(self, competitor_id: str) -> List[Dict[str, Any]]:
        try:
            res = self.supabase.table("products").select(
                "product_url, title, current_price"
            ).eq("competitor_id", competitor_id).execute()
            return res.data or []
        except Exception as e:
            self.logger.warning(f"Could not fetch previous products: {e}")
            return []
    
    def upsert_products(self, products: List[Dict[str, Any]], chunk_size: int = DB_CHUNK_SIZE) -> int:
        total = 0
        for idx, batch in enumerate(_chunked(products, chunk_size), 1):
            try:
                response = self.supabase.table("products").upsert(
                    batch, on_conflict="competitor_id,product_url"
                ).execute()
                total += len(response.data) if response.data else len(batch)
            except Exception as e:
                self.logger.error(f"Failed to upsert batch {idx}: {e}")
        self.logger.info(f"Upserted {total}/{len(products)} products")
        return total
    
    @staticmethod
    def build_history_rows(products, competitor_id: str, recorded_at: str) -> List[Dict[str, Any]]:
        return [{
            "competitor_id": competitor_id,
            "product_url": str(p.get("product_url", ""))[:500],
            "product_title": str(p.get("title", ""))[:200],
            "price": float(_num(p.get("current_price"))),
            "recorded_at": recorded_at,
        } for p in products if _num(p.get("current_price")) > 0]
    
    def save_price_history(self, products, competitor_id: str, chunk_size: int = DB_CHUNK_SIZE, recorded_at: Optional[str] = None):
        now = recorded_at or datetime.now(timezone.utc).isoformat()
        history_rows = self.build_history_rows(products, competitor_id, now)
        if not history_rows: return 0
        total = 0
        for idx, batch in enumerate(_chunked(history_rows, chunk_size), 1):
            try:
                self.supabase.table("price_history").insert(batch).execute()
                total += len(batch)
            except Exception as e:
                self.logger.warning(f"price_history insert failed batch {idx}: {e}")
        self.logger.info(f"Saved {total}/{len(history_rows)} price history records")
        return total
    
    def has_previous_price_history(self, competitor_id: str) -> bool:
        try:
            res = self.supabase.table("price_history").select("id").eq(
                "competitor_id", competitor_id
            ).limit(1).execute()
            return len(res.data or []) > 0
        except Exception as e:
            self.logger.warning(f"Could not check price history: {e}")
            return False
    
    def load_price_history(self, competitor_id: str, tier: str) -> Tuple[List[Dict[str, Any]], bool]:
        cap = TIER_DATA_CAPS[normalize_tier(tier)]['history_rows']
        rows, truncated = [], False
        try:
            offset = 0
            while len(rows) < cap:
                want = min(HISTORY_PAGE_SIZE, cap - len(rows))
                res = self.supabase.table("price_history").select(
                    "product_url, product_title, price, recorded_at"
                ).eq("competitor_id", competitor_id).order(
                    "recorded_at", desc=True
                ).order("product_url", desc=False).range(offset, offset + want - 1).execute()
                batch = res.data or []
                rows.extend(batch)
                if len(batch) < want: break
                offset += want
            if len(rows) >= cap:
                probe = self.supabase.table("price_history").select("recorded_at").eq(
                    "competitor_id", competitor_id
                ).order("recorded_at", desc=True).order("product_url", desc=False).range(cap, cap).execute()
                truncated = bool(probe.data)
        except Exception as e:
            self.logger.warning(f"Could not load price history: {e}")
            return [], False
        if truncated and rows:
            oldest = rows[-1].get("recorded_at")
            rows = [r for r in rows if r.get("recorded_at") != oldest]
            msg = f"[ENGINE] WARN price_history truncated at {cap} rows for {competitor_id}"
            self.logger.warning(msg)
            print_warning(msg)
        rows.reverse()
        return rows, truncated
    
    def get_price_delta(self, competitor_id: str, tier: str = 'free') -> Optional[Dict[str, Any]]:
        rows, _ = self.load_price_history(competitor_id, tier)
        return HistoryIndex(rows).price_delta()
    
    def load_portfolio_snapshots(self, user_id: Optional[str]) -> Dict[str, Dict[str, Any]]:
        out = {}
        if not user_id: return out
        rows = []
        try:
            res = self.supabase.table("ai_insights").select(
                "competitor_id, summary, created_at, competitors!inner(name, user_id)"
            ).eq("type", "chart_bundle").eq("competitors.user_id", user_id).order(
                "created_at", desc=True
            ).limit(500).execute()
            rows = res.data or []
        except Exception as e:
            self.logger.warning(f"Joined portfolio query failed: {e}")
            try:
                comps = self.supabase.table("competitors").select("id, name").eq("user_id", user_id).execute()
                names = {c['id']: c.get('name') for c in (comps.data or [])}
                if names:
                    res = self.supabase.table("ai_insights").select(
                        "competitor_id, summary, created_at"
                    ).eq("type", "chart_bundle").in_("competitor_id", list(names)).order(
                        "created_at", desc=True
                    ).limit(500).execute()
                    rows = res.data or []
                    for r in rows: r['competitors'] = {'name': names.get(r.get('competitor_id'))}
            except Exception as e2:
                self.logger.warning(f"Could not load portfolio: {e2}")
                return out
        
        for r in rows:
            cid = r.get("competitor_id")
            if not cid or cid in out: continue
            joined = r.get("competitors")
            if isinstance(joined, list): joined = joined[0] if joined else {}
            name = (joined or {}).get("name") or "Competitor"
            entry = self.parse_snapshot(r.get("summary"), str(name), r.get("created_at"))
            if entry: out[cid] = entry
        return out
    
    @staticmethod
    def parse_snapshot(summary, name: str, created_at) -> Optional[Dict[str, Any]]:
        try:
            bundle = json.loads(summary) if isinstance(summary, str) else {}
            heads = bundle.get("headlines") or {}
            snap = bundle.get("portfolio_snapshot") or {}
            if _num(heads.get("avg")) <= 0: return None
            return {
                "name": name, "avg": _num(heads.get("avg")), "median": _num(heads.get("median")),
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
                self.logger.error("Refusing to save insights without competitor_id")
                return False
            try:
                self.supabase.table("ai_insights").delete().eq(
                    "competitor_id", comp_id
                ).neq("type", "trend").execute()
            except Exception as e:
                self.logger.warning(f"Could not clear prior insights: {e}")
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
            self.logger.info(f"Saved {len(rows)} insights")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save insights: {e}")
            return False
    
    def save_blocked_insight(self, competitor_id: str, competitor_name: str, status_code, reason: str):
        timestamp = datetime.now(timezone.utc).isoformat()
        status_part = f" (HTTP {status_code})" if status_code else ""
        insight = {
            "competitor_id": competitor_id, "type": "scan_blocked",
            "title": "Scan Blocked",
            "summary": f"Unable to retrieve data for {competitor_name}{status_part}. Reason: {reason}.",
            "ai_recommendation": "Will retry on next scheduled scan.",
            "severity": "medium", "created_at": timestamp,
        }
        try:
            self.supabase.table("ai_insights").delete().eq(
                "competitor_id", competitor_id
            ).eq("type", "scan_blocked").execute()
        except Exception: pass
        try:
            self.supabase.table("ai_insights").insert(insight).execute()
            self.logger.info(f"Recorded 'scan_blocked' for {competitor_name}")
        except Exception as e:
            self.logger.error(f"Failed to save blocked insight: {e}")
    
    def save_trend_insights(self, insights: List[Dict[str, Any]]) -> bool:
        try:
            formatted = [{
                "competitor_id": i.get("competitor_id"), "type": "trend",
                "title": i.get("title", "Trend Analysis"), "summary": i.get("summary", ""),
                "ai_recommendation": i.get("recommendation", ""),
                "severity": str(i.get("severity", "medium")).lower(),
                "created_at": datetime.now(timezone.utc).isoformat()
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
            self.supabase.table("competitors").update({
                "last_scan_at": datetime.now(timezone.utc).isoformat()
            }).eq("id", competitor_id).execute()
            return True
        except Exception as e:
            self.logger.error(f"Failed to update timestamp: {e}")
            return False
    
    def get_watching_users(self, competitor_id: str) -> List[Dict[str, Any]]:
        try:
            comp_res = self.supabase.table("competitors").select("user_id").eq(
                "id", competitor_id
            ).execute()
            if not comp_res.data: return []
            user_ids = list({row["user_id"] for row in comp_res.data if row.get("user_id")})
            if not user_ids: return []
            user_res = self.supabase.table("users").select("id, email, tier").in_(
                "id", user_ids
            ).execute()
            return [u for u in (user_res.data or []) if u.get("email")]
        except Exception as e:
            self.logger.warning(f"Could not fetch watching users: {e}")
            return []

# ===================================================================
# THE ENGINE
# ===================================================================
_TECH_WORDS = frozenset({"pro", "max", "ultra", "series", "gen", "spec", "tech", "technical",
                         "performance", "waterproof", "breathable", "mm", "cm", "kg", "oz",
                         "ml", "gb", "hz", "mah"})
_EMOTIVE_WORDS = frozenset({"love", "dream", "joy", "soul", "wild", "bliss", "cozy", "magic",
                            "happy", "beautiful", "heart", "golden", "sunset", "whisper", "dawn",
                            "paradise", "bloom", "serene", "spirit", "muse", "enchanted", "ritual",
                            "cherish", "devotion"})
_WORD_RE = re.compile(r"[a-z0-9][a-z0-9'\-]*")
_WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
_VOICE_BLURB = {
    "technical": "spec-led titles (materials, dimensions, model codes)",
    "emotional": "benefit-led, feeling-first naming",
    "minimalist": "short, noun-only names",
}
_TITLE_STOP = frozenset({"the", "and", "for", "with", "from", "of", "in", "a", "an", "to", "by",
                         "on", "at", "men", "mens", "women", "womens", "unisex", "pack", "set",
                         "size", "color", "colour"})
_GAP_LEXICON = {
    "technical": ("breathable", "waterproof", "performance", "technical", "series", "spec", "ultra", "max", "pro"),
    "emotional": tuple(sorted(_EMOTIVE_WORDS)),
    "minimalist": (),
}

class PremiumDeterministicMarketIntelligenceEngine:
    CATEGORY_KEYWORDS = [
        "shirt", "pant", "shoe", "dress", "jacket", "bag", "hat", "sock", "accessory", "sweater",
        "hoodie", "short", "skirt", "coat", "boot", "sandal", "sneaker", "scarf", "belt", "watch",
        "jewelry", "legging", "tank", "bra", "jogger", "tee", "backpack", "oil", "balm", "kit",
        "underwear", "boxer", "glove", "strap"
    ]
    PROMOTION_KEYWORDS = ["sale", "off", "discount", "limited", "new", "bestseller", "clearance", "final sale"]
    VELOCITY_KEYWORDS = ["bestseller", "best selling", "popular", "top rated", "favorite", "trending", "most loved"]
    SCARCITY_KEYWORDS = ["low stock", "selling fast", "limited", "final sale", "clearance", "last chance", "only a few left"]
    FRESHNESS_KEYWORDS = ["new in", "just dropped", "new arrival", "fresh", "launch"]
    
    _CAT_RE = {}
    _PROMO_RE = _kw_regex(PROMOTION_KEYWORDS)
    _VEL_RE = _kw_regex(VELOCITY_KEYWORDS)
    _SCAR_RE = _kw_regex(SCARCITY_KEYWORDS)
    _FRESH_RE = _kw_regex(FRESHNESS_KEYWORDS)
    
    def __init__(self, competitor, products, db=None, disappeared_products=None,
                 history_rows=None, portfolio=None, contraction=None, scan_diff=None):
        self.competitor = competitor
        self.products = list(products or [])
        self.db = db
        self.disappeared_products = disappeared_products or []
        self.name = str(competitor.get('name') or 'Unknown')
        self.tier = normalize_tier(competitor.get('_tier'))
        self.rank = TIER_RANK[self.tier]
        self.limits = competitor.get('_limits', TIER_LIMITS[self.tier])
        self.comp_id = competitor.get('id')
        self.logger = logging.getLogger('PremiumDeterministicEngine')
        self.portfolio = dict(portfolio or {})
        self.contraction = contraction
        self.scan_diff = scan_diff or {}
        
        if not self._CAT_RE:
            type(self)._CAT_RE = {kw: _kw_regex([kw]) for kw in self.CATEGORY_KEYWORDS}
        
        if history_rows is None and db is not None and self.comp_id:
            history_rows, _ = db.load_price_history(self.comp_id, self.tier)
        
        self.hist = HistoryIndex(history_rows)
        self.items = [{
            "raw": str(p.get("title") or "").strip(),
            "norm": normalize_text(str(p.get("title") or "")),
            "price": _num(p.get("current_price")),
            "url": str(p.get("product_url") or ""),
        } for p in self.products]
        self.rows = [i for i in self.items if i["price"] > 0]
        self._data = None
        self._rm_last = None
        self.snapshot_entry = {}
    
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
        if not shown: return ""
        if len(shown) == 1: return shown[0]
        return f"{shown[0]} and {shown[1]}"
    
    def _psychological_stats(self) -> Dict[str, Any]:
        if not self.rows: return {"psych_pct": 0.0, "round_pct": 0.0, "top_ending": ""}
        cents = [int(round(r["price"] * 100)) % 100 for r in self.rows]
        n = len(cents)
        charm = Counter(c for c in cents if c in CHARM_ENDINGS)
        top_ending = f".{charm.most_common(1)[0][0]:02d}" if charm else ""
        return {
            "psych_pct": round(sum(charm.values()) / n * 100, 1),
            "round_pct": round(sum(1 for c in cents if c == 0) / n * 100, 1),
            "top_ending": top_ending
        }
    
    def _analyze_data(self) -> Dict[str, Any]:
        prices = [r["price"] for r in self.rows]
        if not prices: return {"error": "No pricing data"}
        
        n = len(prices)
        avg_price = sum(prices) / n
        median_price = statistics.median(prices)
        try: stdev_price = statistics.stdev(prices) if n > 1 else 0.0
        except statistics.StatisticsError: stdev_price = 0.0
        
        budget_threshold = avg_price * BUDGET_RATIO
        premium_threshold = avg_price * PREMIUM_RATIO
        budget_n = sum(1 for p in prices if p < budget_threshold)
        premium_n = sum(1 for p in prices if p > premium_threshold)
        mid_n = n - budget_n - premium_n
        
        category_counts, category_samples, cat_prices = Counter(), {}, {}
        categorized = 0
        for r in self.rows:
            hit = False
            for kw, rx in self._CAT_RE.items():
                if rx.search(r["norm"]):
                    hit = True
                    if kw not in cat_prices: cat_prices[kw] = []
                    cat_prices[kw].append(r["price"])
                    category_counts[kw] += 1
                    samples = category_samples.setdefault(kw, [])
                    if r["raw"] and r["raw"] not in samples and len(samples) < 2:
                        samples.append(r["raw"])
            categorized += 1 if hit else 0
        
        velocity_samples, scarcity_samples, freshness_samples = [], [], []
        promotion_count = budget_promo_count = premium_promo_count = 0
        velocity_count = scarcity_count = freshness_count = 0
        
        for it in self.items:
            title = it["norm"]
            promo_title = title.replace("off-white", "").replace("off white", "")
            if self._PROMO_RE.search(promo_title):
                promotion_count += 1
                if 0 < it["price"] < budget_threshold: budget_promo_count += 1
                elif it["price"] > premium_threshold: premium_promo_count += 1
            if self._VEL_RE.search(title):
                velocity_count += 1
                if it["raw"] and len(velocity_samples) < 2: velocity_samples.append(it["raw"])
            if self._SCAR_RE.search(title):
                scarcity_count += 1
                if it["raw"] and len(scarcity_samples) < 2: scarcity_samples.append(it["raw"])
            if self._FRESH_RE.search(title):
                freshness_count += 1
                if it["raw"] and len(freshness_samples) < 2: freshness_samples.append(it["raw"])
        
        top_categories = category_counts.most_common(5)
        total_cat = sum(category_counts.values())
        hhi = sum((c / total_cat) ** 2 for c in category_counts.values()) if total_cat > 0 else 0.0
        hhi_score = round(hhi * 10000, 1)
        hhi_interp = "highly concentrated" if hhi_score > HHI_HIGH else "moderately concentrated" if hhi_score > HHI_MODERATE else "diversified"
        
        sorted_prices = sorted(prices)
        price_gaps = []
        for i in range(len(sorted_prices) - 1):
            gap = sorted_prices[i + 1] - sorted_prices[i]
            if gap > avg_price * PRICE_GAP_AVG_RATIO:
                price_gaps.append({"from": round(sorted_prices[i], 2), "to": round(sorted_prices[i + 1], 2), "size": round(gap, 2)})
        
        biggest = max(price_gaps, key=lambda g: g["size"]) if price_gaps else None
        largest_gap = ({"from": biggest["from"], "to": biggest["to"], "size": biggest["size"],
                       "ratio_to_avg": round(biggest["size"] / avg_price, 2)} if biggest
                      else {"from": 0.0, "to": 0.0, "size": 0.0, "ratio_to_avg": 0.0})
        
        # Dual CoV
        cov = round(stdev_price / avg_price, 2) if avg_price > 0 else 0.0
        cov_info = within_category_cov(cat_prices, cov)
        cov_w = cov_info["value"]
        cov_interp = ("inconsistent/opportunistic" if cov_w > COV_OPPORTUNISTIC
                     else "disciplined/confident" if cov_w < COV_DISCIPLINED else "moderate")
        structural_diverse = cov_info["basis"] == "category" and (cov - cov_w) >= COV_STRUCTURAL_GAP
        
        # Coverage consistency
        prev_count = int(_num(self.scan_diff.get('prev_count')))
        cov_cons = coverage_consistency(len(self.products), prev_count)
        coverage_low = prev_count > 0 and cov_cons < COVERAGE_TRUST_FLOOR
        coverage_shift_pct = round(abs(len(self.products) - prev_count) / max(prev_count, 1) * 100, 1) if prev_count > 0 else 0.0
        
        total_items = max(len(self.items), 1)
        promo_pct = round(promotion_count / total_items * 100, 1)
        velocity_pct = round(velocity_count / total_items * 100, 1)
        scarcity_pct = round(scarcity_count / total_items * 100, 1)
        freshness_pct = round(freshness_count / total_items * 100, 1)
        
        top_cat = top_categories[0] if top_categories else ("unknown", 0)
        top_cat_pct = round(top_cat[1] / n * 100, 1)
        price_delta = self.hist.price_delta()
        vuln = compute_vulnerability(hhi_score, cov_w, promo_pct, len(price_gaps), velocity_pct, n,
                                    len(self.disappeared_products), cov_cons)
        psych = self._psychological_stats()
        seg = {"budget": round(budget_n / n * 100, 1), "mid": round(mid_n / n * 100, 1), "premium": round(premium_n / n * 100, 1)}
        n_scans = self.hist.n_scans
        
        return {
            "competitor_name": self.name, "tier_context": self.tier,
            "total_products_scanned": len(self.items), "products_with_pricing": n,
            "avg_price": round(avg_price, 2), "median_price": round(median_price, 2),
            "stdev_price": round(stdev_price, 2), "min_price": round(min(prices), 2),
            "max_price": round(max(prices), 2), "p10_price": round(percentile(sorted_prices, 0.10), 2),
            "p90_price": round(percentile(sorted_prices, 0.90), 2),
            "cov": cov, "cov_interp": cov_interp, "cov_within": cov_w,
            "cov_basis": cov_info["basis"], "n_cov_cats": cov_info["n_used"],
            "structural_diverse": structural_diverse,
            "coverage_consistency": cov_cons, "coverage_low": coverage_low,
            "coverage_shift_pct": coverage_shift_pct, "prev_count": prev_count,
            "hhi_score": hhi_score, "hhi_interp": hhi_interp,
            "top_cat": top_cat[0], "top_cat_count": top_cat[1], "top_cat_pct": top_cat_pct,
            "top_cat_samples": category_samples.get(top_cat[0], []),
            "promo_pct": promo_pct, "budget_promo_count": budget_promo_count,
            "premium_promo_count": premium_promo_count, "n_gaps": len(price_gaps),
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
            "cs": clamp(n / 60.0), "cd": clamp((n_scans - 1) / 5.0), "cc": round(categorized / n, 3),
        }
    
    def _basis(self, d) -> str:
        return f"basis: {d['products_with_pricing']} priced products, {d['n_scans']} scans"
    
    def _mk(self, typ, title, summary, rec, severity, conf, ts, basis="", tag=True) -> Dict[str, Any]:
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
    
    def _launch_plan(self, d) -> Tuple[float, str]:
        if d['largest_gap_size'] > 0:
            price = round((d['largest_gap_from'] + d['largest_gap_to']) / 2, 2)
            return price, f"Gap-filler at {usd(price)}"
        anchor = d['top_cat_samples'][0] if d['top_cat_samples'] else f"the {d['top_cat']} line"
        price = round(d['avg_price'] * PREMIUM_ALT_MULT, 2)
        return price, f"Premium alternative to '{anchor}' at {usd(price)}"
    
    def _dual_cov_text(self, d) -> str:
        raw, cw, k = d['cov'], d['cov_within'], d['n_cov_cats']
        if d['cov_basis'] != 'category':
            return f"no category holds {MIN_CAT_SAMPLES}+ products, raw CoV {raw} used"
        if (raw - cw) >= COV_STRUCTURAL_GAP:
            return f"cross-category CoV {raw} (range breadth); within-category CoV {cw} ({k} categories) = {d['cov_interp']}"
        return f"cross-category CoV {raw} ≈ within-category CoV {cw} ({k} categories) = {d['cov_interp']}"
    
    def _price_architecture_rec(self, d) -> str:
        psych, med = d['psych_pct'], d['median_price']
        if psych >= PSYCH_HIGH:
            ending = d['top_ending'] or ".99"
            return f"Match charm endings ({psych}% use them, led by {ending}). Price hero at {usd(round(med * (1 - HERO_UNDERCUT), 2))} ({int(HERO_UNDERCUT * 100)}% under median)."
        if psych <= PSYCH_LOW:
            return f"Do NOT use charm endings ({psych}% use them, {d['round_pct']}% whole-dollar). Price on whole-dollar points at/above {usd(med)} median. Win on value/bundle/guarantee."
        return f"Mixed charm usage ({psych}%). Use charm endings below {usd(med)} median, whole-dollar above."
    
    def _cross_reference_text(self, d) -> Tuple[str, str]:
        hhi, top_pct, cw, gap, top_cat = d['hhi_score'], d['top_cat_pct'], d['cov_within'], d['largest_gap_size'], d['top_cat']
        has_gap = gap > 0
        spec_price = usd(round(d['median_price'] * (1 - SPECIALIST_UNDERCUT), 2))
        
        if hhi > HHI_HIGH and top_pct > 20:
            if has_gap:
                summary = f"Highly concentrated (HHI {hhi}) + {d['cov_interp']} pricing (within-category CoV {cw}). {usd(gap)} gap beside '{top_cat}' ({top_pct}% of catalog)."
                rec = f"Launch premium product in {usd(gap)} gap targeting '{top_cat}' — attacks core revenue at weakest point."
            else:
                summary = f"Highly concentrated (HHI {hhi}, '{top_cat}' {top_pct}%) + {d['cov_interp']} pricing (CoV {cw}). Dense pricing, no gap."
                rec = f"Build '{top_cat}' specialist line at {spec_price} ({int(SPECIALIST_UNDERCUT * 100)}% under median). Narrow catalog can't defend breadth + price."
        elif hhi <= HHI_MODERATE:
            summary = f"Diversified (HHI {hhi}, '{top_cat}' {top_pct}%) + {d['cov_interp']} pricing (CoV {cw}). Risk spread thin."
            rec = "Don't attack single category. Build differentiated brand story around depth in ONE category."
        else:
            zone = d['hhi_interp']
            if has_gap:
                summary = f"{zone} (HHI {hhi}), '{top_cat}' {top_pct}%, {d['cov_interp']} pricing (CoV {cw}). {usd(gap)} gap not tied to single category."
                rec = f"Use {usd(gap)} gap as primary lever, don't over-index on '{top_cat}' alone."
            else:
                summary = f"{zone} (HHI {hhi}, '{top_cat}' {top_pct}%), {d['cov_interp']} pricing (CoV {cw}). No gap, dense pricing."
                rec = f"Bundle core '{top_cat}' items with accessories to raise perceived value without touching price."
        return summary, rec
    
    def _build_quick_wins(self, d) -> List[str]:
        wins, med = [], d['median_price']
        if d['promo_pct'] < 5:
            wins.append(f"Run {FLASH_HOURS}h flash sale at {usd(round(med * (1 - FLASH_DISCOUNT), 2))} ({int(FLASH_DISCOUNT * 100)}% under median) to capture price-sensitive shoppers.")
        if d['largest_gap_size'] > 0:
            wins.append(f"Launch gap-filler at {usd(round((d['largest_gap_from'] + d['largest_gap_to']) / 2, 2))} to occupy {usd(d['largest_gap_size'])} whitespace.")
        else:
            wins.append(f"No gap — bundle two mid-tier SKUs (~{usd(med)} each) into {usd(round(med * BUNDLE_PRICE_FACTOR, 2))} bundle.")
        if self.disappeared_products:
            if d['coverage_low']:
                wins.append(f"Verify {len(self.disappeared_products)} missing items (coverage varied {d['coverage_shift_pct']:.0f}%), then bid on confirmed ones.")
            else:
                wins.append(f"Bid on keywords for {len(self.disappeared_products)} stocked-out items this week.")
        if d['velocity_samples']:
            wins.append(f"Publish comparison content vs bestseller '{d['velocity_samples'][0]}'.")
        if d['top_cat_samples']:
            wins.append(f"Add complementary accessory to '{d['top_cat_samples'][0]}' to raise basket value.")
        return wins[:4]
    
    def _build_timeline(self, d, be_units: int) -> str:
        if d['largest_gap_size'] > 0:
            price = round((d['largest_gap_from'] + d['largest_gap_to']) / 2, 2)
            d30 = f"30 Days: Launch {usd(price)} gap-filler, validate against {be_units:,} break-even units."
        else:
            anchor = d['top_cat_samples'][0] if d['top_cat_samples'] else d['top_cat']
            d30 = f"30 Days: Launch bundled offer around '{anchor}', validate against {be_units:,} break-even units."
        d60 = f"60 Days: Press on concentration (HHI {d['hhi_score']}) by adding SKUs adjacent to '{d['top_cat']}' ({d['top_cat_pct']}% of catalog)."
        d90 = f"90 Days: Keep own within-category CoV ≤ {min(d['cov_within'], COV_DISCIPLINED)} vs their {d['cov_within']}, convert captured segment to repeat purchases."
        return f"{d30}\n{d60}\n{d90}"
    
    def _response_model(self, d) -> Dict[str, Any]:
        thr = PRICE_STABLE_THRESHOLD_PCT
        per = {}
        n_tr = 0
        for key, _d0, p0, _d1, p1 in self.hist.transitions():
            rec = per.setdefault(key, {"cuts": 0, "moves": 0})
            n_tr += 1
            move = (p1 - p0) / p0 * 100 if p0 > 0 else 0.0
            if abs(move) >= thr:
                rec["moves"] += 1
                if move < 0: rec["cuts"] += 1
        
        tracked = len(per)
        cut_skus = sum(1 for r in per.values() if r["cuts"] > 0)
        move_skus = sum(1 for r in per.values() if r["moves"] > 0)
        have_hist = tracked > 0
        cut_share = cut_skus / tracked if have_hist else 0.0
        move_share = move_skus / tracked if have_hist else 0.0
        
        n_scans = d['n_scans']
        cov_w = d['cov_within']
        cov_hold = 1 - clamp(cov_w / COV_OPPORTUNISTIC)
        e_hold = cov_hold * (1 - clamp(move_share / 0.50)) if have_hist else cov_hold
        e_promo = clamp(d['promo_pct'] / 20.0)
        e_cut_raw = (0.6 * clamp(cut_share / 0.25) + 0.4 * clamp(move_share / 0.50)) if have_hist else CUT_PRIOR_NO_HISTORY
        
        never_cut = have_hist and cut_skus == 0
        e_cut = min(e_cut_raw, e_hold) if never_cut else e_cut_raw
        
        total = e_hold + e_promo + e_cut + 0.3
        probs = {"hold": (e_hold + 0.1) / total, "promo": (e_promo + 0.1) / total, "cut": (e_cut + 0.1) / total}
        
        if not have_hist:
            cut_basis = "no history: uninformed prior"
        elif never_cut and n_scans >= HISTORY_MIN_SCANS:
            cut_basis = f"never cut: 0 of {tracked} SKUs cut across {n_scans} scans → low retaliation"
        elif never_cut:
            cut_basis = f"no cuts yet: 0 of {tracked} SKUs cut in {n_scans} scans (short history)"
        else:
            cut_basis = f"{cut_skus} of {tracked} SKUs ({cut_share * 100:.0f}%) cut at least once across {n_scans} scans"
        
        hold_basis = f"within-category CoV {cov_w} ({d['cov_interp']}); {move_skus} of {tracked} SKUs repriced across {n_scans} scans" if have_hist else f"within-category CoV {cov_w} ({d['cov_interp']}); no history"
        promo_basis = f"promo share {d['promo_pct']}% of titles"
        
        conf = wconf([(0.3, d['cs']), (0.4, n_tr / 200.0), (0.3, (d['n_scans'] - 1) / 4.0)])
        rm = {
            "probs": probs, "tracked": tracked, "cut_skus": cut_skus, "move_skus": move_skus,
            "cut_share": cut_share, "move_share": move_share, "n_tr": n_tr, "have_hist": have_hist, "conf": conf,
            "cut_basis": cut_basis, "hold_basis": hold_basis, "promo_basis": promo_basis,
            "never_cut": never_cut, "n_scans": n_scans
        }
        self._rm_last = rm
        return rm
    
    def _sku_pressure(self, d) -> Optional[Dict[str, Any]]:
        thr = PRICE_STABLE_THRESHOLD_PCT
        per = {}
        for key, _d0, p0, _d1, p1 in self.hist.transitions():
            rec = per.setdefault(key, {"trans": 0, "moves": 0, "abs_sum": 0.0})
            rec["trans"] += 1
            move = (p1 - p0) / p0 * 100 if p0 > 0 else 0.0
            if abs(move) >= thr:
                rec["moves"] += 1
                rec["abs_sum"] += abs(move)
        
        ranked, qualifying = [], 0
        for key, r in per.items():
            if r["trans"] < SKU_MIN_TRANSITIONS: continue
            qualifying += 1
            if r["moves"] == 0: continue
            freq = r["moves"] / r["trans"]
            mean_abs = r["abs_sum"] / r["moves"]
            pi = 100.0 * freq * (0.5 + 0.5 * clamp(mean_abs / 20.0))
            series = self.hist.series(key)
            net = (series[-1][1] - series[0][1]) / series[0][1] * 100 if series and series[0][1] > 0 else 0.0
            ranked.append({"key": key, "title": self.hist.titles.get(key, key), "pi": round(pi, 1),
                          "moves": int(r["moves"]), "trans": int(r["trans"]),
                          "mean_abs": round(mean_abs, 1), "net": round(net, 1)})
        
        if not ranked: return None
        ranked.sort(key=lambda x: -x["pi"])
        conf = wconf([(0.4, qualifying / 15.0), (0.6, (d['n_scans'] - 1) / 5.0)])
        return {"top": ranked[:SKU_PRESSURE_TOP_N], "qualifying": qualifying, "volatile": len(ranked), "conf": conf}
    
    def _language_fingerprint(self, d) -> Optional[Dict[str, Any]]:
        titles = [r["norm"] for r in self.rows if r["norm"]]
        if len(titles) < 10: return None
        n = len(titles)
        words_per, tech_n, emo_n, mini_n, long_n = [], 0, 0, 0, 0
        all_tokens = []
        
        for t in titles:
            toks = _WORD_RE.findall(t)
            words_per.append(len(toks))
            all_tokens.extend(toks)
            if any(re.search(r"\d", w) or w in _TECH_WORDS for w in toks): tech_n += 1
            if any(w in _EMOTIVE_WORDS for w in toks): emo_n += 1
            if len(toks) <= 3: mini_n += 1
            if len(toks) >= 8: long_n += 1
        
        shares = {"technical": round(tech_n / n * 100, 1), "emotional": round(emo_n / n * 100, 1), "minimalist": round(mini_n / n * 100, 1)}
        ordered = sorted(shares, key=lambda k: -shares[k])
        top, second, gap_voice = ordered[0], ordered[1], ordered[-1]
        voice = "plain descriptive" if shares[top] < 15.0 else top
        margin = clamp((shares[top] - shares[second]) / 50.0)
        sw = sorted(words_per)
        diversity = round(len(set(all_tokens)) / len(all_tokens), 2) if all_tokens else 0.0
        
        tok_counts = Counter(t for t in all_tokens if len(t) >= 3 and t not in _TITLE_STOP and not re.search(r"\d", t))
        top_tokens = tok_counts.most_common(6)
        used_set = set(all_tokens)
        omitted = [w for w in _GAP_LEXICON.get(gap_voice, ()) if w not in used_set][:6]
        
        return {
            "n": n, "shares": shares, "voice": voice, "gap_voice": gap_voice,
            "mean_words": round(sum(words_per) / n, 1), "median_words": round(statistics.median(words_per), 1),
            "p25": round(percentile([float(x) for x in sw], 0.25), 1), "p75": round(percentile([float(x) for x in sw], 0.75), 1),
            "long_pct": round(long_n / n * 100, 1), "diversity": diversity,
            "top_tokens": top_tokens, "omitted": omitted,
            "conf": wconf([(0.6, n / 40.0), (0.4, margin)]),
        }
    
    def _seasonality(self, d) -> Optional[Dict[str, Any]]:
        trans = list(self.hist.transitions())
        if len(trans) < SEASON_MIN_TRANSITIONS or self.hist.span_days < SEASON_MIN_SPAN_DAYS: return None
        
        thr = PRICE_STABLE_THRESHOLD_PCT
        obs, cuts, total_cuts = Counter(), Counter(), 0
        for _k, _d0, p0, d1, p1 in trans:
            move = (p1 - p0) / p0 * 100 if p0 > 0 else 0.0
            is_cut = move <= -thr
            buckets = [("dow", d1.weekday()), ("wk", "weekend" if d1.weekday() >= 5 else "weekday"),
                      ("mo", "start" if d1.day <= 5 else "end" if d1.day >= 26 else "mid")]
            for b in buckets:
                obs[b] += 1
                if is_cut: cuts[b] += 1
            total_cuts += 1 if is_cut else 0
        
        n_tr = len(trans)
        overall = total_cuts / n_tr
        patterns = []
        
        if overall > 0:
            for dow in range(7):
                key = ("dow", dow)
                if obs[key] >= SEASON_MIN_BUCKET_OBS and cuts[key] >= SEASON_MIN_BUCKET_CUTS:
                    rate = cuts[key] / obs[key]
                    if rate >= SEASON_LIFT * overall:
                        patterns.append(f"discounts concentrate on {_WEEKDAYS[dow]}s ({rate * 100:.1f}% vs {overall * 100:.1f}% overall)")
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
                "span_days": round(self.hist.span_days, 1), "conf": conf,
                "span_raw": self.hist.span_days, "n_scans": self.hist.n_scans}
    
    def _seasonality_path_text(self, se) -> str:
        conf = se['conf']
        if conf >= CONF_DIRECTIVE: return ""
        targets = []
        if conf < CONF_WORKING: targets.append(("RECOMMENDED", CONF_WORKING))
        targets.append(("DIRECTIVE", CONF_DIRECTIVE))
        parts = []
        for label, tgt in targets:
            path = confidence_path(se['total_cuts'], se['span_raw'], se['n_scans'], tgt)
            if path: parts.append(f"{path['days']} more days (~{path['scans']} scans) to reach {label}")
            elif se['total_cuts'] == 0: parts.append(f"{label} unreachable until first cut observed")
            else: parts.append(f"{label} not reachable at current cut rate")
        return " Path to confidence: " + "; ".join(parts) + "."
    
    def _portfolio_view(self, d) -> List[Dict[str, Any]]:
        entries = [dict(v) for k, v in self.portfolio.items() if k != self.comp_id]
        entries.append({"name": self.name, "avg": d['avg_price'], "hhi": d['hhi_score']})
        return entries
    
    def _snapshot(self, d) -> Dict[str, Any]:
        pdv = d['price_delta']
        return {
            "n_products": d['products_with_pricing'], "avg": d['avg_price'], "median": d['median_price'],
            "hhi": d['hhi_score'], "cov": d['cov'], "vulnerability": d['vulnerability_score'],
            "gap_size": d['largest_gap_size'], "gap_from": d['largest_gap_from'], "gap_to": d['largest_gap_to'],
            "avg_drift_pct": pdv['pct_change'] if pdv else 0.0, "drift_known": bool(pdv),
            "cov_within": d['cov_within'],
            "vuln_points": {f['key']: f['points'] for f in d['vulnerability']['factors']},
        }
    
    def _vuln_trajectory(self, d) -> str:
        prior = self.portfolio.get(self.comp_id) if self.comp_id else None
        if not prior or not (prior.get('scan_at') or prior.get('avg')) or 'vulnerability' not in prior: return ""
        pv = _num(prior.get('vulnerability'))
        now = d['vulnerability_score']
        if abs(now - pv) < 1: return f"Trajectory: score unchanged at {now}/100."
        line = f"Trajectory: {pv:.0f} → {now} ({now - pv:+.0f})"
        pp = prior.get('vuln_points')
        if isinstance(pp, dict):
            movers = [(f['points'] - _num(pp.get(f['key'])), f) for f in d['vulnerability']['factors'] if f['key'] in pp]
            if movers:
                delta_pts, f = max(movers, key=lambda x: abs(x[0]))
                if abs(delta_pts) >= 0.5:
                    verb = "eased" if delta_pts < 0 else "worsened"
                    line += f"; largest mover: {f['label'].lower()} {verb} by {abs(delta_pts):.1f} pts"
        return line + "."
    
    def _generate_premium_insights(self) -> List[Dict[str, Any]]:
        d = self.get_data()
        if "error" in d: return self._generate_fallback_insights()
        
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
        out = []
        
        # Executive summary
        vuln_level = "HIGH" if score > 70 else "MEDIUM" if score > 40 else "LOW"
        seg = d['dominant_segment']
        diverse_note = " (structurally diverse range)" if d['structural_diverse'] else ""
        exec_summary = (
            f"{d['competitor_name']} operates with {d['products_with_pricing']} priced products averaging {usd(d['avg_price'])}, "
            f"with the {seg} tier dominant ({d[seg + '_pct']}% of priced products). "
            f"The top category, '{d['top_cat']}', accounts for {d['top_cat_pct']}% of the priced catalog "
            f"with an HHI of {d['hhi_score']} ({d['hhi_interp']}). "
            f"Price discipline is {d['cov_interp']}{diverse_note} (within-category CoV: {d['cov_within']}; "
            f"cross-category spread CoV: {d['cov']}). "
            f"Vulnerability Score: {score}/100 ({vuln_level})."
        )
        if pdv: exec_summary += f" Average prices have {price_delta_phrase(pdv['pct_change'])} since last scan."
        
        if score > 70: exec_rec = f"Critical weaknesses. Review strategic insights for data-backed counter-moves."
        elif score > 40: exec_rec = f"Notable vulnerabilities in specific areas. Review strategic insights."
        else: exec_rec = f"Limited exploitable weakness. Compete on differentiation."
        
        out.append(self._mk("executive_summary", "Market Overview", exec_summary, exec_rec,
                           "high" if score > 70 else "medium", wconf([(0.7, cs), (0.3, cc)]), ts, basis))
        
        # Stockout teaser (free only)
        if self.disappeared_products and self.tier == 'free':
            out.append(self._mk(TEASER_TYPE, "Stockout Signal Detected",
                f"Detected {len(self.disappeared_products)} product(s) no longer listed — possible stockout or delisting.",
                "Upgrade to Pro to see which products, last known prices, and targeted action plan.",
                "medium", wconf([(0.5, (self.scan_diff.get('prev_count', 0)) / 60.0), (0.5, 1.0)]), ts, basis, tag=False))
        
        # Product gap
        if d['largest_gap_size'] > 0:
            lower_title = self._title_near_price(d['largest_gap_from'])
            upper_title = self._title_near_price(d['largest_gap_to'])
            out.append(self._mk("product_gap", "Critical Price Gap Identified",
                f"Significant whitespace between {usd(d['largest_gap_from'])} ('{lower_title}') and {usd(d['largest_gap_to'])} ('{upper_title}') — gap of {usd(d['largest_gap_size'])} ({d['largest_gap_ratio']}x avg price). No priced product in this range.",
                f"Launch flagship product at {usd(launch_price)}, positioned between '{lower_title}' and '{upper_title}'. Base case ({int(BASE_MARGIN * 100)}% margin, {BASE_RUN_UNITS:,}-unit run) breaks even at {base_be:,} units.",
                "high", wconf([(0.7, cs), (0.3, d['largest_gap_ratio'])]), ts, basis))
        else:
            out.append(self._mk("product_gap", "Dense Price Coverage — No Gap To Fill",
                f"No exploitable gap: price ladder from {usd(d['min_price'])} to {usd(d['max_price'])} is continuous (largest jump under {int(PRICE_GAP_AVG_RATIO * 100)}% of {usd(d['avg_price'])} avg). Gap-filling strategy would fail.",
                f"Don't chase a gap that isn't there. Compete on bundle value, subscription, or service wrap around {usd(d['median_price'])} median item.",
                "medium", wconf([(1.0, cs)]), ts, basis))
        
        # Category dominance
        cat_phrase = f", such as '{d['top_cat_samples'][0]}'" if d['top_cat_samples'] else ""
        if d['hhi_score'] > HHI_HIGH:
            cat_rec = f"Dependence on '{d['top_cat']}' is the exposure. Build deeper '{d['top_cat']}' line and bundle kits around it."
        elif d['hhi_score'] <= HHI_MODERATE:
            cat_rec = "Catalog spread across categories — no concentrated weak point. Differentiate with depth in ONE category."
        else:
            cat_rec = f"Moderately concentrated around '{d['top_cat']}'. Contest that category with focused line."
        out.append(self._mk("category_dominance", "Category Concentration Risk",
            f"Catalog is {d['hhi_interp']} (HHI {d['hhi_score']}). Top category '{d['top_cat']}'{cat_phrase} represents {d['top_cat_pct']}% of priced products ({d['top_cat_count']} of {d['products_with_pricing']}).",
            cat_rec, "high" if d['hhi_score'] > HHI_HIGH else "medium", wconf([(0.6, cs), (0.4, cc)]), ts, basis))
        
        # Promotional intensity
        low_promo = d['promo_pct'] < 10
        out.append(self._mk("competitive_threat", "Promotional Intensity Analysis",
            f"Promotional intensity at {d['promo_pct']}%, with {d['budget_promo_count']} promos in budget segment and {d['premium_promo_count']} in premium. {'Limited discounting indicates pricing confidence.' if low_promo else 'High promotional activity suggests inventory pressure or aggressive acquisition.'}",
            f"Run targeted {int(FLASH_DISCOUNT * 100)}% flash campaign on mid-tier staples (~{usd(round(d['median_price'] * (1 - FLASH_DISCOUNT), 2))} vs median) to capture price-sensitive shoppers." if low_promo
            else "Counter promotional blitz with value-added bundles rather than price cuts.",
            "medium", wconf([(1.0, cs)]), ts, basis))
        
        # Pricing warfare (dual-CoV)
        inconsistent = d['cov_within'] > COV_OPPORTUNISTIC
        out.append(self._mk("pricing_warfare", "Pricing Discipline Assessment",
            f"Pricing discipline is {d['cov_interp']} (within-category CoV {d['cov_within']}). {self._dual_cov_text(d)[0].upper()}{self._dual_cov_text(d)[1:]} Price spread ranges from {usd(d['min_price'])} to {usd(d['max_price'])}.",
            f"Make predictability your edge: hold own within-category CoV under {COV_DISCIPLINED} vs their {d['cov_within']}." if inconsistent
            else "Study their pricing discipline as benchmark, use targeted promotions in peripheral categories.",
            "high" if inconsistent else "medium", wconf([(1.0, cs)]), ts, basis))
        
        # Historical shift
        if pdv and abs(pdv['pct_change']) >= PRICE_STABLE_THRESHOLD_PCT:
            rose = pdv['pct_change'] > 0
            overlap_share = pdv['overlap_n'] / max(pdv['latest_n'], 1)
            out.append(self._mk("market_timing", "Historical Price Shift Detected",
                f"Since last scan, avg price has {price_delta_phrase(pdv['pct_change'])} (from {usd(pdv['prior_avg'])} to {usd(pdv['latest_avg'])}). On {pdv['overlap_n']} SKUs present in both scans, like-for-like change is {pdv['like_for_like_pct']}%.",
                "Prices rose: position alternatives as smart value choice." if rose
                else "Prices fell: emphasize superior quality and brand equity.",
                "high", wconf([(0.4, cs), (0.6, overlap_share)]), ts, basis))
        elif pdv:
            out.append(self._mk("market_timing", "Price Stability Confirmed",
                f"Since last scan, avg price has {price_delta_phrase(pdv['pct_change'])} at {usd(pdv['latest_avg'])}, indicating confidence in margin structure.",
                f"Use stability window to test own pricing in +/-{int(PRICE_TEST_BAND * 100)}% band on comparable products.",
                "medium", wconf([(0.4, cs), (0.6, pdv['overlap_n'] / max(pdv['latest_n'], 1))]), ts, basis))
        
        # Velocity & scarcity
        if d['velocity_pct'] > 0 or d['scarcity_pct'] > 0:
            vel_phrase = f", including {self._format_sample_titles(d['velocity_samples'])}" if d['velocity_samples'] else ""
            anchor = d['velocity_samples'][0] if d['velocity_samples'] else (d['top_cat_samples'][0] if d['top_cat_samples'] else d['top_cat'])
            out.append(self._mk("competitive_threat", "Sales Velocity & Scarcity Signals",
                f"Title analysis: {d['velocity_pct']}% carry bestseller/popularity tags{vel_phrase}, {d['scarcity_pct']}% show scarcity signals.",
                f"Don't price-war items like '{anchor}'. Launch complementary cross-sell or premium alternative near {usd(round(d['median_price'] * PREMIUM_ALT_MULT, 2))} ({PREMIUM_ALT_MULT}x median).",
                "high", wconf([(0.5, cs), (0.5, (d['velocity_count'] + d['scarcity_count']) / 10.0)]), ts, basis))
        
        # Freshness
        if d['freshness_pct'] > 0:
            fresh_phrase = f", such as {self._format_sample_titles(d['freshness_samples'])}" if d['freshness_samples'] else ""
            out.append(self._mk("market_timing", "Assortment Freshness & Rapid Drops",
                f"Actively pushing new inventory: {d['freshness_pct']}% tagged 'New In' or 'Just Dropped'{fresh_phrase}.",
                "Counter not by matching speed, but by establishing 'evergreen' staple with lifetime guarantee.",
                "medium", wconf([(0.5, cs), (0.5, d['freshness_count'] / 10.0)]), ts, basis))
        
        # Price architecture
        psych = d['psych_pct']
        spread = round(d['max_price'] - d['min_price'], 2)
        spread_x = round(spread / d['avg_price'], 1) if d['avg_price'] else 0.0
        psych_word = 'heavy' if psych > PSYCH_HIGH else 'moderate' if psych > PSYCH_LOW else 'light'
        position = ('value-oriented, conversion-focused' if psych > PSYCH_HIGH
                   else 'premium, brand-led' if psych < PSYCH_LOW else 'balanced')
        gap_mm = d['avg_price'] - d['median_price']
        if abs(gap_mm) <= d['avg_price'] * 0.005: shape = "mean and median coincide"
        elif gap_mm > 0: shape = "mean pulled up by premium outliers, real volume sits lower"
        else: shape = "distribution skews toward higher prices, average understates typical buy"
        
        out.append(self._mk("price_architecture", "Price Architecture & Psychological Pricing Deep Dive",
            f"{d['competitor_name']}'s price ladder spans {usd(d['min_price'])} to {usd(d['max_price'])} ({usd(spread)} spread, {spread_x}x avg), anchored near {usd(d['p90_price'])} (90th percentile) and {usd(d['p10_price'])} (10th percentile). {psych}% end in charm ending (.99/.95/.97/.49/.90/.88), {d['round_pct']}% whole-dollar — {psych_word} use signals {position} positioning. With {usd(d['median_price'])} median vs {usd(d['avg_price'])} mean, {shape}. Dispersion: {self._dual_cov_text(d)}",
            self._price_architecture_rec(d), "medium", wconf([(1.0, cs)]), ts, basis))
        
        # Delta since last scan
        delta = self._delta_insight(d, ts, basis, deep)
        if delta: out.append(delta)
        
        # Paid tier insights
        if paid:
            if self.disappeared_products:
                shown = self.disappeared_products[:3]
                titles_prices = "; ".join(f"'{p.get('title', 'Unnamed')}' (was {usd(p.get('current_price', 0))})" for p in shown)
                prev_count = self.scan_diff.get('prev_count', 0)
                base_conf = wconf([(0.5, prev_count / 60.0), (0.5, d['n_scans'] / 3.0)])
                oos_summary = f"{len(self.disappeared_products)} product(s) no longer listed, including: {titles_prices}. Signals stockout or deliberate delisting — narrow, time-sensitive window."
                oos_rec = f"Launch targeted ad campaign within {ACTION_WINDOW} bidding on keywords tied to '{shown[0].get('title', 'missing product')}'."
                oos_sev, oos_conf = "critical", base_conf
                if d['coverage_low']:
                    oos_conf = min(round(base_conf * d['coverage_consistency'], 2), round(CONF_DIRECTIVE - 0.01, 2))
                    oos_summary = f"Coverage varied {d['coverage_shift_pct']:.0f}% vs last scan ({len(self.products)} products now vs {d['prev_count']} before); verify before acting. " + oos_summary
                    oos_rec = "First confirm items are really unlisted. If confirmed, " + oos_rec[0].lower() + oos_rec[1:]
                    oos_sev = "medium"
                out.append(self._mk("out_of_stock_signal", "Competitor Stockout/Delisting Detected",
                    oos_summary, oos_rec, oos_sev, oos_conf, ts, basis))
            
            vuln_lines = "\n".join(f"- {f['label']}: {f['points']:.1f}/{f['weight']:.0f} pts (sub-score {f['sub']:.2f}; {f['justification']})" for f in vuln['factors'])
            verdict = ("Critical strategic weaknesses to exploit immediately." if score > 70
                      else "Notable vulnerabilities in specific areas." if score > 40
                      else "Relatively well-positioned.")
            top_factors = sorted(vuln['factors'], key=lambda f: -f['points'])[:2]
            traj = self._vuln_trajectory(d)
            traj_txt = f"\n{traj}" if traj else ""
            out.append(self._mk("vulnerability_analysis", "Vulnerability Score: Deep Dive",
                f"Vulnerability Score: {score}/100 (weighted rubric, weights sum to 100). {verdict}\n{vuln_lines}\nSum: {vuln['raw']:.2f} → {score}/100.{traj_txt}",
                f"Immediate action: target two heaviest factors ({top_factors[0]['label']}, {top_factors[1]['label']}) with coordinated campaigns this quarter." if score > 70
                else f"Strategic approach: focus on two heaviest factors ({top_factors[0]['label']}, {top_factors[1]['label']}) and build differentiated value proposition." if score > 40
                else "Differentiation strategy: compete on brand storytelling or niche specialization.",
                "critical" if score > 70 else "high" if score > 40 else "medium",
                wconf([(0.5, cs), (0.3, cd), (0.2, cc)]), ts, basis))
            
            # Financial blueprint
            if d['largest_gap_size'] > 0:
                bp_summary = f"Detailed rollout plan to fill {usd(d['largest_gap_size'])} whitespace between {usd(d['largest_gap_from'])} and {usd(d['largest_gap_to'])}."
            else:
                anchor_line = d['top_cat_samples'][0] if d['top_cat_samples'] else f"the {d['top_cat']} line"
                bp_summary = f"No exploitable gap — targets premium alternative to '{anchor_line}' to win on value."
            if deep:
                matrix = render_margin_matrix(sc)
                bp_rec = f"Product: {launch_label}. Launch cost F = {usd(sc['launch_cost'])} ({int(LAUNCH_COST_RATIO * 100)}% of {BASE_RUN_UNITS:,}-unit revenue {usd(launch_price * BASE_RUN_UNITS)}).\n{matrix}\nProfit = units × price × margin - F. Days-to-execute: 30. Success KPI: reach break-even volume within 60 days."
            else:
                bp_rec = f"Product: {launch_label}. Base case: {int(BASE_MARGIN * 100)}% margin, {BASE_RUN_UNITS:,}-unit run, launch cost F = {usd(sc['launch_cost'])}. Break-even: {base_be:,} units; profit at {BASE_RUN_UNITS:,} units: {usd(sc['base']['cells'][1]['profit'])}. Days-to-execute: 30. Upgrade to Pro+ for full margin × volume matrix."
            out.append(self._mk("financial_blueprint", "Financial Execution Blueprint", bp_summary, bp_rec, "critical", wconf([(0.6, cs), (0.4, cd)]), ts, basis))
            
            quick_wins = self._build_quick_wins(d)
            out.append(self._mk("quick_wins", "Quick Wins (Execute in 7 Days)",
                "\n".join(f"- {w}" for w in quick_wins),
                "Assign owner to each item today, review results at day 7 against next scan.",
                "high", wconf([(0.7, cs), (0.3, cd)]), ts, basis))
            
            out.append(self._mk("strategic_timeline", "Strategic Timeline (30-60-90 Day)",
                self._build_timeline(d, base_be),
                "Assign dedicated owner and check-in date to each milestone.",
                "medium", wconf([(0.7, cs), (0.3, cd)]), ts, basis))
            
            cross_summary, cross_rec = self._cross_reference_text(d)
            out.append(self._mk("cross_reference", "Cross-Reference Strategic Analysis",
                cross_summary, cross_rec, "high", wconf([(0.5, cs), (0.5, cc)]), ts, basis))
            
            # Catalog contraction
            if self.contraction:
                c = self.contraction
                ex = self._format_sample_titles(c.get('examples', []), 3)
                ex_txt = f" Examples: {ex}." if ex else ""
                out.append(self._mk("catalog_contraction", "Catalog Contraction Detected",
                    f"{c['count']} of {c['prev_count']} SKUs ({c['ratio'] * 100:.0f}%) vanished in single scan. {c['stable_share'] * 100:.0f}% held price range within {int(CONTRACTION_STABLE_RANGE * 100)}% over mean {c['mean_obs']} observations, {c['together_share'] * 100:.0f}% last seen in same scan. Only {c['replacement'] * 100:.0f}% as many new SKUs appeared. Indicates collection retirement, not URL drift. Last-known prices: {usd(c['price_low'])} to {usd(c['price_high'])} (avg {usd(c['avg_last_price'])}).{ex_txt}",
                    f"Treat vacated {usd(c['price_low'])}-{usd(c['price_high'])} band as open shelf space: place closest substitute within {ACTION_WINDOW}, don't treat as temporary stockout.",
                    "high", c['confidence'], ts, basis))
            
            # Competitive response model
            rm = self._response_model(d)
            out.append(self._response_insight(d, rm, launch_price, ts, basis))
            
            # SKU pressure index
            sp = self._sku_pressure(d)
            if sp:
                lines = []
                for r in sp['top']:
                    if r['net'] <= -5: direction = "downward drift (clearance proxy)"
                    elif r['net'] >= 5: direction = "upward drift (demand proxy)"
                    else: direction = "oscillating"
                    lines.append(f"- '{r['title'][:70]}': PI {r['pi']} ({r['moves']} repricings in {r['trans']} intervals, mean move {r['mean_abs']}%, net {r['net']}%, {direction})")
                top = sp['top'][0]
                out.append(self._mk("sku_pressure_index", "SKU-Level Pressure Index",
                    f"{sp['volatile']} of {sp['qualifying']} SKUs with enough history repriced. Most volatile first (PI = 100 × repricing frequency × magnitude factor):\n" + "\n".join(lines),
                    f"Watch '{top['title'][:70]}' as leading indicator (PI {top['pi']}): repricing frequency precedes category-wide moves.",
                    "medium", sp['conf'], ts, basis))
            
            # Language fingerprint
            lf = self._language_fingerprint(d)
            if lf:
                sh = lf['shares']
                voice_line = f"dominant voice: {lf['voice']}" if lf['voice'] != "plain descriptive" else "no dominant voice (all below 15%): plain descriptive"
                used_txt = ", ".join(f"'{t}' ({c})" for t, c in lf['top_tokens'])
                tok_sentence = f" Most-used title words: {used_txt}." if used_txt else ""
                if lf['omitted']:
                    omit_txt = ", ".join(f"'{w}'" for w in lf['omitted'])
                    omit_rec = f" Words in {lf['gap_voice']} register they never use: {omit_txt} — put them in your naming."
                elif lf['gap_voice'] == "minimalist":
                    omit_rec = " Keep names to three words or fewer."
                else: omit_rec = ""
                out.append(self._mk("language_fingerprint", "Positioning Language Fingerprint",
                    f"Across {lf['n']} titles: technical {sh['technical']}%, emotional {sh['emotional']}%, minimalist {sh['minimalist']}% (titles ≤3 words). Title length avg {lf['mean_words']} words (median {lf['median_words']}, IQR {lf['p25']}-{lf['p75']}; {lf['long_pct']}% run 8+ words). Lexical diversity {lf['diversity']}. Inferred brand voice — {voice_line}.{tok_sentence}",
                    f"Least-occupied voice is {lf['gap_voice']} ({sh[lf['gap_voice']]}% of titles). Name line with {_VOICE_BLURB[lf['gap_voice']]} to own space they leave empty.{omit_rec}",
                    "medium", lf['conf'], ts, basis))
            
            # Seasonality
            se = self._seasonality(d)
            if se:
                if se['patterns']: finding = "; ".join(se['patterns'])
                elif se['total_cuts'] == 0: finding = "no price cuts observed"
                else: finding = "no calendar bucket shows cut activity at 2× overall rate"
                rec = "Launch counter-offer 24h before flagged window so it's live when cuts land." if se['patterns'] else "Prices don't follow calendar rhythm. Time promotions on own demand curve."
                out.append(self._mk("seasonality_cycle", "Discount Cycle & Seasonality Detector",
                    f"Across {se['n_tr']} SKU-intervals over {se['span_days']} days, {se['total_cuts']} were price cuts ({se['overall'] * 100:.1f}%). Finding: {finding}.{self._seasonality_path_text(se)}",
                    rec, "medium", se['conf'], ts, basis))
            
            # Portfolio map
            pmap = build_portfolio_map(self._portfolio_view(d)) if deep else None
            if pmap:
                self._pmap = pmap
                ws = pmap['white_space']
                counts = ", ".join(f"{k}: {v}" for k, v in sorted(pmap['quadrant_counts'].items()))
                empty = ", ".join(pmap['empty_quadrants']) if pmap['empty_quadrants'] else "every quadrant occupied"
                focus = "focused catalog (high HHI)" if ws['hhi'] > pmap['y_mid'] else "broad catalog (low HHI)"
                n_pts = len(pmap['points'])
                out.append(self._mk("portfolio_map", "Portfolio Market Map",
                    f"{n_pts} tracked competitors positioned on avg price (x) vs HHI concentration (y); watchlist medians {usd(pmap['x_mid'])} and HHI {pmap['y_mid']}. Quadrants — {counts}. Unoccupied: {empty}. Largest white space: avg price near {usd(ws['avg_price'])} with HHI near {ws['hhi']} ({ws['quadrant']}), {ws['min_distance']} normalized units from nearest competitor.",
                    f"Enter at ~{usd(ws['avg_price'])} with {focus}: no tracked competitor within {ws['min_distance']} normalized units.",
                    "high", wconf([(0.6, n_pts / 5.0), (0.4, cs)]), ts, basis))
        
        # Server-side tier gate
        out = self._enforce_tier_gate(out)
        
        # Chart bundle
        conf_map = {}
        for i in out: conf_map.setdefault(i['type'], []).append(i['confidence'])
        by_type = {k: round(sum(v) / len(v), 2) for k, v in conf_map.items()}
        overall_conf = round(sum(by_type.values()) / len(by_type), 2) if by_type else 0.0
        chart = self._build_chart_data(d, by_type, overall_conf)
        out.append(self._mk("chart_bundle", "Market Visualizations",
            json.dumps(_jsonable(chart), allow_nan=False), "Render as interactive charts.",
            "low", overall_conf, ts, tag=False))
        
        # Executive dashboard (always index 0)
        critical_high = sum(1 for i in out if i.get('severity') in ('critical', 'high'))
        if d['largest_gap_size'] > 0:
            opp_label = f"{usd(launch_price * BASE_RUN_UNITS)} Modeled Price-Gap Revenue ({BASE_RUN_UNITS:,}-unit run)"
        elif self.disappeared_products:
            pool = sum(_num(p.get('current_price')) for p in self.disappeared_products)
            unverified = " — unverified, coverage varied" if d['coverage_low'] else ""
            opp_label = f"{usd(pool)} Stockout-Capture Pool (last known prices{unverified})"
        else:
            opp_label = "$0.00 Immediate Gap Opportunity (compete on differentiation)"
        dash_rec = ("These three numbers summarize the full report. Start with highest-leverage insight."
                   if paid else "Upgrade to Pro for full vulnerability breakdown, financial blueprint, and stockout monitoring.")
        out.insert(0, self._mk("dashboard_summary", "Executive Dashboard",
            f"{critical_high} Critical/High-Priority Findings | {opp_label} | Vulnerability Score: {score}/100",
            dash_rec, "critical" if score > 70 else "high" if score > 40 else "medium", overall_conf, ts, tag=False))
        
        out = self._finalize(out)
        self.snapshot_entry = {"name": self.name, **self._snapshot(d)}
        self.logger.info(f"[ENGINE] Generated {len(out)} insights for tier: {self.tier}")
        return out
    
    def _response_insight(self, d, rm, launch_price, ts, basis) -> Dict[str, Any]:
        probs = rm['probs']
        cost_floor = round(launch_price * (1 - BASE_MARGIN), 2)
        cut_label = "Matches/undercuts with list-price cut (suppressed by observed record)" if rm['never_cut'] else "Matches/undercuts with list-price cut"
        scen = {
            "hold": (f"Holds price, ignores launch — driver: {rm['hold_basis']}.",
                    f"Launch at {usd(launch_price)}; no defensive repricing needed."),
            "promo": (f"Answers with promotion/bundle rather than list-price cut — driver: {rm['promo_basis']}.",
                     "Pre-empt with bundle or guarantee, don't match discount."),
            "cut": (f"{cut_label} — driver: {rm['cut_basis']}.",
                   f"Hold {usd(launch_price)}, set walk-away floor at cost basis ({usd(cost_floor)} = price × (1 - {int(BASE_MARGIN * 100)}% margin))."),
        }
        order = sorted(probs, key=lambda k: -probs[k])
        lines = [f"{i + 1}. {probs[k] * 100:.0f}% — {scen[k][0]}" for i, k in enumerate(order)]
        summary = f"If you launch at {usd(launch_price)}, three modeled reactions (propensity-normalized, weights from observed behavior):\n" + "\n".join(lines)
        rec = f"Plan for most likely reaction first: {scen[order[0]][1]} Then cover #2: {scen[order[1]][1]}"
        return self._mk("competitive_response", "Competitive Response Model", summary, rec, "medium", rm['conf'], ts, basis)
    
    def _delta_insight(self, d, ts, basis, deep) -> Optional[Dict[str, Any]]:
        pdv = d['price_delta']
        prior = self.portfolio.get(self.comp_id) if self.comp_id else None
        diff = self.scan_diff
        has_diff = bool(diff.get('prev_count'))
        if not (pdv or prior or has_diff): return None
        
        parts = []
        if has_diff: parts.append(f"{diff.get('new', 0)} new SKU(s) and {diff.get('removed_raw', 0)} removed SKU(s) against {diff['prev_count']} tracked last scan")
        if pdv: parts.append(f"avg price has {price_delta_phrase(pdv['pct_change'])} ({usd(pdv['prior_avg'])} → {usd(pdv['latest_avg'])})")
        
        if deep or self.rank >= TIER_RANK['pro']:
            if prior and prior.get('gap_size') is not None and (prior.get('scan_at') or prior.get('avg')):
                pg, ng = _num(prior.get('gap_size')), d['largest_gap_size']
                if pg == 0 and ng > 0: parts.append(f"{usd(ng)} price gap OPENED ({usd(d['largest_gap_from'])} → {usd(d['largest_gap_to'])})")
                elif pg > 0 and ng == 0: parts.append(f"prior {usd(pg)} price gap CLOSED")
                elif pg > 0 and ng > 0 and abs(ng - pg) >= 0.01: parts.append(f"largest price gap {'widened' if ng > pg else 'narrowed'} from {usd(pg)} to {usd(ng)}")
                pv = _num(prior.get('vulnerability'))
                if abs(d['vulnerability_score'] - pv) >= 1: parts.append(f"vulnerability moved from {pv:.0f} to {d['vulnerability_score']}/100")
        
        others = [v for k, v in self.portfolio.items() if k != self.comp_id and v.get('drift_known')] if self.rank >= TIER_RANK['pro'] else []
        watch = ""
        if others:
            drifts = [_num(o.get('avg_drift_pct')) for o in others]
            rising = sum(1 for x in drifts if x >= PRICE_STABLE_THRESHOLD_PCT)
            falling = sum(1 for x in drifts if x <= -PRICE_STABLE_THRESHOLD_PCT)
            mean_drift = round(sum(drifts) / len(drifts), 2)
            watch = f" Across your {len(others) + 1} watched competitors, other {len(others)} moved {mean_drift}% avg ({rising} rising, {falling} falling)."
        
        if not parts and not watch: return None
        
        move = abs(pdv['pct_change']) if pdv else 0.0
        sev = "high" if (move >= 5 or diff.get('removed_raw', 0) >= 5) else "medium"
        overlap = (pdv['overlap_n'] / max(pdv['latest_n'], 1)) if pdv else 0.3
        conf = wconf([(0.6, overlap), (0.4, diff.get('prev_count', 0) / 30.0)])
        summary = f"Since last scan of {d['competitor_name']}: " + "; ".join(parts) + "." + watch
        rec = "Review moves above before touching own pricing: act on gaps that opened, ignore noise below 0.5% avg drift."
        return self._mk("market_timing", "Watchlist Delta Since Last Scan", summary, rec, sev, conf, ts, basis)
    
    def _build_chart_data(self, d, conf_by_type, overall_conf) -> Dict[str, Any]:
        prices = [r["price"] for r in self.rows]
        hist = []
        if prices:
            lo, hi = min(prices), max(prices)
            buckets = 6
            if hi > lo:
                step = (hi - lo) / buckets
                edges = [lo + step * i for i in range(buckets + 1)]
                counts = [0] * buckets
                for pr in prices: counts[min(int((pr - lo) / step), buckets - 1)] += 1
                hist = [{"range": f"${round(edges[i])}-${round(edges[i + 1])}", "count": counts[i]} for i in range(buckets)]
            else: hist = [{"range": f"${round(lo)}", "count": len(prices)}]
        
        cat_stats = {}
        for r in self.rows:
            for kw, rx in self._CAT_RE.items():
                if rx.search(r["norm"]): cat_stats.setdefault(kw, []).append(r["price"])
        cats = [{"name": k, "count": len(v), "avg_price": round(sum(v) / len(v), 2)}
               for k, v in sorted(cat_stats.items(), key=lambda x: -len(x[1]))[:5]]
        
        chart = {
            "price_distribution": hist,
            "segments": {"budget": d['budget_pct'], "mid": d['mid_pct'], "premium": d['premium_pct']},
            "categories": cats,
            "price_history": self.hist.daily_avgs()[-12:],
            "signals": {"velocity": d['velocity_pct'], "scarcity": d['scarcity_pct'],
                       "freshness": d['freshness_pct'], "promo": d['promo_pct']},
            "headlines": {"avg": d['avg_price'], "median": d['median_price'], "hhi": d['hhi_score'],
                         "cov": d['cov'], "vulnerability": d['vulnerability_score']},
            "signals_interpretation": interpret_signals(d['velocity_pct'], d['scarcity_pct'], d['freshness_pct'], d['promo_pct']),
            "confidence": {"overall": overall_conf, "by_type": conf_by_type},
            "portfolio_snapshot": {**self._snapshot(d), "scan_at": datetime.now(timezone.utc).isoformat()},
            "cov_structural": d['cov'], "cov_within_category": d['cov_within'],
            "cov_basis": d['cov_basis'], "coverage_consistency": d['coverage_consistency'],
        }
        pmap = getattr(self, "_pmap", None)
        if pmap and self.rank >= TIER_RANK['pro_plus']:
            chart["portfolio_map"] = {**pmap, "confidence": conf_by_type.get("portfolio_map", 0.0)}
        return chart
    
    def _enforce_tier_gate(self, insights: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        kept = [i for i in insights if type_allowed(i.get('type', ''), self.tier)]
        dropped = len(insights) - len(kept)
        if dropped: self.logger.warning(f"[ENGINE] Tier gate removed {dropped} insight(s) for tier '{self.tier}'")
        return kept
    
    def _consistency_guard(self, insights: List[Dict[str, Any]]) -> List[str]:
        issues = []
        d = self.get_data()
        if "error" in d: return issues
        gap = d['largest_gap_size']
        for i in insights:
            typ = i.get('type')
            if typ == 'chart_bundle': continue
            low = f"{i.get('summary', '')} {i.get('ai_recommendation', '')}".lower()
            if gap > 0 and ("no exploitable price gap" in low or "no price gap exists" in low):
                msg = f"{typ} claims no gap but catalog found {usd(gap)}"
                issues.append(msg)
                i['summary'] = f"{i.get('summary', '')}\n[Consistency check: catalog found {usd(gap)} gap ({usd(d['largest_gap_from'])} → {usd(d['largest_gap_to'])}); data-backed value applies.]"
            elif gap <= 0 and "gap-filler priced at" in low:
                msg = f"{typ} prices gap-filler but no gap found"
                issues.append(msg)
                i['summary'] = f"{i.get('summary', '')}\n[Consistency check: no uncovered gap; data-backed value applies.]"
            if typ == 'out_of_stock_signal' and d['coverage_low']:
                if _num(i.get('confidence')) >= CONF_DIRECTIVE or "coverage varied" not in str(i.get('summary', '')).lower():
                    issues.append("out_of_stock_signal ignored coverage drift")
                    i['confidence'] = min(_num(i.get('confidence')), round(CONF_DIRECTIVE - 0.01, 2))
                    if "coverage varied" not in str(i.get('summary', '')).lower():
                        i['summary'] = f"Coverage varied {d['coverage_shift_pct']:.0f}% vs last scan; verify before acting.\n{i.get('summary', '')}"
                    i['ai_recommendation'] = str(i.get('ai_recommendation', '')).replace(VOICE_PREFIX['directive'], VOICE_PREFIX['working'], 1)
                    i['summary'] = str(i['summary']).replace("DIRECTIVE", voice_label(i['confidence']).upper(), 1)
        rm = self._rm_last
        if rm and rm['have_hist'] and rm['cut_skus'] == 0 and rm['probs']['cut'] > rm['probs']['hold'] + 1e-12:
            issues.append("competitive_response prices cut above hold although no SKU ever cut")
        for msg in issues: self.logger.warning(f"[ENGINE] WARN consistency guard: {msg}")
        return issues
    
    def _finalize(self, insights: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        self._consistency_guard(insights)
        for i in insights:
            if i['type'] == 'chart_bundle': continue
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
            "summary": f"Scanned {len(self.products)} products, no valid pricing data detected.",
            "ai_recommendation": "Ensure scraper correctly extracts 'current_price' fields.",
            "severity": "medium", "created_at": timestamp, "confidence": 0.0,
        }]

# ===================================================================
# SCRAPER ENGINE
# ===================================================================
class ScraperEngine:
    def __init__(self):
        self.scrapers = {'shopify': scrape_shopify, 'woocommerce': scrape_woocommerce, 'generic': scrape_generic}
        self.logger = logging.getLogger('ScraperEngine')
    
    def scrape(self, url: str, platform: Optional[str] = None, max_retries: int = 3, max_products: int = 9999) -> Tuple[List[Dict[str, Any]], Optional[ScraperBlockedError]]:
        if not platform: platform = detect_platform(url)
        scraper_func = self.scrapers.get(platform, scrape_generic)
        for attempt in range(max_retries):
            try:
                self.logger.info(f"[SCRAPE] Using {platform} scraper (attempt {attempt + 1}/{max_retries})")
                products = asyncio.run(scraper_func(url)) if inspect.iscoroutinefunction(scraper_func) else scraper_func(url)
                if products and len(products) > 0:
                    if len(products) > max_products:
                        products = products[:max_products]
                        self.logger.info(f"[SKIP] Trimmed to {max_products} products (tier limit)")
                    print_success(f"Successfully scraped {len(products)} products")
                    return products, None
                self.logger.warning(f"[EMPTY] {platform} scraper returned 0 products on attempt {attempt + 1}")
            except ScraperBlockedError as be:
                self.logger.warning(f"[BLOCKED] {platform} scraper blocked: {be.reason}")
                return [], be
            except _HTTP_ERRORS as he:
                status = he.response.status_code if he.response is not None else None
                if status in (403, 404):
                    reason = detect_block_signal(status, getattr(he.response, "text", "")) or f"HTTP {status}"
                    self.logger.warning(f"[BLOCKED] HTTP {status}: {reason}")
                    return [], ScraperBlockedError(status, reason)
                self.logger.error(f"Scraper HTTP error (attempt {attempt + 1}): {he}")
                if attempt < max_retries - 1: time.sleep(2 ** attempt)
            except Exception as e:
                self.logger.error(f"Scraper failed (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1: time.sleep(2 ** attempt)
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

# ===================================================================
# RUN STATS
# ===================================================================
class ScanResult(str, Enum):
    SUCCESS, BLOCKED, NO_PRODUCTS, FAILED = "success", "blocked", "no_products", "failed"

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
    
    def record(self, result: ScanResult):
        if result == ScanResult.SUCCESS: self.succeeded += 1
        elif result == ScanResult.BLOCKED: self.blocked += 1
        elif result == ScanResult.NO_PRODUCTS: self.no_products += 1
        else: self.failed += 1
    
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

# ===================================================================
# MAIN ORCHESTRATOR
# ===================================================================
class VeloraScraper:
    def __init__(self):
        self.config = Config()
        self.supabase: Optional[Client] = None
        self.db: Optional[DatabaseManager] = None
        self.scraper: Optional[ScraperEngine] = None
        self.email_service: Optional[Any] = None
        self.logger = logging.getLogger('VeloraScraper')
        self._portfolio_cache: Dict[str, Dict[str, Dict[str, Any]]] = {}
    
    def initialize(self) -> bool:
        print_banner()
        if not self.config.validate(): return False
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
                    print_warning(f"[EMAIL] EmailService init failed: {e}")
                    self.email_service = None
            return True
        except Exception as e:
            print_error(f"Failed to connect to Supabase: {e}")
            return False
    
    def _portfolio_for(self, user_id: Optional[str]) -> Dict[str, Dict[str, Any]]:
        if not user_id: return {}
        if user_id not in self._portfolio_cache:
            self._portfolio_cache[user_id] = self.db.load_portfolio_snapshots(user_id)
            self.logger.info(f"[ENGINE] Portfolio pre-load for user {user_id}: {len(self._portfolio_cache[user_id])} snapshots")
        return self._portfolio_cache[user_id]
    
    def _send_stockout_alerts(self, competitor_id: str, competitor_name: str, disappeared_products) -> int:
        if not self.email_service or not self.db or not disappeared_products: return 0
        users = self.db.get_watching_users(competitor_id)
        if not users:
            self.logger.info(f"[EMAIL] No watching users for {competitor_name}")
            return 0
        products_for_email = [
            {"name": str(p.get("title", "Unnamed"))[:80], "price": f"${_num(p.get('current_price')):.2f}"}
            for p in disappeared_products
        ]
        sent = 0
        for user in users:
            user_email = user.get("email")
            user_tier = (user.get("tier") or "free").lower()
            if not user_email: continue
            try:
                ok = self.email_service.send_stockout_alert(
                    email=user_email, competitor_name=competitor_name,
                    products=products_for_email, tier=user_tier,
                )
                if ok: sent += 1
            except Exception as e:
                self.logger.warning(f"[EMAIL] Failed to send stockout alert to {user_email}: {e}")
        if sent: print_success(f"[EMAIL] Stockout alert sent to {sent} user(s) watching {competitor_name}")
        return sent
    
    def _send_scan_digest(self, competitor_id: str, competitor_name: str, insights) -> int:
        if not self.email_service or not self.db or not insights: return 0
        digest_insights = [{k: i.get(k) for k in EMAIL_INSIGHT_KEYS} for i in insights if i.get("type") not in SKIP_TYPES]
        if not digest_insights: return 0
        users = self.db.get_watching_users(competitor_id)
        if not users: return 0
        sent = 0
        for user in users:
            user_email = user.get("email")
            user_tier = (user.get("tier") or "free").lower()
            if not user_email: continue
            try:
                ok = self.email_service.send_insights_digest(
                    email=user_email, insights=digest_insights,
                    competitor_name=competitor_name, tier=user_tier,
                )
                if ok: sent += 1
            except Exception as e:
                self.logger.warning(f"[EMAIL] Failed to send digest to {user_email}: {e}")
        if sent: print_success(f"[EMAIL] Scan digest sent to {sent} user(s) watching {competitor_name}")
        return sent
    
    def display_intelligence_brief(self, brief, insights):
        print_header("PREMIUM MARKET INTELLIGENCE BRIEFING")
        print(f"{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
        print(f"{Colors.BOLD}Target Competitor:{Colors.ENDC} {brief.get('competitor_name')}")
        print(f"{Colors.BOLD}Tier:{Colors.ENDC} {str(brief.get('tier_context', 'free')).upper()}")
        print(f"{Colors.BOLD}Products Analyzed:{Colors.ENDC} {brief.get('products_with_pricing')} / {brief.get('total_products_scanned')}")
        if brief.get('price_delta'):
            dl = brief['price_delta']
            print(f"{Colors.BOLD}Price Delta vs Last Scan:{Colors.ENDC} {price_delta_phrase(dl['pct_change'])} (${dl['prior_avg']} → ${dl['latest_avg']})")
        print()
        dashboard = next((i for i in insights if i.get('type') == 'dashboard_summary'), None)
        if dashboard: print(f"{Colors.BOLD}EXECUTIVE DASHBOARD:{Colors.ENDC}\n  {dashboard.get('summary')}\n")
        exec_insight = next((i for i in insights if i.get('type') == 'executive_summary'), None)
        if exec_insight: print(f"{Colors.BOLD}EXECUTIVE SUMMARY:{Colors.ENDC}\n  {exec_insight.get('summary')}\n")
        strategic_types = {
            "pricing_warfare", "product_gap", "competitive_threat", "counter_move", "market_timing",
            "brand_positioning", "customer_psychology", "supply_chain_signal", "category_dominance",
            "financial_blueprint", "strategic_timeline", "quick_wins", "risk_assessment",
            "vulnerability_analysis", "cross_reference", "out_of_stock_signal", "stockout_signal_teaser",
            "price_architecture",
        } | set(NEW_PREMIUM_TYPES)
        print_header("STRATEGIC INSIGHTS")
        for i, insight in enumerate(insights, 1):
            if insight.get('type') not in strategic_types: continue
            severity = str(insight.get('severity', 'medium')).upper()
            severity_color = Colors.WARNING if severity in ('CRITICAL', 'HIGH') else Colors.OKGREEN
            print(f"\n{Colors.OKCYAN}{'-'*80}{Colors.ENDC}")
            print(f"{Colors.BOLD}INSIGHT #{i} [{str(insight.get('type', 'GENERAL')).upper()}] — Severity: {severity_color}{severity}{Colors.ENDC}")
            print(f"{Colors.BOLD}Title:{Colors.ENDC} {insight.get('title')}")
            print(f"\n{Colors.OKBLUE}Situation Summary:{Colors.ENDC}\n  {insight.get('summary')}")
            print(f"\n{Colors.OKGREEN}Strategic Counter-Move:{Colors.ENDC}\n  {insight.get('ai_recommendation')}")
        print(f"\n{Colors.OKGREEN}{'='*80}{Colors.ENDC}\n")
    
    def scan_competitor(self, competitor, url: str, stats: Optional[RunStats] = None) -> ScanResult:
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
            prior_history, _truncated = self.db.load_price_history(competitor_id, tier)
            prior_index = HistoryIndex(prior_history)
            disappeared_products, contraction = [], None
            scan_diff = {}
            
            if previous_products:
                current_urls = {normalize_product_url(p.get('product_url')) for p in cleaned_products}
                current_urls.discard("")
                current_titles = {normalize_text(p.get('title')) for p in cleaned_products}
                current_titles.discard("")
                prev_urls = {normalize_product_url(p.get('product_url')) for p in previous_products}
                prev_urls.discard("")
                raw_disappeared = [p for p in previous_products
                                  if normalize_product_url(p.get('product_url')) not in current_urls
                                  and normalize_text(p.get('title')) not in current_titles]
                scan_diff = {"prev_count": len(previous_products), "new": len(current_urls - prev_urls),
                            "removed_raw": len(raw_disappeared)}
                if raw_disappeared:
                    verdict = classify_disappearance(raw_disappeared, previous_products, current_urls, prior_index)
                    ratio = verdict['ratio']
                    if verdict['mode'] == 'stockout':
                        disappeared_products = verdict['stockouts']
                        print_warning(f"[STOCKOUT] {len(disappeared_products)} product(s) disappeared")
                    elif verdict['mode'] == 'contraction':
                        contraction = verdict['contraction']
                        self.logger.warning(f"[STOCKOUT-GUARD] {len(raw_disappeared)}/{len(previous_products)} ({ratio:.0%}) vanished — collection retirement")
                    else:
                        self.logger.warning(f"[STOCKOUT-GUARD] {len(raw_disappeared)}/{len(previous_products)} ({ratio:.0%}) — likely URL/schema drift")
            
            if self.db.upsert_products(cleaned_products) == 0:
                print_error(f"Failed to save products for {competitor_name}")
                return ScanResult.FAILED
            
            has_history = bool(prior_history) or self.db.has_previous_price_history(competitor_id)
            self.db.save_price_history(cleaned_products, competitor_id, recorded_at=timestamp)
            history_rows = prior_history + DatabaseManager.build_history_rows(cleaned_products, competitor_id, timestamp)
            
            if has_history:
                try:
                    self.supabase.table("ai_insights").delete().eq("competitor_id", competitor_id).eq("type", "trend").execute()
                except Exception as e:
                    self.logger.warning(f"Could not clear prior trend insights: {e}")
                try:
                    print(f"\n[TREND] Analyzing price trends for {competitor_name}")
                    trend_analyzer = TrendAnalyzer(competitor_id, products)
                    trend_data = trend_analyzer.analyze_price_trends()
                    if "error" not in trend_data and trend_data.get("insights"):
                        moving = [i for i in trend_data["insights"] if "stable" not in str(i.get("title", "")).lower()]
                        if moving:
                            for _t in moving: _t.setdefault("competitor_id", competitor_id)
                            self.db.save_trend_insights(moving)
                            print_success(f"Saved {len(moving)} real price-movement trends")
                        else: print_info("[SKIP] No real price movements detected")
                except Exception as e:
                    self.logger.error(f"Trend analysis failed: {e}")
            else: print_info("[SKIP] First scan — skipping trend analysis")
            
            user_id = competitor.get('user_id')
            portfolio = self._portfolio_for(user_id)
            intel_engine = PremiumDeterministicMarketIntelligenceEngine(
                competitor, products, db=self.db, disappeared_products=disappeared_products,
                history_rows=history_rows, portfolio=portfolio, contraction=contraction, scan_diff=scan_diff,
            )
            insights = intel_engine.generate_all_insights()
            brief = intel_engine.get_data()
            if "error" not in brief and insights: self.display_intelligence_brief(brief, insights)
            if insights:
                saved = self.db.save_insights(insights, competitor_id)
                if saved:
                    print_success(f"Saved {len(insights)} premium strategic insights")
                    if user_id and intel_engine.snapshot_entry:
                        self._portfolio_cache.setdefault(user_id, {})[competitor_id] = {
                            **intel_engine.snapshot_entry, "scan_at": datetime.now(timezone.utc).isoformat()
                        }
            self.db.update_competitor_scan_time(competitor_id)
            
            emails_this_scan = 0
            try:
                if disappeared_products: emails_this_scan += self._send_stockout_alerts(competitor_id, competitor_name, disappeared_products)
                if insights: emails_this_scan += self._send_scan_digest(competitor_id, competitor_name, insights)
            except Exception as email_err:
                self.logger.warning(f"[EMAIL] Auto-alert step errored: {email_err}")
            if stats is not None: stats.emails_sent += emails_this_scan
            
            print_success(f"[DONE] Mission Complete: {competitor_name}")
            print(f"   — Products Mapped: {len(cleaned_products)}\n   — Insights Generated: {len(insights)}\n   — Emails Sent: {emails_this_scan}")
            return ScanResult.SUCCESS
        except Exception as e:
            print_error(f"Failed to scan {competitor_name}: {e}")
            self.logger.exception(f"Unhandled exception scanning {competitor_name} ({url})")
            return ScanResult.FAILED
    
    def run_dynamic_mode(self, force_all: bool = False) -> RunStats:
        stats = RunStats()
        print_info("Running in TIER-AWARE DYNAMIC MODE")
        self._portfolio_cache = {}
        pending = self.db.get_pending_competitors(force_all=force_all)
        stats.scanned = len(pending)
        if not pending:
            print_success("[DONE] All competitors up to date!")
            print_info("   Next auto-update according to tier schedules")
            print(stats.summary())
            return stats
        print_info(f"Found {len(pending)} competitor(s) to scan\n")
        for i, comp in enumerate(pending, 1):
            print(f"\n[{i}/{len(pending)}]")
            url = comp.get('website') or comp.get('shopify_store')
            if not url:
                self.logger.warning(f"Competitor {comp.get('name')} has no URL — skipping")
                stats.skipped += 1
                continue
            result = self.scan_competitor(comp, url, stats=stats)
            stats.record(result)
            if i < len(pending): time.sleep(5)
        print(stats.summary())
        return stats
    
    def run(self, url: Optional[str] = None, continuous: bool = False, force_all: bool = False):
        if not self.initialize(): sys.exit(1)
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
        elif force_all: self.run_dynamic_mode(force_all=True)
        else: self.run_dynamic_mode(force_all=False)

# ===================================================================
# SELFTEST
# ===================================================================
_ST_COMP_ID = "comp-synth-001"
_ST_BAD_RE = re.compile(r"\bNone\b|\bnan\b|\bNaN\b|Infinity|\binf\b|\{[A-Za-z_][A-Za-z0-9_]*\}")

def _st_products(style: str) -> List[Dict[str, Any]]:
    cats = ["Merino Sweater", "Canvas Backpack", "Leather Belt", "Wool Scarf",
            "Denim Jacket", "Linen Shirt", "Trail Boot", "Cotton Sock"]
    items = []
    for i in range(64):
        base = 24 + (i % 8) * 6 + (i // 8) * 3
        if i >= 60: base = 240 + (i - 60) * 10
        if style == "charm":
            price = base + 0.99
            tag = "Bestseller " if i % 16 == 0 else ""
            if i % 20 == 7: tag += "Sale "
            title = f"{tag}Model {100 + i} {cats[i % 8]}"
        else:
            price = float(base)
            title = f"Atelier {cats[i % 8]} {chr(65 + i % 26)}{chr(65 + (i // 3) % 26)}"
        items.append({"title": title, "product_url": f"https://example-store.test/products/p{i}",
                     "current_price": price, "image_url": f"https://example-store.test/img/{i}.jpg"})
    return items

def _st_history(products, scans: int = 14) -> List[Dict[str, Any]]:
    start = datetime(2026, 9, 28, 3, 0, tzinfo=timezone.utc)
    rows = []
    for k in range(scans):
        dt = start + timedelta(days=k)
        ts = dt.isoformat()
        for i, p in enumerate(products):
            price = float(p["current_price"])
            if i % 10 == 0 and dt.weekday() == 6: price = round(price * 0.85, 2)
            rows.append({"product_url": p["product_url"], "product_title": p["title"],
                        "price": price, "recorded_at": ts})
    return rows

def run_selftest() -> int:
    results = []
    def check(name, cond, detail=""):
        results.append((name, bool(cond), detail))
        print(f"[{'PASS' if cond else 'FAIL'}] {name}" + (f" — {detail}" if detail and not cond else ""))
    
    logging.getLogger().setLevel(logging.WARNING)
    charm = _st_products("charm")
    premium = _st_products("premium")
    hist_charm = _st_history(charm)
    hist_prem = _st_history(premium)
    portfolio = {
        "comp-synth-002": {"name": "Rival Alpha", "avg": 38.0, "hhi": 3100.0, "vulnerability": 40.0,
                          "gap_size": 0.0, "avg_drift_pct": 1.5, "drift_known": True,
                          "scan_at": "2026-10-13T00:00:00+00:00"},
        "comp-synth-003": {"name": "Rival Beta", "avg": 95.0, "hhi": 1200.0, "vulnerability": 55.0,
                          "gap_size": 40.0, "avg_drift_pct": -2.0, "drift_known": True, "scarcity": 0,
                          "scan_at": "2026-10-13T00:00:00+00:00"},
        _ST_COMP_ID: {"name": "Synthetic Store", "avg": 60.0, "hhi": 2000.0, "vulnerability": 30.0,
                     "gap_size": 0.0, "avg_drift_pct": 0.0, "drift_known": True,
                     "scan_at": "2026-10-13T00:00:00+00:00",
                     "vuln_points": {"delisting_churn": 12.0, "concentration": 5.0}},
    }
    gone = [{"title": "Retired Cashmere Wrap", "product_url": "https://example-store.test/products/old1",
            "current_price": 120.0}, {"title": "Retired Cashmere Cap",
            "product_url": "https://example-store.test/products/old2", "current_price": 45.0}]
    
    outputs = {}
    for tier in ("free", "pro", "pro_plus", "enterprise"):
        comp = {"id": _ST_COMP_ID, "name": "Synthetic Store", "_tier": tier, "_limits": TIER_LIMITS[tier]}
        eng = PremiumDeterministicMarketIntelligenceEngine(
            comp, charm, db=None, disappeared_products=gone, history_rows=hist_charm, portfolio=portfolio,
            contraction={"count": 8, "prev_count": 12, "ratio": 0.667, "stable_share": 0.9,
                        "together_share": 1.0, "mean_obs": 6.0, "replacement": 0.0, "confidence": 0.9,
                        "avg_last_price": 55.0, "price_low": 40.0, "price_high": 80.0, "pool": 440.0,
                        "examples": ["Retired Wrap"]},
            scan_diff={"prev_count": 12, "new": 0, "removed_raw": 8}
        )
        outputs[tier] = eng.generate_all_insights()
    
    prem_comp = {"id": _ST_COMP_ID, "name": "Atelier Test", "_tier": "pro_plus", "_limits": TIER_LIMITS["pro_plus"]}
    prem_out = PremiumDeterministicMarketIntelligenceEngine(
        prem_comp, premium, db=None, history_rows=hist_prem, portfolio=portfolio
    ).generate_all_insights()
    
    all_rows = [r for rows in outputs.values() for r in rows] + prem_out
    
    # (a) chart bundle keys
    def decode_bundle(rows):
        b = next((r for r in rows if r["type"] == "chart_bundle"), None)
        if not b: return None
        def _bad(_c): raise ValueError("non-finite number")
        try: return json.loads(b["summary"], parse_constant=_bad)
        except Exception: return None
    
    a_ok, a_detail = True, ""
    for label, rows in list(outputs.items()) + [("premium-style", prem_out)]:
        bundle = decode_bundle(rows)
        if bundle is None:
            a_ok, a_detail = False, f"{label}: bundle missing"
            break
        title_ok = next(r for r in rows if r["type"] == "chart_bundle")["title"] == "Market Visualizations"
        shapes = (isinstance(bundle.get("price_distribution"), list) and
                 isinstance(bundle.get("segments"), dict) and
                 all(k in bundle["segments"] for k in ("budget", "mid", "premium")) and
                 isinstance(bundle.get("categories"), list) and
                 isinstance(bundle.get("price_history"), list) and
                 isinstance(bundle.get("signals"), dict) and
                 all(k in bundle["signals"] for k in ("velocity", "scarcity", "freshness", "promo")) and
                 isinstance(bundle.get("headlines"), dict) and
                 all(k in bundle["headlines"] for k in ("avg", "median", "hhi", "cov", "vulnerability")))
        seg_sum = sum(bundle["segments"].values()) if shapes else 0
        if not (title_ok and shapes and 99.0 <= seg_sum <= 101.0):
            a_ok, a_detail = False, f"{label}: keys/shape invalid ({seg_sum})"
            break
        if any(k not in bundle for k in CHART_FROZEN_KEYS):
            a_ok, a_detail = False, f"{label}: frozen key missing"
            break
    check("(a) chart_bundle decodes with all frozen keys", a_ok, a_detail)
    
    # (b) vocabulary
    bad_types = sorted({r["type"] for r in all_rows} - ALLOWED_TYPES)
    check("(b) every emitted type in allowed vocabulary", not bad_types, str(bad_types))
    
    # (c) free-tier gate
    free_types = {r["type"] for r in outputs["free"]}
    leaked = sorted(free_types & PAID_ONLY_TYPES)
    check("(c) FREE tier has zero pro-only types", not leaked, str(leaked))
    check("(c2) FREE receives teaser, paid tiers don't",
          TEASER_TYPE in free_types and all(TEASER_TYPE not in {r['type'] for r in outputs[t]} for t in ("pro", "pro_plus", "enterprise")))
    
    inj_eng = PremiumDeterministicMarketIntelligenceEngine(
        {"id": _ST_COMP_ID, "name": "X", "_tier": "free"}, charm, history_rows=[]
    )
    injected = inj_eng._enforce_tier_gate([{"type": "vulnerability_analysis"}, {"type": "portfolio_map"}, {"type": "executive_summary"}])
    check("(c3) gate strips injected premium types from FREE", [i["type"] for i in injected] == ["executive_summary"])
    check("(c4) portfolio_map only for pro_plus/enterprise",
          "portfolio_map" not in {r["type"] for r in outputs["pro"]} and
          "portfolio_map" in {r["type"] for r in outputs["pro_plus"]} and
          "portfolio_map" in {r["type"] for r in outputs["enterprise"]})
    
    pro_types = {r["type"] for r in outputs["pro"]}
    check("(c5) pro tier carries all six pro-only types and new pro insights",
          {"out_of_stock_signal", "vulnerability_analysis", "financial_blueprint", "quick_wins",
           "strategic_timeline", "cross_reference", "catalog_contraction", "competitive_response",
           "sku_pressure_index", "language_fingerprint", "seasonality_cycle"} <= pro_types,
          str(sorted(pro_types)))
    check("(c6) unknown tier falls back to free gating",
          all(not type_allowed(t, "platinum-hacker") for t in PAID_ONLY_TYPES))
    
    # (c7) delta watch sentence tier-gated
    def _delta_row(rows):
        return next((r for r in rows if r["type"] == "market_timing" and "Watchlist Delta" in r["title"]), None)
    free_clean = all("watched competitors" not in r["summary"] and "Across your" not in r["summary"]
                    for r in outputs["free"] if r["type"] == "market_timing")
    paid_missing = []
    for t in ("pro", "pro_plus", "enterprise"):
        row = _delta_row(outputs[t])
        if row is None or "watched competitors" not in row["summary"]: paid_missing.append(t)
    check("(c7) delta watch sentence tier-gated", free_clean and not paid_missing,
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
    check("(d) vulnerability rubric within [0,100], weights sum 100", d_ok and maxed["score"] == 100, d_detail)
    
    # (e) unsafe strings
    e_bad = []
    for r in all_rows:
        if r["type"] == "chart_bundle": continue
        for fld in ("title", "summary", "ai_recommendation"):
            if _ST_BAD_RE.search(str(r.get(fld, ""))): e_bad.append(f"{r['type']}.{fld}")
    check("(e) no unbound placeholder/None/nan/Infinity", not e_bad, str(e_bad))
    
    # (f) competitor_id
    f_bad = [r["type"] for r in all_rows if not r.get("competitor_id") or r["competitor_id"] != _ST_COMP_ID]
    check("(f) every row carries real competitor_id", not f_bad, str(f_bad))
    
    # extras
    check("dashboard_summary at index 0 for every tier",
          all(rows[0]["type"] == "dashboard_summary" for rows in outputs.values()))
    conf_bad = [r["type"] for r in all_rows if not (0.0 <= _num(r.get("confidence"), -1) <= 1.0)]
    check("every insight has confidence in [0,1]", not conf_bad, str(conf_bad))
    sev_bad = [r["type"] for r in all_rows if r.get("severity") not in ("low", "medium", "high", "critical")]
    check("severity vocabulary valid", not sev_bad, str(sev_bad))
    
    pa_charm = next(r for r in outputs["pro"] if r["type"] == "price_architecture")["ai_recommendation"]
    pa_prem = next(r for r in prem_out if r["type"] == "price_architecture")["ai_recommendation"]
    check("charm-pricing: high psych% → MATCH", "Match their charm endings" in pa_charm and "Do NOT" not in pa_charm, pa_charm[:80])
    check("charm-pricing: ~0 psych% → AVOID", "Do NOT use charm endings" in pa_prem and "Mirror" not in pa_prem, pa_prem[:80])
    
    prem_bundle = decode_bundle(prem_out) or {}
    interp = prem_bundle.get("signals_interpretation") or {}
    check("zero-signals brand gets strategic interpretation",
          interp.get("state") == "silent" and "brand equity" in interp.get("detail", ""), str(interp)[:80])
    
    fb = next(r for r in outputs["pro_plus"] if r["type"] == "financial_blueprint")["ai_recommendation"]
    check("margin matrix renders 3 margins in pro_plus, base case only in pro",
          fb.count("Margin ") == 3 and "Margin " not in next(r for r in outputs["pro"] if r["type"] == "financial_blueprint")["ai_recommendation"])
    
    vuln_txt = next(r for r in outputs["pro"] if r["type"] == "vulnerability_analysis")["summary"]
    check("vulnerability insight shows per-factor breakdown", vuln_txt.count("pts (sub-score") == 7)
    
    # smart stockout guard
    prev = [{"product_url": f"https://s.test/p{i}", "title": f"Old {i}", "current_price": 50.0 + i} for i in range(10)]
    stable_hist = HistoryIndex([{"product_url": p["product_url"], "product_title": p["title"],
                               "price": p["current_price"], "recorded_at": f"2026-10-0{k + 1}T03:00:00+00:00"}
                              for p in prev for k in range(5)])
    keep_urls = {normalize_product_url(prev[0]["product_url"]), normalize_product_url(prev[1]["product_url"])}
    verdict = classify_disappearance(prev[2:], prev, keep_urls, stable_hist)
    check("stockout guard: stable + vanished together → contraction",
          verdict["mode"] == "contraction" and verdict["contraction"]["count"] == 8, str(verdict["mode"]))
    drift = classify_disappearance(prev[2:], prev, keep_urls | {f"s.test/new{i}" for i in range(20)}, stable_hist)
    check("stockout guard: replaced URLs → drift", drift["mode"] == "drift", str(drift["mode"]))
    blind = classify_disappearance(prev[2:], prev, keep_urls, HistoryIndex([]))
    check("stockout guard: no history → drift", blind["mode"] == "drift", str(blind["mode"]))
    small = classify_disappearance(prev[:2], prev, {normalize_product_url(p["product_url"]) for p in prev[2:]}, stable_hist)
    check("stockout guard: small disappearance → stockout", small["mode"] == "stockout")
    
    pm = build_portfolio_map([{"name": "A", "avg": 30.0, "hhi": 3000.0}, {"name": "B", "avg": 90.0, "hhi": 1000.0},
                             {"name": "C", "avg": 35.0, "hhi": 2800.0}])
    check("portfolio map builds quadrants and white-space point",
          bool(pm) and pm["white_space"]["min_distance"] > 0 and len(pm["points"]) == 3)
    check("portfolio map needs ≥2 competitors",
          build_portfolio_map([{"name": "A", "avg": 30.0, "hhi": 3000.0}]) is None)
    check("scrub() neutralizes unsafe tokens",
          "n/a" in scrub("price None and {oops}") and "None" not in scrub("price None"))
    
    failed = [n for n, ok, _ in results if not ok]
    print(f"\nSELFTEST RESULT: {len(results) - len(failed)}/{len(results)} checks passed")
    if failed:
        print("FAILED: " + "; ".join(failed))
        return 1
    print("ALL CHECKS PASSED")
    return 0

# ===================================================================
# MAIN
# ===================================================================
def main():
    parser = argparse.ArgumentParser(
        description=f"Velora v{VERSION} — Deterministic Market Intelligence",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('url', nargs='?', help='Store URL to scan (optional)')
    parser.add_argument('--continuous', '-c', action='store_true', help='Run continuously')
    parser.add_argument('--force-all', '-f', action='store_true', help='Force scan all competitors')
    parser.add_argument('--selftest', action='store_true', help='Run offline self-test and exit')
    args = parser.parse_args()
    
    if args.selftest: sys.exit(run_selftest())
    
    scraper = VeloraScraper()
    scraper.run(url=args.url, continuous=args.continuous, force_all=args.force_all)

if __name__ == "__main__":
    main()
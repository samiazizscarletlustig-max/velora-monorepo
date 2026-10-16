import logging
import json
import re
import time
from typing import List, Dict, Any, Optional, Tuple
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup
from curl_cffi import requests as curl_requests

logger = logging.getLogger('GenericScraper')

# ===================================================================
# Advanced generic scraper = a catalog DISCOVERER, not a page reader.
#
# Root cause this fixes (evidence from a real run on allbirds.com):
#   allbirds is a SHOPIFY store on a custom domain (its homepage HTML
#   contains /cdn/shop/files/...). The platform detector hit HTTP 429 on
#   the homepage and misrouted it to "generic". The OLD generic scraper
#   then parsed ONLY the homepage URL it was handed -- and a Shopify
#   HOMEPAGE is a marketing landing page with zero JSON-LD Product nodes
#   and zero product:price:amount meta tags. Result: 0 products, silently.
#
# The fix: after fetching the homepage (which curl_cffi CAN get even when
# plain httpx 429s), we (1) sniff Shopify fingerprints in that HTML and,
# if present, pivot to the universal /products.json endpoint (full catalog,
# 1-2 requests), and (2) for non-Shopify sites, discover product URLs via
# sitemap.xml and in-page /products/ links, then fetch a BOUNDED set of
# PDPs. Cheap endpoints first, expensive crawl last, with a hard request
# budget so one heavy site cannot exhaust GitHub Actions free-tier minutes.
#
# FROZEN CONTRACT (main.py depends on it; never violate):
#   - signature scrape_generic(url) -> List[Dict]
#   - each dict MUST carry: title, product_url, current_price(float), image_url
#   - NEVER raise; return [] on total failure (main.py maps [] -> NO_PRODUCTS)
# ===================================================================

IMPERSONATE = "chrome120"
TIMEOUT = 30.0

# Final-list cap aligned with the largest tier (pro=1000) but kept modest so a
# single scan stays fast; main.py additionally trims to the per-tier max_products.
MAX_PRODUCT_PAGES = 300
# How many individual PDP pages we are willing to fetch in the crawl stages.
MAX_PDP_FETCH = 80
# /products.json pagination: 4 pages x 250 = 1000 covers pro's max_products.
MAX_JSON_PAGES = 4
JSON_PAGE_SIZE = 250
# Absolute ceiling on HTTP requests per scrape (free-tier / goodwill guard).
REQUEST_BUDGET = 120
# Once we have this many products from a crawl stage, stop fetching more PDPs.
EARLY_STOP_PRODUCTS = 250

_RETRY_AFTER_CAP = 30.0
_TRANSIENT_RETRIES = 2
_BACKOFF_BASE = 2.0

_SHOPIFY_MARKERS = (
    "cdn/shop/", "cdn.shopify.com", "myshopify.com",
    "shopify-section", "shopify.theme", "shopifyassets",
)
# A product URL heuristic for sitemaps / in-page links (covers Shopify, Woo,
# Magento, BigCommerce and most custom carts).
_PRODUCT_HREF_RE = re.compile(r"/(products?|p)/[^/?#]+", re.I)
_LOC_RE = re.compile(r"<loc>\s*(.*?)\s*</loc>", re.I | re.S)
_CHILD_SITEMAP_RE = re.compile(r"sitemap[^<]*product[^<]*\.xml", re.I)

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Cache-Control": "max-age=0",
}
_JSON_HEADERS = dict(_HEADERS)
_JSON_HEADERS.update({
    "Accept": "application/json,text/html;q=0.9,*/*;q=0.8",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-origin",
})


def _norm_url(u: Optional[str]) -> str:
    """Local, dependency-free URL normalizer for de-duplication only."""
    if not u:
        return ""
    s = str(u).strip().lower()
    s = re.sub(r"^https?://", "", s)
    s = re.sub(r"^www\.", "", s)
    s = s.split("?")[0].split("#")[0].rstrip("/")
    return s


def _abs(base: str, href: Optional[str]) -> str:
    if not href:
        return ""
    href = str(href).strip()
    if href.startswith("//"):
        href = "https:" + href
    return urljoin(base + "/", href)


def _to_float(x: Any) -> float:
    try:
        v = float(str(x).replace(",", "").replace("$", "").strip())
        return v if v == v and v not in (float("inf"), float("-inf")) else 0.0
    except (TypeError, ValueError):
        return 0.0


class _Budget:
    """Counts requests and refuses to exceed the per-scrape ceiling."""
    def __init__(self, total: int) -> None:
        self.left = total

    def spend(self, n: int = 1) -> bool:
        if self.left < n:
            return False
        self.left -= n
        return True


def _retry_after(resp: Any) -> float:
    try:
        raw = resp.headers.get("Retry-After")
    except Exception:
        raw = None
    if not raw:
        return 0.0
    try:
        return max(0.0, float(raw))
    except (TypeError, ValueError):
        return _BACKOFF_BASE


def _get(session: Any, url: str, budget: _Budget,
         headers: Optional[Dict[str, str]] = None,
         as_json: bool = False) -> Tuple[Optional[str], Optional[int]]:
    """Bounded, polite GET. Returns (text_or_None, status_or_None). NEVER raises.

    Policy:
      * 429  -> ONE Retry-After-aware backoff, then give up (never hammer a
                rate-limited host; this is the free-tier / goodwill guard).
      * >=400 -> return (None, status) so the caller can try an alternate path.
      * transient transport errors -> up to _TRANSIENT_RETRIES with exp backoff.
    """
    if not budget.spend():
        return None, None
    h = headers or (_JSON_HEADERS if as_json else _HEADERS)
    last_status: Optional[int] = None
    transient_left = _TRANSIENT_RETRIES
    allow_429 = True
    while True:
        try:
            resp = session.get(url, headers=h, timeout=TIMEOUT)
            last_status = getattr(resp, "status_code", None)
            if last_status == 429:
                if allow_429:
                    allow_429 = False
                    wait = min(max(_retry_after(resp) or _BACKOFF_BASE, 1.0), _RETRY_AFTER_CAP)
                    logger.info(f"⏳ 429 on {url}; one backoff {wait:.0f}s")
                    time.sleep(wait)
                    if not budget.spend():
                        return None, 429
                    continue
                return None, 429
            if last_status is not None and last_status >= 400:
                return None, last_status
            return resp.text, last_status
        except Exception as te:  # noqa: BLE001 - must never propagate to main.py
            if transient_left > 0:
                transient_left -= 1
                step = _TRANSIENT_RETRIES - transient_left
                wait = min(_BACKOFF_BASE * (2 ** (step - 1)), _RETRY_AFTER_CAP)
                logger.info(f"⏳ transient {type(te).__name__} on {url}; retry in {wait:.0f}s")
                time.sleep(wait)
                if not budget.spend():
                    return None, last_status
                continue
            logger.warning(f"⚠️ fetch exhausted on {url}: {te}")
            return None, last_status


# -------------------------------------------------------------------
# Parsers (operate on a fetched HTML string + the page's canonical URL)
# -------------------------------------------------------------------
def _parse_jsonld_products(html: str, page_url: str) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    try:
        soup = BeautifulSoup(html, "html.parser")
    except Exception:
        return out
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or "")
        except (json.JSONDecodeError, TypeError, ValueError):
            continue
        nodes = data.get("@graph", [data]) if isinstance(data, dict) else (data if isinstance(data, list) else [])
        if not isinstance(nodes, list):
            nodes = [nodes]
        for item in nodes:
            if not isinstance(item, dict):
                continue
            t = item.get("@type", "")
            if "Product" not in str(t):
                continue
            offers = item.get("offers", {})
            if isinstance(offers, list):
                offers = offers[0] if offers else {}
            if not isinstance(offers, dict):
                offers = {}
            price = _to_float(offers.get("price", offers.get("lowPrice", 0)))
            name = str(item.get("name", "")).strip()
            image = item.get("image", "")
            if isinstance(image, list):
                image = image[0] if image else ""
            canonical = str(item.get("url", "")).strip() or page_url
            if name and price > 0:
                out.append({
                    "title": name,
                    "current_price": price,
                    "product_url": canonical,
                    "image_url": str(image).strip(),
                    "currency": str(offers.get("priceCurrency", "USD")).strip(),
                })
    return out


def _parse_meta_products(html: str, page_url: str) -> List[Dict[str, Any]]:
    try:
        soup = BeautifulSoup(html, "html.parser")
    except Exception:
        return []
    title = soup.find("meta", property="og:title")
    price_meta = soup.find("meta", property="product:price:amount")
    image_meta = soup.find("meta", property="og:image")
    if not (title and price_meta):
        return []
    price = _to_float(price_meta.get("content", 0))
    if price <= 0:
        return []
    return [{
        "title": str(title.get("content", "Unknown Product")).strip(),
        "current_price": price,
        "product_url": page_url,
        "image_url": str(image_meta.get("content", "")).strip() if image_meta else "",
        "currency": "USD",
    }]


def _parse_one_pdp(html: str, page_url: str) -> List[Dict[str, Any]]:
    """Best-effort extraction from a single product detail page."""
    prods = _parse_jsonld_products(html, page_url)
    if not prods:
        prods = _parse_meta_products(html, page_url)
    # Force the canonical URL to the PDP we actually fetched (JSON-LD 'url'
    # can be relative or point at a variant); keeps product_url trustworthy.
    for p in prods:
        if not p.get("product_url") or p["product_url"].startswith("/"):
            p["product_url"] = page_url
    return prods


# -------------------------------------------------------------------
# Discovery strategies (cheap -> expensive)
# -------------------------------------------------------------------
def _looks_shopify(html: str) -> bool:
    t = (html or "").lower()
    return any(m in t for m in _SHOPIFY_MARKERS)


def _shopify_products_json(session: Any, base: str, budget: _Budget) -> List[Dict[str, Any]]:
    """Universal Shopify catalog endpoint. Returns the FULL catalog in a few
    requests -- this is what rescues allbirds (a Shopify store misrouted to
    generic by a 429 on the homepage)."""
    out: List[Dict[str, Any]] = []
    for page in range(1, MAX_JSON_PAGES + 1):
        if len(out) >= MAX_PRODUCT_PAGES or not budget.spend():
            break
        url = f"{base}/products.json?limit={JSON_PAGE_SIZE}&page={page}"
        text, status = _get(session, url, budget, as_json=True)
        if status != 200 or not text:
            break  # endpoint disabled / blocked -> fall through to other strategies
        try:
            payload = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            break
        items = payload.get("products", []) if isinstance(payload, dict) else []
        if not items:
            break
        for it in items:
            if not isinstance(it, dict):
                continue
            handle = str(it.get("handle", "")).strip()
            title = str(it.get("title", "")).strip()
            variants = it.get("variants") or [{}]
            price = _to_float(variants[0].get("price", 0)) if isinstance(variants, list) and variants else 0.0
            images = it.get("images") or []
            image = ""
            if isinstance(images, list) and images and isinstance(images[0], dict):
                image = str(images[0].get("src", "")).strip()
            if not (title and price > 0):
                continue
            purl = f"{base}/products/{handle}" if handle else base
            out.append({
                "title": title,
                "current_price": price,
                "product_url": purl,
                "image_url": image,
                "currency": "USD",
            })
            if len(out) >= MAX_PRODUCT_PAGES:
                break
    return out


def _sitemap_product_urls(session: Any, base: str, budget: _Budget) -> List[str]:
    """Collect product URLs from sitemap.xml (and one product child sitemap if
    the master is an index). Sitemaps are rarely rate-limited like the HTML."""
    urls: List[str] = []
    text, status = _get(session, f"{base}/sitemap.xml", budget)
    if status != 200 or not text:
        return urls
    locs = [m.group(1).strip() for m in _LOC_RE.finditer(text) if m.group(1).strip()]
    # If this is a sitemap index pointing at a product child sitemap, follow ONE.
    children = [u for u in locs if _CHILD_SITEMAP_RE.search(u)]
    if children and not any(_PRODUCT_HREF_RE.search(u) for u in locs):
        child = children[0]
        ctext, cstatus = _get(session, child, budget)
        if cstatus == 200 and ctext:
            locs += [m.group(1).strip() for m in _LOC_RE.finditer(ctext) if m.group(1).strip()]
    seen = set()
    for u in locs:
        if _PRODUCT_HREF_RE.search(u):
            n = _norm_url(u)
            if n and n not in seen:
                seen.add(n)
                urls.append(u)
            if len(urls) >= MAX_PDP_FETCH:
                break
    return urls


def _in_page_product_links(html: str, base: str) -> List[str]:
    try:
        soup = BeautifulSoup(html, "html.parser")
    except Exception:
        return []
    seen, urls = set(), []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not _PRODUCT_HREF_RE.search(href):
            continue
        absolute = _abs(base, href)
        n = _norm_url(absolute)
        if n and n not in seen:
            seen.add(n)
            urls.append(absolute)
        if len(urls) >= MAX_PDP_FETCH:
            break
    return urls


def _crawl_pdps(session: Any, urls: List[str], budget: _Budget) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for u in urls:
        if len(out) >= EARLY_STOP_PRODUCTS or not budget.spend():
            break
        text, status = _get(session, u, budget)
        if status != 200 or not text:
            continue
        out.extend(_parse_one_pdp(text, u))
        if len(out) >= MAX_PRODUCT_PAGES:
            break
    return out


# -------------------------------------------------------------------
# Entry point
# -------------------------------------------------------------------
def scrape_generic(url: str) -> List[Dict[str, Any]]:
    logger.info(f"Starting advanced generic scrape for {url}")
    products: List[Dict[str, Any]] = []
    budget = _Budget(REQUEST_BUDGET)

    try:
        if "://" not in url:
            url = "https://" + url.lstrip("/")
        parsed = urlparse(url)
        if not parsed.netloc:
            logger.warning(f"⚠️ unparseable url {url!r}; returning []")
            return []
        base = f"{parsed.scheme}://{parsed.netloc}"

        session = curl_requests.Session(impersonate=IMPERSONATE)

        # Stage 0: fetch the homepage (curl_cffi often succeeds where plain
        # httpx 429s -- this is exactly the allbirds situation).
        html, status = _get(session, url, budget)
        if status != 200 or not html:
            # One polite httpx fallback, then give up gracefully.
            try:
                import httpx
                with httpx.Client(headers=_HEADERS, follow_redirects=True, timeout=TIMEOUT) as cx:
                    r = cx.get(url)
                    if r.status_code == 200:
                        html, status = r.text, 200
            except Exception:
                pass
        if not html:
            logger.warning(f"❌ could not fetch homepage for {url}; returning []")
            return []

        # Baseline: featured products that DO live on the homepage.
        products.extend(_parse_jsonld_products(html, url))
        if len(products) < 3:
            products.extend(_parse_meta_products(html, url))

        # Stage 1 (the allbirds rescue): if the homepage HTML smells like
        # Shopify, the catalog is at /products.json regardless of routing.
        if _looks_shopify(html):
            logger.info("️ Shopify fingerprint in homepage HTML -> probing /products.json")
            sj = _shopify_products_json(session, base, budget)
            if sj:
                products = sj  # authoritative full catalog; skip expensive crawl
                logger.info(f"✅ Shopify /products.json yielded {len(products)} products")

        # Stage 2: sitemap-discovered PDPs (non-Shopify or json disabled).
        if len(products) < 3:
            logger.info("🗺️ trying sitemap.xml for product URLs")
            pdp_urls = _sitemap_product_urls(session, base, budget)
            if pdp_urls:
                products.extend(_crawl_pdps(session, pdp_urls, budget))

        # Stage 3: in-page /products/ links as a last discovery resort.
        if len(products) < 3:
            logger.info("🔗 trying in-page product links")
            link_urls = _in_page_product_links(html, base)
            if link_urls:
                products.extend(_crawl_pdps(session, link_urls, budget))

        # De-duplicate by normalized product_url, preserving first-seen order.
        seen, deduped = set(), []
        for p in products:
            n = _norm_url(p.get("product_url"))
            if not n or n in seen:
                continue
            seen.add(n)
            deduped.append(p)
            if len(deduped) >= MAX_PRODUCT_PAGES:
                break

        logger.info(f"✅ Successfully extracted {len(deduped)} products via advanced generic scraper")
        return deduped

    except Exception as e:  # noqa: BLE001 - contract: never raise to main.py
        logger.error(f"❌ Generic scraper failed for {url}: {e}")
        return []
    finally:
        try:
            session.close()  # type: ignore[name-defined]
        except Exception:
            pass
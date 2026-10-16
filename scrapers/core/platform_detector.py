import httpx
import logging
import time
from urllib.parse import urlparse, urljoin

logger = logging.getLogger(__name__)

# ===================================================================
# Platform detection = a ROUTING decision, not a data harvest.
# Two hard rules inherited from main.py's contract (NEVER violate):
#   1. Return value MUST be one of {'shopify','woocommerce','generic'}.
#      (main.py does self.scrapers.get(platform, scrape_generic); a 4th string
#       would silently fall back to generic anyway, so adding one buys nothing
#       and risks confusing future readers. Keep the 3.)
#   2. This function is called OUTSIDE main.py's per-attempt try/except
#      (see ScraperEngine.scrape: `platform = detect_platform(url)` precedes the
#       for-loop). Therefore it MUST NEVER RAISE. Any unhandled exception here
#       aborts the whole competitor scan as FAILED. Everything is wrapped.
#
# Why the old version was unsafe:
#   - A single transient blip (timeout/reset) on a REAL Shopify homepage returned
#     "generic" -> the Shopify site got scraped by the generic scraper -> 0/few
#     products = a SILENT MISROUTE (worse than a clean failure).
#   - A 429 on the homepage raised via res.raise_for_status() -> caught -> "generic",
#     losing the chance to peek at cheaper endpoints that WAFs often do NOT
#     rate-limit identically (sitemap.xml / robots.txt), so a blocked Shopify
#     homepage was misrouted to generic too.
#   - No Retry-After handling: on a 429 it neither backed off politely nor stopped,
#     inviting a harder block (free-tier / goodwill risk).
# ===================================================================

_VALID_PLATFORMS = ("shopify", "woocommerce", "generic")

_MAX_TRANSIENT_RETRIES = 2      # ConnectError / Timeout / RemoteProtocolError only
_BACKOFF_BASE_SECONDS = 2.0
_MAX_BACKOFF_SECONDS = 30.0
_REQUEST_TIMEOUT = 15.0

# Strong, low-false-positive fingerprints. Ordered so the most specific win.
_SHOPIFY_MARKERS = (
    "cdn.shopify.com", "myshopify.com", "shopify-section", "shopify.theme",
    "shopifyassets", "shopify.com",
)
_WOO_MARKERS = (
    "wp-content/plugins/woocommerce", "woocommerce_params", "wc-cart-fragments",
    "woocommerce",
)

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def _classify_text(text: str) -> str:
    """Pure function: map a body blob to one of the 3 platforms. Never raises."""
    t = (text or "").lower()
    for marker in _SHOPIFY_MARKERS:
        if marker in t:
            return "shopify"
    for marker in _WOO_MARKERS:
        if marker in t:
            return "woocommerce"
    return "generic"


def _retry_after_seconds(response: httpx.Response) -> float:
    """Parse Retry-After (seconds form). HTTP-date form -> a modest fixed wait.
    Never raises; unknown/absent -> 0.0 so the caller applies its own base backoff."""
    raw = response.headers.get("Retry-After")
    if not raw:
        return 0.0
    try:
        return max(0.0, float(raw))
    except (TypeError, ValueError):
        return _BACKOFF_BASE_SECONDS


def _fetch(client: httpx.Client, url: str, allow_429_backoff: bool = True):
    """GET with BOUNDED, polite retries. Returns (text_or_None, status_or_None).

    Policy (this is the whole point of the rewrite):
      * 429  -> at most ONE Retry-After-aware backoff (if allowed), then STOP.
                We never hammer a rate-limited host; probes pass allow_429_backoff=False
                so they give up on 429 immediately.
      * >=400 (403/404/...) -> not a transport blip; return (None, status) so the caller
                can try a secondary probe instead of trusting a blocked homepage.
      * transient transport errors (timeout / connection reset / protocol) -> retry up to
                _MAX_TRANSIENT_RETRIES with exponential backoff. THIS is what fixes the
                silent-misroute: a real Shopify site is no longer downgraded to generic
                because of one flaky packet.
      * anything else -> log + return (None, last_status). NEVER raises.
    """
    last_status = None
    transient_left = _MAX_TRANSIENT_RETRIES
    allow_429 = allow_429_backoff

    while True:
        try:
            res = client.get(url)
            last_status = res.status_code

            if res.status_code == 429:
                if allow_429:
                    allow_429 = False  # single shot only
                    wait = _retry_after_seconds(res) or _BACKOFF_BASE_SECONDS
                    wait = min(max(wait, 1.0), _MAX_BACKOFF_SECONDS)
                    logger.info(f"⏳ 429 on {url}; one Retry-After-aware backoff {wait:.0f}s")
                    time.sleep(wait)
                    continue
                return None, 429  # still blocked after the one backoff -> stop politely

            if res.status_code >= 400:
                return None, res.status_code  # let caller probe alternates

            return res.text, res.status_code  # 2xx/3xx(after follow_redirects)

        except (httpx.TimeoutException, httpx.ConnectError, httpx.RemoteProtocolError) as te:
            if transient_left > 0:
                transient_left -= 1
                step = (_MAX_TRANSIENT_RETRIES - transient_left)  # 1,2,...
                wait = min(_BACKOFF_BASE_SECONDS * (2 ** (step - 1)), _MAX_BACKOFF_SECONDS)
                logger.info(
                    f"⏳ transient {type(te).__name__} on {url}; "
                    f"retry ({_MAX_TRANSIENT_RETRIES - transient_left}/{_MAX_TRANSIENT_RETRIES}) in {wait:.0f}s"
                )
                time.sleep(wait)
                continue
            logger.warning(f"⚠️ transient failures exhausted on {url}: {te}")
            return None, last_status

        except httpx.HTTPStatusError as he:
            return None, (he.response.status_code if he.response is not None else last_status)

        except Exception as e:  # absolute last resort: never propagate to main.py
            logger.warning(f"⚠️ unexpected fetch error on {url}: {e}")
            return None, last_status


def detect_platform(url: str) -> str:
    """Detect storefront platform -> 'shopify' | 'woocommerce' | 'generic'.

    Strategy:
      1. Normalize scheme (a bare 'gymshark.com' must not become a misroute).
      2. Primary homepage GET (bounded, transient-retrying, single 429 backoff).
         - If it yields a shopify/woo fingerprint -> return it.
         - If it is a CLEAN 200 generic -> trust it (this is correct for React/Next
           storefronts like Allbirds; their data is JS-hydrated, not in static HTML).
         - If it was BLOCKED/failed (None body) -> do NOT trust 'generic' yet; a
           blocked homepage can hide a Shopify/Woo fingerprint. Fall to step 3.
      3. Secondary cheap probes (/sitemap.xml, /robots.txt): WAFs frequently do NOT
         rate-limit these the same way as the HTML homepage, so they can still reveal
         shopify/woo markers and PREVENT a misroute. First probe that returns 200 with
         no marker means the site is genuinely generic -> stop probing (don't hammer).
      4. Default 'generic'. The whole body is wrapped so we NEVER raise.
    """
    try:
        if "://" not in url:
            url = "https://" + url.lstrip("/")
        parsed = urlparse(url)
        if not parsed.netloc:
            logger.warning(f"⚠️ detect_platform: unparseable url {url!r}; generic")
            return "generic"
        base = f"{parsed.scheme}://{parsed.netloc}"

        with httpx.Client(
            timeout=_REQUEST_TIMEOUT, follow_redirects=True, headers=_HEADERS
        ) as client:
            body, status = _fetch(client, base)

            if body is not None:
                plat = _classify_text(body)
                if plat != "generic":
                    logger.info(f"🛍️ Detected: {plat.capitalize()}")
                    return plat
                if status == 200:
                    # Clean 200 with no shopify/woo marker => genuinely generic
                    # (Next.js/React storefront). Correct answer; no need to probe.
                    logger.info("🌐 Detected: Generic (HTML 200)")
                    return "generic"
                # else: body present but status unusual, or blocked-ish -> try probes.

            # Homepage blocked/failed: cheap probes may still expose the platform.
            for probe_path in ("/sitemap.xml", "/robots.txt"):
                probe_url = urljoin(base + "/", probe_path.lstrip("/"))
                pbody, pstatus = _fetch(client, probe_url, allow_429_backoff=False)
                if pbody:
                    plat = _classify_text(pbody)
                    if plat != "generic":
                        logger.info(f"🔎 Detected {plat.capitalize()} via {probe_path}")
                        return plat
                if pstatus == 200:
                    # Probe reachable but no fingerprint => site is truly generic.
                    # Stop here; do not burn more requests on a confirmed-generic host.
                    break

            logger.info("🌐 Detected: Generic (fallback)")
            return "generic"

    except Exception as e:
        # Contract rule #2: must never raise (called outside main.py's try/except).
        logger.warning(f"⚠️ Platform detection error ({e}); defaulting to generic")
        return "generic"
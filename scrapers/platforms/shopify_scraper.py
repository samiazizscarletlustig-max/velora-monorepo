"""
🛍️ Shopify Scraper — Enhanced Edition
4 fallback methods:
1. /products.json (official endpoint — fastest & most reliable)
2. Main sitemap.xml → sub-sitemaps
3. Direct sitemap_products_1.xml
4. /collections/all (HTML)
+ Homepage warm-up (cookies) to bypass simple WAFs
"""
import httpx
import logging
import re
import json
from typing import List, Dict, Any, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

logger = logging.getLogger(__name__)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Cache-Control": "no-cache",
    "Sec-Ch-Ua": '"Chromium";v="126", "Google Chrome";v="126", "Not-A.Brand";v="8"',
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Ch-Ua-Platform": '"Windows"',
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Upgrade-Insecure-Requests": "1",
}

MAX_PRODUCTS = 250  # cap per scan (keeps runtime + DB healthy)


def _make_client() -> httpx.Client:
    return httpx.Client(
        timeout=30.0,
        follow_redirects=True,
        headers=HEADERS,
        limits=httpx.Limits(max_connections=8, max_keepalive_connections=4),
    )


def _warm_up(client: httpx.Client, url: str) -> str:
    """Visit homepage first: collects cookies + resolves final base URL (www vs non-www)."""
    try:
        resp = client.get(url)
        base = str(resp.url).rstrip("/")
        logger.info(f"🏠 Warm-up OK → base URL: {base}")
        return base
    except Exception as e:
        logger.warning(f"⚠️ Warm-up failed: {e}")
        return url.rstrip("/")


# ═══════════════════════════════════════════════════════
# METHOD 1 — /products.json (official Shopify endpoint)
# ═══════════════════════════════════════════════════════
def _method_products_json(client: httpx.Client, base_url: str) -> List[Dict[str, Any]]:
    logger.info("📡 Method 1: /products.json ...")
    products: List[Dict[str, Any]] = []

    for page in range(1, 21):  # max 20 pages × 250 = 5000
        try:
            resp = client.get(
                f"{base_url}/products.json",
                params={"page": page, "limit": 250},
            )
            if resp.status_code != 200:
                logger.info(f"   → status {resp.status_code}, stopping pagination")
                break

            batch = resp.json().get("products", [])
            if not batch:
                break

            for p in batch:
                variants = p.get("variants") or []
                images = p.get("images") or []

                price = 0.0
                sku = ""
                if variants:
                    try:
                        price = float(variants[0].get("price") or 0)
                    except (TypeError, ValueError):
                        price = 0.0
                    sku = variants[0].get("sku") or ""

                products.append({
                    "title": p.get("title") or "Unknown",
                    "product_url": f"{base_url}/products/{p.get('handle', '')}",
                    "image_url": images[0].get("src", "") if images else "",
                    "current_price": price,
                    "sku": sku,
                })

            logger.info(f"   → page {page}: +{len(batch)} products (total {len(products)})")

            if len(batch) < 250 or len(products) >= MAX_PRODUCTS:
                break

        except Exception as e:
            logger.warning(f"   → error on page {page}: {e}")
            break

    if products:
        logger.info(f"✅ Method 1 OK: {len(products)} products")
    return products[:MAX_PRODUCTS]


# ═══════════════════════════════════════════════════════
# METHODS 2-4 — collect product URLs (sitemaps / collections)
# ═══════════════════════════════════════════════════════
def _collect_product_urls(client: httpx.Client, base_url: str) -> List[str]:
    urls: List[str] = []

    # Method 2: main sitemap.xml → product sub-sitemaps
    logger.info("📡 Method 2: /sitemap.xml ...")
    try:
        resp = client.get(f"{base_url}/sitemap.xml")
        if resp.status_code == 200:
            sub_sitemaps = re.findall(r"<loc>([^<]*products[^<]*\.xml)</loc>", resp.text)
            if sub_sitemaps:
                for sub in sub_sitemaps[:5]:
                    try:
                        r2 = client.get(sub)
                        if r2.status_code == 200:
                            urls += re.findall(r"<loc>(https?://[^<]+/products/[^<]+)</loc>", r2.text)
                    except Exception:
                        pass
            else:
                urls = re.findall(r"<loc>(https?://[^<]+/products/[^<]+)</loc>", resp.text)
    except Exception as e:
        logger.warning(f"   → error: {e}")

    # Method 3: direct sitemap_products_1.xml
    if not urls:
        logger.info("📡 Method 3: /sitemap_products_1.xml ...")
        try:
            resp = client.get(f"{base_url}/sitemap_products_1.xml")
            if resp.status_code == 200:
                urls = re.findall(r"<loc>(https?://[^<]+/products/[^<]+)</loc>", resp.text)
        except Exception as e:
            logger.warning(f"   → error: {e}")

    # Method 4: /collections/all (HTML product links)
    if not urls:
        logger.info("📡 Method 4: /collections/all ...")
        for page in range(1, 6):
            try:
                resp = client.get(f"{base_url}/collections/all", params={"page": page})
                if resp.status_code != 200:
                    break
                found = re.findall(r'href="(/products/[^"?#]+)', resp.text)
                if not found:
                    break
                urls += [base_url + f for f in found]
            except Exception:
                break

    unique = list(dict.fromkeys(urls))[:MAX_PRODUCTS]
    logger.info(f"🔗 Collected {len(unique)} unique product URLs")
    return unique


# ═══════════════════════════════════════════════════════
# Product page extraction (JSON-LD → og/meta fallback)
# ═══════════════════════════════════════════════════════
def extract_product_data(url: str, client: httpx.Client) -> Optional[Dict[str, Any]]:
    try:
        response = client.get(url)
        response.raise_for_status()
        html = response.text

        # --- JSON-LD ---
        for ld_match in re.finditer(
            r'<script type="application/ld\+json"[^>]*>(.*?)</script>', html, re.DOTALL
        ):
            try:
                data = json.loads(ld_match.group(1))
            except json.JSONDecodeError:
                continue

            nodes = data if isinstance(data, list) else [data]
            if isinstance(data, dict) and "@graph" in data:
                nodes = data["@graph"]

            for node in nodes:
                if not isinstance(node, dict):
                    continue
                if node.get("@type") not in ("Product", "ProductGroup"):
                    continue

                variants = node.get("hasVariant") or []
                offers = node.get("offers") or {}
                if isinstance(offers, list):
                    offers = offers[0] if offers else {}

                first = variants[0] if variants else {}
                price, sku, image = 0.0, "", node.get("image", "")

                if isinstance(first, dict):
                    off = first.get("offers") or offers
                    if isinstance(off, list):
                        off = off[0] if off else {}
                    try:
                        price = float((off or {}).get("price", 0) or 0)
                    except (TypeError, ValueError):
                        price = 0.0
                    sku = first.get("sku") or ""
                    image = first.get("image") or image
                elif isinstance(offers, dict):
                    try:
                        price = float(offers.get("price", 0) or 0)
                    except (TypeError, ValueError):
                        price = 0.0

                if isinstance(image, list):
                    image = image[0] if image else ""
                if isinstance(image, dict):
                    image = image.get("url", "")

                return {
                    "title": node.get("name", "Unknown"),
                    "product_url": url,
                    "image_url": image or "",
                    "current_price": price,
                    "sku": sku,
                }

        # --- Fallback: og tags + inline price ---
        title_m = re.search(r'<meta property="og:title" content="([^"]+)"', html) or \
                  re.search(r"<title>(.*?)</title>", html, re.DOTALL)
        if not title_m:
            return None

        image_m = re.search(r'<meta property="og:image" content="([^"]+)"', html)
        price_m = re.search(r'"price":(\d+\.?\d*)', html) or \
                  re.search(r'itemprop="price" content="([^"]+)"', html)

        try:
            price = float(price_m.group(1)) if price_m else 0.0
        except (TypeError, ValueError):
            price = 0.0

        return {
            "title": title_m.group(1).strip(),
            "product_url": url,
            "image_url": image_m.group(1) if image_m else "",
            "current_price": price,
            "sku": "",
        }

    except Exception as e:
        logger.debug(f"Failed to scrape {url}: {e}")
        return None


# ═══════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════
def scrape_shopify(store_url: str) -> List[Dict[str, Any]]:
    parsed_products: List[Dict[str, Any]] = []

    with _make_client() as client:
        base_url = _warm_up(client, store_url)

        # Method 1: products.json
        parsed_products = _method_products_json(client, base_url)

        # Methods 2-4 if Method 1 failed
        if not parsed_products:
            product_urls = _collect_product_urls(client, base_url)

            if product_urls:
                logger.info(f"🚀 Scraping {len(product_urls)} product pages (4 workers)...")
                with ThreadPoolExecutor(max_workers=4) as executor:
                    futures = {
                        executor.submit(extract_product_data, u, client): u
                        for u in product_urls
                    }
                    for i, future in enumerate(as_completed(futures), 1):
                        result = future.result()
                        if result:
                            parsed_products.append(result)
                        if i % 25 == 0:
                            logger.info(
                                f"⏳ Progress: {i}/{len(product_urls)} pages "
                                f"({len(parsed_products)} valid)"
                            )

    logger.info(f"✅ Successfully scraped {len(parsed_products)} products.")
    return parsed_products
import httpx
import logging
import re
import json
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor, as_completed

logger = logging.getLogger(__name__)

def extract_product_data(url: str, client: httpx.Client) -> Dict[str, Any]:
    """Fetches a single product page and extracts data from JSON-LD."""
    try:
        response = client.get(url)
        response.raise_for_status()
        
        # Shopify embeds product data in <script type="application/ld+json">
        ld_match = re.search(r'<script type="application/ld\+json">(.*?)</script>', response.text, re.DOTALL)
        if not ld_match:
            return None
            
        data = json.loads(ld_match.group(1))
        
        # Gymshark uses "ProductGroup" with "hasVariant" array
        variants = data.get("hasVariant", [])
        if not variants:
            return None
            
        first_variant = variants[0]
        
        title = data.get("name", "")
        product_url = url
        
        # Image
        image_url = first_variant.get("image", "")
        if isinstance(image_url, list):
            image_url = image_url[0] if image_url else ""
            
        # Price & SKU
        sku = first_variant.get("sku", "")
        offers = first_variant.get("offers", {})
        price_str = offers.get("price", "0")
        try:
            current_price = float(price_str)
        except (ValueError, TypeError):
            current_price = 0.0
            
        return {
            "title": title,
            "product_url": product_url,
            "image_url": image_url,
            "current_price": current_price,
            "sku": sku
        }
        
    except Exception as e:
        logger.debug(f"Failed to scrape {url}: {e}")
        return None

def scrape_shopify(store_url: str) -> List[Dict[str, Any]]:
    """
    Scrapes a Shopify store by fetching the product sitemap and scraping individual HTML pages.
    This bypasses the 403 Forbidden block on the /products.json endpoint used by large stores like Gymshark.
    """
    base_url = store_url.rstrip("/")
    sitemap_url = f"{base_url}/sitemap_products_1.xml"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }

    logger.info(f"Fetching product sitemap from {sitemap_url}")
    parsed_products = []
    
    try:
        with httpx.Client(timeout=30.0, follow_redirects=True, headers=headers) as client:
            # 1. Fetch Sitemap
            sitemap_response = client.get(sitemap_url)
            sitemap_response.raise_for_status()
            
            # Extract all product URLs from XML
            product_urls = re.findall(r'<loc>(https?://[^<]+/products/[^<]+)</loc>', sitemap_response.text)
            logger.info(f"🔍 Found {len(product_urls)} product URLs in sitemap.")
            
            # 2. Scrape individual pages concurrently
            logger.info("🚀 Starting concurrent scraping... This may take a few minutes.")
            with ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(extract_product_data, url, client): url for url in product_urls}
                
                for i, future in enumerate(as_completed(futures)):
                    result = future.result()
                    if result:
                        parsed_products.append(result)
                    
                    # Log progress every 100 products
                    if (i + 1) % 100 == 0:
                        logger.info(f"⏳ Progress: Scraped {i + 1}/{len(product_urls)} pages... ({len(parsed_products)} valid products found)")

    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error occurred: {e}")
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")

    logger.info(f"✅ Successfully scraped {len(parsed_products)} products.")
    return parsed_products
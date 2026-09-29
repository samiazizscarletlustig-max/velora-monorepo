import logging
import json
from typing import List, Dict, Any
from bs4 import BeautifulSoup
from curl_cffi import requests

logger = logging.getLogger('GenericScraper')

def scrape_generic(url: str) -> List[Dict[str, Any]]:
    logger.info(f"Starting advanced generic scrape for {url}")
    products = []
    
    # Headers that mimic a real Chrome browser to bypass basic Cloudflare/bot protection
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
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

    try:
        # Use curl_cffi to impersonate Chrome 120 and bypass TLS fingerprinting
        logger.info("Attempting to fetch with curl_cffi (Chrome impersonation)...")
        response = requests.get(url, headers=headers, timeout=30, impersonate="chrome120")
        
        if response.status_code != 200:
            logger.warning(f"curl_cffi failed with status {response.status_code}, falling back to standard httpx...")
            import httpx
            client = httpx.Client(headers=headers, follow_redirects=True, timeout=30)
            response = client.get(url)
            
        response.raise_for_status()
        html = response.text
        soup = BeautifulSoup(html, 'html.parser')
        
        # Strategy 1: Extract from JSON-LD (Most reliable for big sites like Nike/Adidas)
        scripts = soup.find_all('script', type='application/ld+json')
        for script in scripts:
            try:
                data = json.loads(script.string)
                # Handle both single object and @graph array
                items = data.get('@graph', [data]) if isinstance(data, dict) else []
                if not isinstance(items, list):
                    items = [items]
                    
                for item in items:
                    if item.get('@type') == 'Product' or 'Product' in str(item.get('@type', '')):
                        name = item.get('name', '')
                        offers = item.get('offers', {})
                        if isinstance(offers, list):
                            offers = offers[0] if offers else {}
                        
                        price = offers.get('price', 0)
                        currency = offers.get('priceCurrency', 'USD')
                        image = item.get('image', '')
                        if isinstance(image, list):
                            image = image[0] if image else ''
                        
                        if name and price:
                            products.append({
                                "title": str(name).strip(),
                                "current_price": float(price),
                                "product_url": url,
                                "image_url": str(image).strip(),
                                "currency": str(currency).strip()
                            })
            except (json.JSONDecodeError, TypeError, ValueError):
                continue
                
        # Strategy 2: Fallback to basic HTML meta tags if JSON-LD yields nothing
        if len(products) < 3:
            logger.info("JSON-LD yielded few products, attempting basic HTML meta extraction...")
            title = soup.find('meta', property='og:title')
            price_meta = soup.find('meta', property='product:price:amount')
            image_meta = soup.find('meta', property='og:image')
            
            if title and price_meta:
                try:
                    products.append({
                        "title": title.get('content', 'Unknown Product').strip(),
                        "current_price": float(price_meta.get('content', 0)),
                        "product_url": url,
                        "image_url": image_meta.get('content', '').strip() if image_meta else '',
                        "currency": "USD"
                    })
                except ValueError:
                    pass

        logger.info(f"✅ Successfully extracted {len(products)} products via advanced generic scraper")
        return products
        
    except Exception as e:
        logger.error(f"❌ Generic scraper failed for {url}: {e}")
        return []
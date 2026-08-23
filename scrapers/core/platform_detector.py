import httpx
import logging
from urllib.parse import urlparse

logger = logging.getLogger(__name__)


def detect_platform(url: str) -> str:
    """يحدد منصة المتجر تلقائياً: shopify | woocommerce | generic"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0.0.0",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    try:
        with httpx.Client(timeout=15.0, follow_redirects=True, headers=headers) as client:
            res = client.get(url)
            res.raise_for_status()
            html = res.text.lower()
            
            if "shopify.com" in html or "shopify-section" in html or "shopify.theme" in html or "cdn.shopify.com" in html:
                logger.info(f"🛍️ Detected: Shopify")
                return "shopify"
            
            if "woocommerce" in html or "wp-content/plugins/woocommerce" in html or "woocommerce_params" in html:
                logger.info(f"🛒 Detected: WooCommerce")
                return "woocommerce"
            
            logger.info(f"🌐 Detected: Generic (HTML)")
            return "generic"
            
    except Exception as e:
        logger.warning(f"⚠️ Platform detection failed: {e}, defaulting to generic")
        return "generic"
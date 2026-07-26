import logging
from typing import List, Dict, Any
from supabase import Client

logger = logging.getLogger(__name__)

class DeltaAnalyzer:
    def __init__(self, supabase_client: Client):
        self.supabase = supabase_client

    def get_delta(self, competitor_id: str, scraped_products: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Fetches existing products for the given competitor and compares them
        with newly scraped data. Returns only the 'Delta' (new products, price changes, title changes).
        """
        logger.info(f"Fetching existing products for competitor_id: {competitor_id}")
        
        # Fetch existing products for this competitor
        try:
            response = self.supabase.table("products").select("product_url, current_price, title").eq("competitor_id", competitor_id).execute()
            existing_records = response.data
        except Exception as e:
            logger.error(f"Error fetching existing products from Supabase: {e}")
            existing_records = []

        # Create a lookup dictionary by product_url
        existing_lookup = {
            record["product_url"]: record for record in existing_records
        }

        delta_products = []

        for scraped_product in scraped_products:
            url = scraped_product["product_url"]
            existing = existing_lookup.get(url)

            is_delta = False

            if not existing:
                # Completely new product
                is_delta = True
            else:
                # Check for significant changes
                price_changed = float(existing.get("current_price") or 0.0) != float(scraped_product.get("current_price") or 0.0)
                title_changed = existing.get("title") != scraped_product.get("title")

                if price_changed or title_changed:
                    is_delta = True

            if is_delta:
                # Inject competitor_id into the dictionary so it's ready for insertion
                product_to_insert = scraped_product.copy()
                
                # We will only insert columns that exist in the table. sku is not in products table schema.
                if "sku" in product_to_insert:
                    del product_to_insert["sku"]
                    
                product_to_insert["competitor_id"] = competitor_id
                delta_products.append(product_to_insert)

        logger.info(f"Delta Analysis Complete: {len(delta_products)} products have changed or are new.")
        return delta_products
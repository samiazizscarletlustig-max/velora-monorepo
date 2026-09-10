"""
📊 Trend Analyzer — Price Trend Analysis Engine
═══════════════════════════════════════════════════════════════
Analyzes historical price data to identify trends, patterns,
and optimal pricing opportunities.
"""

from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger('TrendAnalyzer')


class TrendAnalyzer:
    """Analyzes price trends and identifies patterns"""
    
    def __init__(self, competitor_id: str, products: List[Dict[str, Any]]):
        self.competitor_id = competitor_id
        self.products = products
        self.logger = logging.getLogger('TrendAnalyzer')
    
    def analyze_price_trends(self) -> Dict[str, Any]:
        """
        Analyze price trends across all products
        Returns comprehensive trend analysis
        """
        if not self.products:
            return {"error": "No products to analyze"}
        
        # Calculate trend metrics
        price_changes = []
        trending_up = 0
        trending_down = 0
        stable = 0
        
        for product in self.products:
            current_price = product.get('current_price', 0)
            previous_price = product.get('previous_price', current_price)
            
            if previous_price and current_price:
                change_percent = ((current_price - previous_price) / previous_price) * 100
                price_changes.append({
                    'product_id': product.get('id'),
                    'product_name': product.get('title'),
                    'current_price': current_price,
                    'previous_price': previous_price,
                    'change_percent': round(change_percent, 2),
                    'change_amount': round(current_price - previous_price, 2)
                })
                
                if change_percent > 2:
                    trending_up += 1
                elif change_percent < -2:
                    trending_down += 1
                else:
                    stable += 1
        
        total_products = len([p for p in self.products if p.get('current_price')])
        
        return {
            "competitor_id": self.competitor_id,
            "analysis_date": datetime.now().isoformat(),
            "total_products_analyzed": total_products,
            "trend_summary": {
                "trending_up": trending_up,
                "trending_down": trending_down,
                "stable": stable,
                "up_percentage": round((trending_up / total_products * 100) if total_products > 0 else 0, 1),
                "down_percentage": round((trending_down / total_products * 100) if total_products > 0 else 0, 1),
            },
            "price_changes": sorted(price_changes, key=lambda x: abs(x['change_percent']), reverse=True)[:20],
            "insights": self._generate_trend_insights(trending_up, trending_down, stable, total_products, price_changes)
        }
    
    def _generate_trend_insights(self, up: int, down: int, stable: int, total: int, changes: List) -> List[Dict]:
        """Generate strategic insights from trend data"""
        insights = []
        
        if total == 0:
            return insights
        
        # Insight 1: Overall trend direction
        if up > down * 1.5:
            insights.append({
                "type": "trend_direction",
                "severity": "medium",
                "title": "Competitor Increasing Prices",
                "summary": f"{up} out of {total} products ({round(up/total*100, 1)}%) showing price increases",
                "recommendation": "Consider maintaining current prices to gain market share while competitor raises prices",
                "opportunity": "high"
            })
        elif down > up * 1.5:
            insights.append({
                "type": "trend_direction",
                "severity": "high",
                "title": "Competitor Decreasing Prices",
                "summary": f"{down} out of {total} products ({round(down/total*100, 1)}%) showing price decreases",
                "recommendation": "Review pricing strategy - competitor may be clearing inventory or gaining market share",
                "opportunity": "medium"
            })
        
        # Insight 2: Significant price changes
        significant_changes = [c for c in changes if abs(c['change_percent']) > 15]
        if significant_changes:
            insights.append({
                "type": "significant_changes",
                "severity": "high",
                "title": f"{len(significant_changes)} Products with Major Price Changes",
                "summary": f"Products with price changes exceeding 15%",
                "affected_products": [c['product_name'] for c in significant_changes[:5]],
                "recommendation": "Investigate these products - may indicate strategy shift or inventory clearance",
                "opportunity": "high"
            })
        
        # Insight 3: Price stability
        if stable > total * 0.8:
            insights.append({
                "type": "stability",
                "severity": "low",
                "title": "Stable Pricing Strategy Detected",
                "summary": f"{stable} out of {total} products ({round(stable/total*100, 1)}%) have stable prices",
                "recommendation": "Market appears stable - focus on product differentiation rather than price competition",
                "opportunity": "low"
            })
        
        return insights
    
    def identify_seasonal_patterns(self) -> Dict[str, Any]:
        """
        Identify seasonal pricing patterns
        Requires historical data with timestamps
        """
        # This would require historical price data with dates
        # For now, return placeholder
        return {
            "competitor_id": self.competitor_id,
            "pattern_detected": False,
            "message": "Requires 3+ months of historical data for seasonal analysis",
            "recommendation": "Continue monitoring to identify seasonal patterns"
        }
    
    def calculate_price_velocity(self) -> Dict[str, Any]:
        """
        Calculate how quickly prices are changing
        """
        if not self.products:
            return {"error": "No products to analyze"}
        
        rapid_changes = 0
        moderate_changes = 0
        slow_changes = 0
        
        for product in self.products:
            change_freq = product.get('price_change_frequency', 0)
            
            if change_freq >= 4:  # Changed 4+ times
                rapid_changes += 1
            elif change_freq >= 2:
                moderate_changes += 1
            elif change_freq >= 1:
                slow_changes += 1
        
        total = len(self.products)
        
        return {
            "competitor_id": self.competitor_id,
            "velocity_analysis": {
                "rapid_changes": rapid_changes,
                "moderate_changes": moderate_changes,
                "slow_changes": slow_changes,
                "no_changes": total - (rapid_changes + moderate_changes + slow_changes)
            },
            "insight": "High frequency of price changes indicates dynamic pricing strategy" if rapid_changes > total * 0.2 else "Competitor uses stable pricing strategy"
        }
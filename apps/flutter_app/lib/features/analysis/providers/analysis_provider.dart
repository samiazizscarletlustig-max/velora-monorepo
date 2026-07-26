import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_insight.dart';
import '../models/price_delta.dart';
import '../models/competitor_metric.dart';

// 1. AI Insights Provider
final aiInsightsProvider = FutureProvider<List<AiInsight>>((ref) async {
  // Simulate network delay
  await Future.delayed(const Duration(milliseconds: 1200));
  
  return [
    AiInsight(
      id: 'insight_1',
      workspaceId: 'ws_1',
      title: 'Noon.com Price Drop Detection / رصد انخفاض أسعار نون',
      summary: 'Noon has aggressively dropped prices on electronics by 12% ahead of White Friday. / قامت نون بتخفيض أسعار الإلكترونيات بنسبة 12٪ قبل الجمعة البيضاء.',
      aiRecommendation: 'Match prices on top 20 SKUs and launch a bundle offer to retain market share. / قم بمطابقة الأسعار لأهم 20 منتج وأطلق عروض ترويجية للحفاظ على حصتك السوقية.',
      type: 'threat',
      severity: 'high',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      confidenceScore: 0.94,
      sources: ['noon_tracker_bot', 'market_api_v2'],
    ),
    AiInsight(
      id: 'insight_2',
      workspaceId: 'ws_1',
      title: 'Amazon SA Stock Shortage / نقص مخزون أمازون السعودية',
      summary: 'Amazon SA is currently out of stock on key smart home devices. / أمازون السعودية تعاني من نقص في مخزون الأجهزة الذكية الرئيسية.',
      aiRecommendation: 'Increase ad spend on smart home keywords while competitor is out of stock. / زيادة الإنفاق الإعلاني على الكلمات المفتاحية للأجهزة الذكية.',
      type: 'opportunity',
      severity: 'medium',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      confidenceScore: 0.88,
      sources: ['amazon_inventory_scraper'],
    ),
    AiInsight(
      id: 'insight_3',
      workspaceId: 'ws_1',
      title: 'Jarir Shipping Policy Change / تغيير سياسة الشحن لجرير',
      summary: 'Jarir Bookstore increased free shipping threshold to 250 SAR. / رفعت مكتبة جرير الحد الأدنى للشحن المجاني إلى 250 ريال سعودي.',
      aiRecommendation: 'Promote our 100 SAR free shipping threshold in targeted campaigns. / روّج للحد الأدنى للشحن المجاني الخاص بنا (100 ريال) في حملات موجهة.',
      type: 'trend',
      severity: 'low',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      confidenceScore: 0.98,
      sources: ['competitor_policy_monitor'],
    ),
  ];
});

// 2. Price Deltas Provider
final priceDeltasProvider = FutureProvider<List<PriceDelta>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 800));
  
  return [
    PriceDelta(
      id: 'pd_1',
      competitorName: 'Noon',
      productName: 'iPhone 15 Pro Max 256GB',
      oldPrice: 4799,
      newPrice: 4599,
      deltaPercentage: 4.16,
      lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      sourceUrl: 'https://noon.com/sa-en/iphone15',
      isIncrease: false,
    ),
    PriceDelta(
      id: 'pd_2',
      competitorName: 'Amazon SA',
      productName: 'Sony WH-1000XM5',
      oldPrice: 1299,
      newPrice: 1450,
      deltaPercentage: 11.6,
      lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      sourceUrl: 'https://amazon.sa/dp/B09XS7JWHH',
      isIncrease: true,
    ),
    PriceDelta(
      id: 'pd_3',
      competitorName: 'Jarir',
      productName: 'MacBook Air M3',
      oldPrice: 5299,
      newPrice: 4999,
      deltaPercentage: 5.66,
      lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      sourceUrl: 'https://jarir.com/sa-en/macbook-air-m3',
      isIncrease: false,
    ),
    PriceDelta(
      id: 'pd_4',
      competitorName: 'Extra',
      productName: 'Samsung S24 Ultra',
      oldPrice: 5399,
      newPrice: 5399,
      deltaPercentage: 0.0,
      lastUpdatedAt: DateTime.now().subtract(const Duration(days: 1)),
      sourceUrl: 'https://extra.com/en-sa/samsung-s24',
      isIncrease: false,
    ),
  ];
});

// 3. Competitor Metrics Provider
final competitorMetricsProvider = FutureProvider<List<CompetitorMetric>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 1000));
  
  final now = DateTime.now();
  return [
    CompetitorMetric(
      id: 'comp_1',
      name: 'Noon.com',
      healthScore: 85.4,
      marketShare: 32.5,
      pricingTrend: 'decreasing',
      threatLevel: 'high',
      historicalMarketShare: [
        DataPoint(now.subtract(const Duration(days: 90)), 28.0),
        DataPoint(now.subtract(const Duration(days: 60)), 30.5),
        DataPoint(now.subtract(const Duration(days: 30)), 31.2),
        DataPoint(now, 32.5),
      ],
    ),
    CompetitorMetric(
      id: 'comp_2',
      name: 'Amazon SA',
      healthScore: 92.1,
      marketShare: 45.0,
      pricingTrend: 'stable',
      threatLevel: 'high',
      historicalMarketShare: [
        DataPoint(now.subtract(const Duration(days: 90)), 46.5),
        DataPoint(now.subtract(const Duration(days: 60)), 45.8),
        DataPoint(now.subtract(const Duration(days: 30)), 45.2),
        DataPoint(now, 45.0),
      ],
    ),
    CompetitorMetric(
      id: 'comp_3',
      name: 'Jarir',
      healthScore: 78.0,
      marketShare: 12.4,
      pricingTrend: 'increasing',
      threatLevel: 'medium',
      historicalMarketShare: [
        DataPoint(now.subtract(const Duration(days: 90)), 11.0),
        DataPoint(now.subtract(const Duration(days: 60)), 11.5),
        DataPoint(now.subtract(const Duration(days: 30)), 12.0),
        DataPoint(now, 12.4),
      ],
    ),
  ];
});

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/tier_repository.dart';
import '../presentation/providers/tier_providers.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text('Plans & Pricing / الخطط والأسعار'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF222938)),
        ),
      ),
      body: FutureBuilder<String>(
        future: TierRepository.getCurrentUserTier(),
        builder: (context, snapshot) {
          final currentTier = snapshot.data ?? 'free';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                const Text(
                  'Unlock Your Competitive Edge\nافتح آفاقك التنافسية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your current plan: ${currentTier.toUpperCase()}\nخططتك الحالية',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white54),
                ),
                const SizedBox(height: 64),
                
                // ═══ 4 بطاقات الخطط ═══
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _PricingCard(
                        title: 'Free',
                        titleAr: 'مجاني',
                        price: '\$0',
                        subtitle: 'Perfect to start',
                        features: const [
                          '3 Competitors',
                          'Scan every 24 hours',
                          '6 Strategic Insights / scan',
                          'Executive Summary',
                          'Community Support',
                        ],
                        buttonText: currentTier == 'free' ? 'Current Plan' : 'Downgrade',
                        isPopular: false,
                        isCurrent: currentTier == 'free',
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -12),
                        child: _PricingCard(
                          title: 'Pro',
                          titleAr: 'احترافي',
                          price: '\$29',
                          period: '/mo',
                          subtitle: 'For growing brands',
                          features: const [
                            '10 Competitors',
                            'Scan every 6 hours',
                            '12 Executive Insights / scan',
                            'Competitive Scorecard',
                            'Quick Wins & Risk Alerts',
                            'Priority Email Support',
                          ],
                          buttonText: currentTier == 'pro' ? 'Current Plan' : 'Upgrade to Pro',
                          isPopular: true,
                          isCurrent: currentTier == 'pro',
                          checkoutUrl: 'https://yourstore.lemonsqueezy.com/checkout/buy/pro-id',
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _PricingCard(
                        title: 'Pro Plus',
                        titleAr: 'متقدم',
                        price: '\$79',
                        period: '/mo',
                        subtitle: 'For serious teams',
                        features: const [
                          '25 Competitors',
                          'Scan every 3 hours',
                          'Price History Tracking',
                          'Trend Comparison (30/90 days)',
                          'PDF Report Export',
                          'Email Alerts (Critical changes)',
                        ],
                        buttonText: currentTier == 'pro_plus' ? 'Current Plan' : 'Upgrade',
                        isPopular: false,
                        isCurrent: currentTier == 'pro_plus',
                        checkoutUrl: 'https://yourstore.lemonsqueezy.com/checkout/buy/proplus-id',
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _PricingCard(
                        title: 'Enterprise',
                        titleAr: 'مؤسسي',
                        price: '\$199',
                        period: '/mo',
                        subtitle: 'For agencies & corps',
                        features: const [
                          'Unlimited Competitors',
                          'Scan every 1 hour',
                          'API Access',
                          'White-label Reports',
                          'Custom AI Models',
                          'Dedicated Account Manager',
                        ],
                        buttonText: 'Contact Sales',
                        isPopular: false,
                        isCurrent: currentTier == 'enterprise',
                        isContact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 64),
                _buildComparisonTable(context, currentTier),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context, String currentTier) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222938)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF222938))),
            ),
            child: const Text(
              'Feature Comparison / مقارنة الميزات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
              dataTextStyle: const TextStyle(color: Colors.white70),
              columns: const [
                DataColumn(label: Text('Feature')),
                DataColumn(label: Text('Free')),
                DataColumn(label: Text('Pro')),
                DataColumn(label: Text('Pro Plus')),
                DataColumn(label: Text('Enterprise')),
              ],
              rows: [
                _buildTableRow('Competitors', '3', '10', '25', '∞'),
                _buildTableRow('Scan Frequency', '24h', '6h', '3h', '1h'),
                _buildTableRow('Strategic Insights', '6', '12', '12 + Trends', 'Custom'),
                _buildTableRow('Executive Summary', '✅', '✅', '✅', '✅'),
                _buildTableRow('Scorecard & Quick Wins', '❌', '✅', '✅', '✅'),
                _buildTableRow('Price History', '❌', '❌', '✅', '✅'),
                _buildTableRow('PDF Export', '❌', '❌', '✅', '✅'),
                _buildTableRow('Email Alerts', '❌', '❌', '✅', '✅ + Slack'),
                _buildTableRow('API Access', '❌', '❌', '❌', '✅'),
                _buildTableRow('Support', 'Community', 'Email 48h', 'Priority 24h', 'Dedicated'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildTableRow(String feature, String free, String pro, String proPlus, String enterprise) {
    return DataRow(
      cells: [
        DataCell(Text(feature, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(free)),
        DataCell(Text(pro)),
        DataCell(Text(proPlus)),
        DataCell(Text(enterprise)),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String titleAr;
  final String price;
  final String? period;
  final String subtitle;
  final List<String> features;
  final String buttonText;
  final bool isPopular;
  final bool isCurrent;
  final bool isContact;
  final String? checkoutUrl;

  const _PricingCard({
    required this.title,
    required this.titleAr,
    required this.price,
    this.period,
    required this.subtitle,
    required this.features,
    required this.buttonText,
    required this.isPopular,
    required this.isCurrent,
    this.isContact = false,
    this.checkoutUrl,
  });

  Future<void> _handleClick(BuildContext context) async {
    if (isCurrent) return;
    if (isContact) {
      await launchUrl(Uri.parse('mailto:hello@velora.app?subject=Enterprise%20Inquiry'));
      return;
    }
    if (checkoutUrl != null) {
      await launchUrl(Uri.parse(checkoutUrl!), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout coming soon — activate Pro manually for demo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B26).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular
              ? primaryColor
              : isCurrent
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF222938),
          width: isPopular || isCurrent ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'MOST POPULAR',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                else if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'YOUR PLAN',
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 28),
                Text(
                  title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  titleAr,
                  style: const TextStyle(fontSize: 14, color: Colors.white38),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    if (period != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(period!, style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: isCurrent ? null : () => _handleClick(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? primaryColor
                        : isCurrent
                            ? const Color(0xFF222938)
                            : const Color(0xFF2A3142),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isCurrent ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Divider(color: Color(0xFF222938), height: 1),
                const SizedBox(height: 24),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, color: primaryColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text('Billing & Plans / الفوترة والخطط'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF222938)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Text(
              'Upgrade your strategic capability\nقم بترقية قدراتك الاستراتيجية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.3, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose the plan that fits your organization\'s scale.\nاختر الخطة التي تناسب حجم مؤسستك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white54),
            ),
            const SizedBox(height: 64),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: _PricingCard(
                    title: 'Free / مجاني',
                    price: '\$0',
                    subtitle: 'For individuals / للأفراد',
                    features: [
                      '1 Workspace',
                      'Basic AI Analysis',
                      'Community Support',
                      'Local Storage',
                    ],
                    buttonText: 'Current Plan',
                    isPopular: false,
                    checkoutUrl: 'https://lemonsqueezy.com',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: const _PricingCard(
                      title: 'Pro / احترافي',
                      price: '\$49',
                      period: '/mo',
                      subtitle: 'For strategic teams / للفرق الاستراتيجية',
                      features: [
                        'Unlimited Workspaces',
                        'Advanced AI & Forecasting',
                        'Priority Support',
                        'Cloud Sync & Backup',
                        'Custom Strategy Templates',
                      ],
                      buttonText: 'Upgrade to Pro',
                      isPopular: true,
                      checkoutUrl: 'https://lemonsqueezy.com',
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  child: _PricingCard(
                    title: 'Agency / وكالة',
                    price: '\$149',
                    period: '/mo',
                    subtitle: 'For large agencies / للوكالات الكبيرة',
                    features: [
                      'Everything in Pro',
                      'White-label Reports',
                      'Dedicated Account Manager',
                      'SSO & SAML',
                      'Custom Integrations',
                    ],
                    buttonText: 'Contact Sales',
                    isPopular: false,
                    checkoutUrl: 'https://lemonsqueezy.com',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),
            _buildComparisonTable(context),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white54),
            columns: const [
              DataColumn(label: Text('Feature')),
              DataColumn(label: Text('Free')),
              DataColumn(label: Text('Pro')),
              DataColumn(label: Text('Agency')),
            ],
            rows: [
              _buildTableRow('AI Queries / Month', '100', 'Unlimited', 'Unlimited'),
              _buildTableRow('Custom Templates', '❌', '✅', '✅'),
              _buildTableRow('Data Export (PDF/CSV)', '❌', '✅', '✅'),
              _buildTableRow('White-labeling', '❌', '❌', '✅'),
              _buildTableRow('Support', 'Community', 'Priority', 'Dedicated 24/7'),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _buildTableRow(String feature, String free, String pro, String agency) {
    return DataRow(
      cells: [
        DataCell(Text(feature, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(free)),
        DataCell(Text(pro)),
        DataCell(Text(agency)),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String? period;
  final String subtitle;
  final List<String> features;
  final String buttonText;
  final bool isPopular;
  final String checkoutUrl;

  const _PricingCard({
    required this.title,
    required this.price,
    this.period,
    required this.subtitle,
    required this.features,
    required this.buttonText,
    required this.isPopular,
    required this.checkoutUrl,
  });

  Future<void> _launchCheckout() async {
    final url = Uri.parse(checkoutUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
          color: isPopular ? primaryColor : const Color(0xFF222938),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                      'MOST POPULAR / الأكثر شيوعاً',
                      style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, height: 1.0)),
                    if (period != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(period!, style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _launchCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? primaryColor : const Color(0xFF222938),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 32),
                const Divider(color: Color(0xFF222938), height: 1),
                const SizedBox(height: 32),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 14))),
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

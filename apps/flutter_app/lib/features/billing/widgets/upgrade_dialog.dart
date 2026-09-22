import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpgradeDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String reason, // مثل: "You've reached the 3-competitor limit"
    String? targetTier, // 'pro' | 'pro_plus' | null (يعرض جميع الخطط)
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => _UpgradeDialogContent(reason: reason, targetTier: targetTier),
    );
  }
}

class _UpgradeDialogContent extends StatelessWidget {
  final String reason;
  final String? targetTier;

  const _UpgradeDialogContent({required this.reason, this.targetTier});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, color: primaryColor, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unlock More Power',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'افتح المزيد من القدرات',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF222938)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade300, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _PlanButton(
                        title: 'Pro',
                        price: '\$29/mo',
                        highlight: targetTier == 'pro' || targetTier == null,
                        onTap: () => _openCheckout(
                          context,
                          'https://yourstore.lemonsqueezy.com/checkout/buy/pro-id',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlanButton(
                        title: 'Pro Plus',
                        price: '\$79/mo',
                        highlight: targetTier == 'pro_plus',
                        onTap: () => _openCheckout(
                          context,
                          'https://yourstore.lemonsqueezy.com/checkout/buy/proplus-id',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Maybe later / لاحقاً',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCheckout(BuildContext context, String url) async {
    Navigator.of(context).pop(true);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _PlanButton extends StatelessWidget {
  final String title;
  final String price;
  final bool highlight;
  final VoidCallback onTap;

  const _PlanButton({
    required this.title,
    required this.price,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: highlight ? primaryColor : const Color(0xFF0A0E1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight ? primaryColor : const Color(0xFF222938),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: highlight ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                color: highlight ? Colors.white.withOpacity(0.8) : Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
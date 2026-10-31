import 'package:flutter/material.dart';

import '../widgets/studio/studio.dart';
import 'profile/widgets/profile_seller_insights.dart';

/// Seller analytics detail — opened from Settings when seller mode is on. "Your insights"
/// 22, a Graphite line, then the four counts on a Surface panel.
class SellerAnalyticsPage extends StatelessWidget {
  const SellerAnalyticsPage({
    super.key,
    this.savesCount,
    this.likesCount,
    this.inquiriesCount,
    this.salesCount,
  });

  final int? savesCount;
  final int? likesCount;
  final int? inquiriesCount;
  final int? salesCount;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Seller analytics'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 8, StudioSpace.marginPage, 40),
        children: [
          Text('Your insights', style: StudioType.title22(color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Track how your listings perform over time.',
            style: StudioType.body14(color: c.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(StudioRadius.panel),
            ),
            child: ProfileSellerInsights(
              savesCount: savesCount,
              likesCount: likesCount,
              inquiriesCount: inquiriesCount,
              salesCount: salesCount,
            ),
          ),
        ],
      ),
    );
  }
}

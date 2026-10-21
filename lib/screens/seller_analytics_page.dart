import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';
import '../widgets/studio/studio_top_bar.dart';
import 'profile/widgets/profile_seller_insights.dart';

/// Seller analytics detail — opened from Settings when seller mode is on.
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
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: StudioTopBar(context: context, title: 'Seller analytics'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Your insights',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track how your listings perform over time.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ProfileSellerInsights(
            savesCount: savesCount,
            likesCount: likesCount,
            inquiriesCount: inquiriesCount,
            salesCount: salesCount,
          ),
        ],
      ),
    );
  }
}

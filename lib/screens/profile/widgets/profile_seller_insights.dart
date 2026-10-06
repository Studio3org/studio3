import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_exception.dart';
import '../../../services/user_service.dart';
import '../../../theme/home_feed_tokens.dart';

/// Enables/disables seller mode without interrupting the profile flow.
Future<bool?> toggleSellerMode({
  required BuildContext context,
  required bool enable,
  String? profileLocation,
}) async {
  if (!enable) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to artist profile?'),
        content: const Text('Listed pieces will be delisted automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    try {
      await UserService.instance.disableSeller();
      return false;
    } catch (e) {
      if (context.mounted) _showError(context, e);
      return null;
    }
  }

  try {
    await UserService.instance.enableSeller(
      location: profileLocation?.trim() ?? '',
      useProfileLocation: true,
    );
    return true;
  } catch (e) {
    if (!context.mounted) return null;
    final message = e is ApiException ? e.message : e.toString();
    if (message.toLowerCase().contains('location')) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Add a location in Edit profile first, then switch to seller mode.',
            ),
          ),
        );
    } else {
      _showError(context, e);
    }
    return null;
  }
}

void _showError(BuildContext context, Object e) {
  final message = e is ApiException ? e.message : e.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Seller insights row — Figma 1070-709 (Saves, Likes, Inquiries, Sales).
class ProfileSellerInsights extends StatelessWidget {
  const ProfileSellerInsights({
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

  String _fmt(int? v) => v == null ? '—' : '$v';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          _InsightCell(label: 'Saves', value: _fmt(savesCount)),
          _InsightCell(label: 'Likes', value: _fmt(likesCount)),
          _InsightCell(label: 'Inquiries', value: _fmt(inquiriesCount)),
          _InsightCell(label: 'Sales', value: _fmt(salesCount)),
        ],
      ),
    );
  }
}

class _InsightCell extends StatelessWidget {
  const _InsightCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

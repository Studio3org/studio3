import 'package:flutter/material.dart';

import '../../../services/api_exception.dart';
import '../../../services/user_service.dart';
import '../../../widgets/studio/studio.dart';

/// Enables/disables seller mode without interrupting the profile flow.
Future<bool?> toggleSellerMode({
  required BuildContext context,
  required bool enable,
  String? profileLocation,
}) async {
  if (!enable) {
    final confirmed = await showStudioConfirm(
      context,
      title: 'Switch to artist profile?',
      message: 'Listed pieces will be delisted automatically.',
      confirmLabel: 'Switch',
    );
    if (!confirmed) return null;
    try {
      await UserService.instance.disableSeller();
      return false;
    } catch (e) {
      if (context.mounted) _showError(context, e);
      return null;
    }
  }

  // Selling needs a real place on the profile (the server takes an empty one without
  // complaint), chosen from search in Edit profile.
  if ((profileLocation?.trim() ?? '').isEmpty) {
    if (context.mounted) {
      showStudioToast(context, 'Add your city in Edit profile first, then switch to seller mode.', icon: null);
    }
    return null;
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
      showStudioToast(
        context,
        'Add a location in Edit profile first, then switch to seller mode.',
        icon: null,
      );
    } else {
      _showError(context, e);
    }
    return null;
  }
}

void _showError(BuildContext context, Object e) {
  showStudioToast(context, e is ApiException ? e.message : 'Something went wrong. Try again.', icon: null);
}

/// Seller insights (Saves, Likes, Inquiries, Sales): four equal cells, the count in Mono 20
/// Ink over the label 12 Graphite; "—" while a count is unknown.
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
    return Row(
      children: [
        _InsightCell(label: 'Saves', value: _fmt(savesCount)),
        _InsightCell(label: 'Likes', value: _fmt(likesCount)),
        _InsightCell(label: 'Inquiries', value: _fmt(inquiriesCount)),
        _InsightCell(label: 'Sales', value: _fmt(salesCount)),
      ],
    );
  }
}

class _InsightCell extends StatelessWidget {
  const _InsightCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(value, style: StudioType.mono(20, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: StudioType.caption12(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

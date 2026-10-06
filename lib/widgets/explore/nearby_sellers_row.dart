import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/nearby_seller.dart';
import '../../services/nearby_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/profile_navigation.dart';
import '../home_feed/home_feed_widgets.dart';

/// Horizontal row of sellers near the viewer's current location.
class NearbySellersRow extends StatefulWidget {
  const NearbySellersRow({super.key});

  @override
  State<NearbySellersRow> createState() => _NearbySellersRowState();
}

class _NearbySellersRowState extends State<NearbySellersRow> {
  List<NearbySeller> _sellers = [];
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final sellers = await NearbyService.instance.getNearbySellers(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _sellers = sellers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    if (_permissionDenied) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: GestureDetector(
          onTap: _load,
          child: Text(
            'Enable location to discover nearby sellers',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ),
      );
    }

    if (_sellers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Sellers near you',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sellers.length,
              separatorBuilder: (context, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final seller = _sellers[index];
                return GestureDetector(
                  onTap: () => openUserProfile(context, seller.username),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        UserAvatar(
                          url: seller.profilePhotoUrl,
                          name: seller.displayName,
                          size: 56,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          seller.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: HomeFeedTokens.textPrimary,
                          ),
                        ),
                        Text(
                          seller.distanceDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

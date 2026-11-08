import 'package:flutter/material.dart';

import '../../widgets/studio/studio.dart';
import 'models/profile_series_data.dart';
import 'profile_constants.dart';
import 'widgets/profile_series_grid.dart';

/// Every series on a profile, from See all on the Series shelf at the top of the Pieces tab.
/// The boards have no Series tab (`HandoffProfiles`: tabs are Pieces, Scenes, Collection; the
/// shelf lives in Pieces) and draw no page for See all, so it is a top bar over the shelf's
/// cards in two columns (16 apart, 22 between rows). Tapping a series opens it.
class ProfileAllSeriesPage extends StatelessWidget {
  const ProfileAllSeriesPage({super.key, required this.series, required this.onSeriesTap});

  final List<ProfileSeriesData> series;
  final void Function(ProfileSeriesData series) onSeriesTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.studio.background,
      appBar: StudioTopBar(context: context, title: 'Series'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxWidth - kProfileHorizontalPad * 2 - StudioSpace.s16) / 2;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              kProfileHorizontalPad,
              kProfileGridTopGap,
              kProfileHorizontalPad,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Wrap(
              spacing: StudioSpace.s16,
              runSpacing: 22,
              children: [
                for (final item in series)
                  ProfileSeriesCard(data: item, size: size, onTap: () => onSeriesTap(item)),
              ],
            ),
          );
        },
      ),
    );
  }
}

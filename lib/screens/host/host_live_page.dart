import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_link_config.dart';
import '../../models/studio_event.dart';
import '../../widgets/post_crop_preview.dart';
import '../../widgets/studio/studio.dart';
import 'host_flyer_page.dart';
import 'host_manage_page.dart';

/// Your event is live (`HostLive`), styled like the collect confirmation: Close; the cover
/// (204 × 272, radius 10) in a slowly shifting iridescent frame (6, radius 16, a soft shadow);
/// "Your event is live" 28/500 with a 15 Graphite line; an Event details card with a 1.5 px
/// iridescent edge (When and Link in Mono); Share event and Manage event. Everything fades up
/// in turn; with reduced motion it shows at once and the shimmer stops.
class HostLivePage extends StatefulWidget {
  const HostLivePage({
    super.key,
    required this.event,
    required this.whenLabel,
    required this.ticketsLabel,
    this.flyer,
  });

  final StudioEvent event;
  final String whenLabel;
  final String ticketsLabel;

  /// The flyer as framed, while the uploaded copy may still be on its way to the CDN.
  final HostFlyer? flyer;

  @override
  State<HostLivePage> createState() => _HostLivePageState();
}

class _HostLivePageState extends State<HostLivePage> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else if (_motion.value == 0 && !_motion.isAnimating) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Widget _up(Widget child, int delayMs) {
    final t = CurvedAnimation(
      parent: _motion,
      curve: Interval(delayMs / 950, (delayMs + 500) / 950, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t.value)), child: child),
      ),
    );
  }

  String get _link => AppLinkConfig.eventUrl(widget.event.id);

  Future<void> _share() async {
    final e = widget.event;
    await SharePlus.instance.share(ShareParams(text: '${e.title}\n${widget.whenLabel}\n$_link'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final e = widget.event;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final flyer = widget.flyer;
    final Widget cover = flyer != null
        ? PostCropPreview(
            imagePath: flyer.path,
            transform: flyer.transform,
            borderRadius: BorderRadius.circular(StudioRadius.card),
            frameSize: const Size(204, 272),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(StudioRadius.card),
            child: SizedBox(
              width: 204,
              height: 272,
              child: e.imageUrl.isEmpty
                  ? ColoredBox(color: c.surface)
                  : CachedNetworkImage(imageUrl: e.imageUrl, fit: BoxFit.cover),
            ),
          );
    Widget row(String label, String value, {bool mono = false, bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.textPrimary.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Text(label, style: StudioType.label13(color: c.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono ? StudioType.mono(13, color: c.textPrimary) : StudioType.label13(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Close',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox.square(
                        dimension: 44,
                        child: Center(child: StudioIcon(StudioIcons.close, size: 22, color: c.textPrimary)),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginForm),
                  child: Column(
                    children: [
                      _up(
                        StudioIridescent(
                          padding: const EdgeInsets.all(6),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x1F111111), blurRadius: 40, offset: Offset(0, 20))],
                          child: cover,
                        ),
                        0,
                      ),
                      const SizedBox(height: 22),
                      _up(
                        Column(
                          children: [
                            Text(
                              'Your event is live',
                              textAlign: TextAlign.center,
                              style: StudioType.sans(28, weight: StudioType.medium, letterSpacing: -0.5, color: c.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${e.title} is showing in Events now.',
                              textAlign: TextAlign.center,
                              style: StudioType.body15(color: c.textSecondary),
                            ),
                          ],
                        ),
                        150,
                      ),
                      const SizedBox(height: 22),
                      _up(
                        StudioIridescent(
                          padding: const EdgeInsets.all(1.5),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            decoration: BoxDecoration(
                              color: c.background.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      StudioIridescent(
                                        borderRadius: BorderRadius.circular(4),
                                        child: const SizedBox.square(dimension: 8),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Event details',
                                        style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                                row('When', widget.whenLabel, mono: true),
                                if (e.venue.isNotEmpty) row('Where', e.venue),
                                row('Tickets', widget.ticketsLabel),
                                row('Link', _link.replaceFirst(RegExp(r'^https?://'), ''), mono: true, last: true),
                              ],
                            ),
                          ),
                        ),
                        300,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _up(
                Padding(
                  padding: EdgeInsets.fromLTRB(StudioSpace.marginForm, 8, StudioSpace.marginForm, safe > 0 ? safe : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StudioButton(label: 'Share event', onPressed: _share),
                      const SizedBox(height: 4),
                      StudioButton(
                        label: 'Manage event',
                        variant: StudioButtonVariant.text,
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => HostManagePage(event: e)),
                        ),
                      ),
                    ],
                  ),
                ),
                450,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

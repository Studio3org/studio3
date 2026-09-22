import 'package:flutter/widgets.dart';

/// What a section should be showing right now.
enum SectionPhase {
  /// Nothing cached, nothing loaded, a request is in flight — the only
  /// case where a skeleton is allowed.
  skeleton,

  /// The request finished (or failed) and there is genuinely nothing.
  empty,

  /// There is data. Render it — even if a refresh is still in flight.
  content,
}

/// Resolves the one decision every backend-backed section has to make.
///
/// The ordering is the whole point: [hasData] is checked *before*
/// [loading], so previously-loaded or cache-seeded content is never
/// replaced by a placeholder while it silently refreshes.
SectionPhase sectionPhase({required bool hasData, required bool loading}) {
  if (hasData) return SectionPhase.content;
  if (loading) return SectionPhase.skeleton;
  return SectionPhase.empty;
}

/// Renders one independently-fetched section under the app's loading rule
/// (see `skeleton_primitives.dart`).
///
/// * [hasData] true  → [content], always, refresh or not.
/// * otherwise loading → [skeleton].
/// * otherwise        → [empty] (falling back to [content] when no empty
///   state is supplied, e.g. lists that render their own zero-state).
///
/// Anything static around the section — headings, tabs, filters, actions —
/// belongs *outside* this widget so it paints on the first frame.
class SectionLoader extends StatelessWidget {
  const SectionLoader({
    super.key,
    required this.hasData,
    required this.loading,
    required this.skeleton,
    required this.content,
    this.empty,
  });

  /// Whether there is anything at all to render — cached, stale or fresh.
  final bool hasData;

  /// Whether a backend request for this section is currently in flight.
  final bool loading;

  /// Placeholder shaped like the real content. Only ever shown when
  /// [hasData] is false.
  final WidgetBuilder skeleton;

  /// The real content.
  final WidgetBuilder content;

  /// Zero-state for "loaded, but there is nothing".
  final WidgetBuilder? empty;

  @override
  Widget build(BuildContext context) {
    switch (sectionPhase(hasData: hasData, loading: loading)) {
      case SectionPhase.content:
        return content(context);
      case SectionPhase.skeleton:
        return skeleton(context);
      case SectionPhase.empty:
        return (empty ?? content)(context);
    }
  }
}

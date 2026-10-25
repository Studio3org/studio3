import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../widgets/studio/studio.dart';
import '../widgets/studio_loading.dart';

/// One switch on the settings page and the server push types it turns on and off.
///
/// The server checks `push[type]` for each notification it sends (missing means on) and
/// merges any keys it is given, so a switch writes every type in its group.
class NotificationSwitch {
  const NotificationSwitch(this.title, this.subtitle, this.types);

  final String title;
  final String subtitle;
  final List<String> types;
}

/// A Mono label and its switches. [yourWork] sections only show for people who have posted.
class NotificationSection {
  const NotificationSection(this.label, this.switches, {this.yourWork = false});

  final String label;
  final List<NotificationSwitch> switches;
  final bool yourWork;
}

/// The board's sections, for the notifications the server sends today. Saved pieces,
/// Artists you follow, the daily summary choice and Text messages wait on the server
/// (BACKEND_CHANGES B7, B12, B13).
const notificationSections = [
  NotificationSection('Collecting', [
    NotificationSwitch('Auctions', 'Outbid, ending soon, won, lost, payment reminders.', [
      'outbid',
      'auction_extended',
      'auction_won',
      'auction_lost',
      'auction_payment_failed',
      'auction_cancelled',
      'bid_hold_expired',
    ]),
    NotificationSwitch('Orders and shipping', 'Receipts and delivery updates.', ['purchase']),
  ]),
  NotificationSection('Following', [
    NotificationSwitch('Events', 'Reminders for events you have tickets to.', [
      'event_cancelled',
    ]),
  ]),
  NotificationSection('Your work', yourWork: true, [
    NotificationSwitch('Bids and sales', 'New bids, sold, paid, auctions ended.', [
      'bid_placed',
      'auction_sold',
      'auction_no_sale',
      'auction_winner_payment_failed',
    ]),
    NotificationSwitch('Saves and follows', 'People saving your pieces or following you.', [
      'save',
      'follow',
      'follow_request',
      'like',
      'comment',
    ]),
  ]),
  NotificationSection('Messages', [
    NotificationSwitch('New messages', 'From artists and collectors.', ['message', 'inquiry']),
  ]),
];

/// Notification settings (`NotifSettings`): Profile, Settings, Notifications.
///
/// Back and "Notifications"; a grey card with the phone's permission state and Open (the
/// phone's settings); then Mono section labels over switch rows (15/500 title, 12 Graphite
/// line). "Your work" only shows for people who have posted.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({
    super.key,
    this.debugPrefs,
    this.debugHasPosted,
    this.debugPushAllowed,
  });

  /// For tests: settings, whether the person has posted, and the phone permission,
  /// instead of loading them.
  @visibleForTesting
  final NotificationPreferences? debugPrefs;
  @visibleForTesting
  final bool? debugHasPosted;
  @visibleForTesting
  final bool? debugPushAllowed;

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage>
    with WidgetsBindingObserver {
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _hasPosted = false;
  bool? _pushAllowed;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefs = widget.debugPrefs;
    if (prefs != null) {
      _prefs = prefs;
      _hasPosted = widget.debugHasPosted ?? true;
      _pushAllowed = widget.debugPushAllowed;
      _loading = false;
      return;
    }
    _load();
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.debugPrefs == null) _checkPermission();
  }

  Future<void> _load() async {
    try {
      final profile = await UserService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _prefs = profile.notificationPreferences ?? const NotificationPreferences();
        _hasPosted = profile.piecesCount > 0 || profile.sellerEnabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _checkPermission() async {
    try {
      final allowed = await PermissionService.instance.notificationsAllowed();
      if (mounted) setState(() => _pushAllowed = allowed);
    } catch (_) {}
  }

  bool _isOn(NotificationSwitch s) => s.types.every((t) => _prefs.push[t] ?? true);

  Future<void> _toggle(NotificationSwitch s, bool value) async {
    final change = {for (final t in s.types) t: value};
    final before = {for (final t in s.types) t: _prefs.push[t]};
    setState(() => _prefs = _prefs.copyWith(push: {..._prefs.push, ...change}));
    try {
      await UserService.instance.updateNotificationPreferences(push: change);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final push = {..._prefs.push};
        before.forEach((t, v) => v == null ? push.remove(t) : push[t] = v);
        _prefs = _prefs.copyWith(push: push);
      });
      showStudioToast(context, 'Could not save. Try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final allowed = _pushAllowed;
    return StudioLoadingGate(
      loading: _loading,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(context: context, title: 'Notifications'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (allowed != null)
              _PushCard(
                allowed: allowed,
                onOpen: () => PermissionService.instance.openSettings(),
              ),
            for (final section in notificationSections)
              if (!section.yourWork || _hasPosted) ...[
                _SectionLabel(section.label),
                for (final s in section.switches)
                  _SwitchRow(item: s, value: _isOn(s), onChanged: (v) => _toggle(s, v)),
              ],
          ],
        ),
      ),
    );
  }
}

/// Surface card, radius 12, 14 16 padding: the permission state and Open.
class _PushCard extends StatelessWidget {
  const _PushCard({required this.allowed, required this.onOpen});

  final bool allowed;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final phone = Theme.of(context).platform == TargetPlatform.iOS ? 'iPhone' : 'phone';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StudioRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allowed ? 'Push notifications are on' : 'Push notifications are off',
                  style: StudioType.sans(14, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  allowed
                      ? 'Change this in your $phone settings.'
                      : 'Turn them on in your $phone settings.',
                  style: StudioType.caption12(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Open',
                  style: StudioType.sans(13, weight: StudioType.medium, color: c.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mono 11/500 Tertiary caps, 18 above and 2 below.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: StudioType.mono(
          11,
          weight: StudioType.medium,
          color: context.studio.textTertiary,
        ).copyWith(letterSpacing: 0.5),
      ),
    );
  }
}

/// 15/500 title over a 12 / 1.45 Graphite line, the switch on the right; 14 above and
/// below, 1 px Line under.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.item, required this.value, required this.onChanged});

  final NotificationSwitch item;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: StudioType.caption12(height: 1.45, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          StudioSwitch(value: value, onChanged: onChanged, semanticLabel: item.title),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/loading/section_loader.dart';
import '../widgets/settings_tile.dart';
import '../theme/app_fonts.dart';

const _pushLabels = {
  'follow': ('Follows', Icons.person_add_alt_outlined),
  'like': ('Likes', Icons.favorite_border),
  'save': ('Saves', Icons.bookmark_border),
  'comment': ('Comments', Icons.chat_bubble_outline),
  'inquiry': ('Inquiries', Icons.question_answer_outlined),
  'purchase': ('Purchases', Icons.shopping_bag_outlined),
};

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;

  /// Whether real preference values are on screen (cached or fetched) as
  /// opposed to the placeholder defaults.
  bool _hasPrefs = false;

  @override
  void initState() {
    super.initState();
    // Paint the real switch positions immediately when the profile is
    // already cached; the fetch below still runs and refreshes silently.
    final cached = UserService.instance.peekMeCached()?.notificationPreferences;
    if (cached != null) {
      _prefs = cached;
      _hasPrefs = true;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserService.instance.getMeCached(
        onBackgroundUpdate: (fresh) {
          if (!mounted) return;
          setState(() {
            _prefs =
                fresh.notificationPreferences ?? const NotificationPreferences();
            _hasPrefs = true;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _prefs = profile.notificationPreferences ?? const NotificationPreferences();
        _hasPrefs = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePush(String key, bool value) async {
    final previous = _prefs;
    setState(() {
      _prefs = _prefs.copyWith(push: {..._prefs.push, key: value});
    });
    try {
      setState(() => _saving = true);
      final updated = await UserService.instance.updateNotificationPreferences(
        push: {key: value},
      );
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleDailyDigest(bool value) async {
    final previous = _prefs;
    setState(() => _prefs = _prefs.copyWith(dailyDigestEnabled: value));
    try {
      setState(() => _saving = true);
      final updated = await UserService.instance.updateNotificationPreferences(
        dailyDigestEnabled: value,
      );
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDigestTime() async {
    final parts = _prefs.dailyDigestTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      // Simple hour/minute entry instead of the round-clock dial, to match
      // the rest of the app's time inputs.
      initialEntryMode: TimePickerEntryMode.inputOnly,
      // TimePickerEntryMode.input(Only)'s dialog has a fixed minimum
      // content height that a larger system text-scale setting can push
      // past, throwing "BoxConstraints has non-normalized height
      // constraints" — clamping text scale here is Flutter's own
      // documented workaround (see event_date_sheet.dart's _pickTime).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
    if (picked == null) return;
    final time =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final previous = _prefs;
    setState(() => _prefs = _prefs.copyWith(dailyDigestTime: time));
    try {
      setState(() => _saving = true);
      final updated = await UserService.instance.updateNotificationPreferences(
        dailyDigestTime: time,
      );
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Chrome is static — it never waits on the network. Only the switch
    // positions are backend-dependent, so only they get a placeholder, and
    // only until there are real values (cached or fetched) to show.
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        title: Text(
          'Notification preferences',
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
      ),
      body: SectionLoader(
        hasData: _hasPrefs,
        loading: _loading,
        skeleton: (_) => const SettingsListSkeleton(),
        content: (_) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionLabel('Push notifications'),
            for (final entry in _pushLabels.entries)
              SettingsToggleTile(
                icon: entry.value.$2,
                label: entry.value.$1,
                value: _prefs.push[entry.key] ?? true,
                onChanged: _saving ? (_) {} : (v) => _togglePush(entry.key, v),
              ),
            const SizedBox(height: 20),
            _sectionLabel('Daily digest'),
            SettingsToggleTile(
              icon: Icons.mail_outline_rounded,
              label: 'Daily digest email',
              value: _prefs.dailyDigestEnabled,
              onChanged: _saving ? (_) {} : _toggleDailyDigest,
            ),
            if (_prefs.dailyDigestEnabled)
              SettingsTile(
                icon: Icons.schedule_outlined,
                label: 'Delivery time (${_prefs.dailyDigestTime})',
                onTap: _saving ? () {} : _pickDigestTime,
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
          ),
        ),
      );
}

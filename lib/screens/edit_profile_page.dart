import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/user_service.dart';
import '../widgets/studio/studio.dart';
import '../utils/profile_photo_upload.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/profile_edit_header.dart';
import '../widgets/settings_tile.dart' show SettingsSectionLabel;
import '../widgets/studio_loading.dart';
import 'profile_banner_picker_sheet.dart';

const _bannerRuleOptions = [
  ('most_saved', 'Most saved'),
  ('most_recent', 'Most recent'),
  ('none', 'None (manual pin)'),
];

/// Edit profile (`EditProfile`): Cancel / Edit profile / Save; the cover ("Change cover") and
/// the photo with its pencil badge; Name; Username with a grey @ and "You can change this once
/// every 30 days." (or the date it can next change); Bio up to 150 with a Mono count; then
/// Location and Website rows. Cancel asks first when anything changed.
///
/// Mediums (sellers only) needs a field on the account (BACKEND_CHANGES B31). Pronouns and the
/// pinned banner aren't on the board; they stay below until that is decided
/// (REMAINING_UI_CHECKLIST section 1).
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pronounsController = TextEditingController();
  final _websiteController = TextEditingController();

  static const _bioLimit = 150;

  /// What the form held when it loaded, to tell whether Cancel would lose anything.
  String _initial = '';
  DateTime? _lastUsernameChangeAt;

  bool _loading = true;
  bool _saving = false;
  bool _canChangeUsername = true;
  String? _usernameError;
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;
  double? _latitude;
  double? _longitude;
  Timer? _usernameDebounce;

  String _username = '';
  String _bannerAutoRule = 'none';
  String? _bannerTargetType;
  String? _bannerTargetId;
  String? _bannerMediaUrl;
  bool _bannerPinChanged = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _usernameController.dispose();
    _pronounsController.dispose();
    _websiteController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _nameController.text = profile.name;
        _bioController.text = profile.bio ?? '';
        _locationController.text = profile.location ?? '';
        _usernameController.text = profile.username;
        _pronounsController.text = profile.pronouns ?? '';
        _websiteController.text = profile.website ?? '';
        _lastUsernameChangeAt = profile.lastUsernameChangeAt;
        _profilePhotoUrl = profile.profilePhotoUrl;
        _coverPhotoUrl = profile.coverPhotoUrl;
        _latitude = profile.latitude;
        _longitude = profile.longitude;
        _canChangeUsername = profile.canChangeUsername;
        _username = profile.username;
        _bannerAutoRule = profile.bannerAutoRule;
        _bannerTargetType = profile.bannerTargetType;
        _bannerTargetId = profile.bannerTargetId;
        _bannerMediaUrl = profile.banner?.mediaUrl;
        _loading = false;
      });
      _initial = _signature();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _signature() => [
    _nameController.text.trim(),
    _usernameController.text.trim(),
    _bioController.text.trim(),
    _locationController.text,
    _websiteController.text.trim(),
    _pronounsController.text.trim(),
    _profilePhotoUrl,
    _coverPhotoUrl,
    _bannerAutoRule,
    _bannerPinChanged,
  ].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  /// Cancel throws away the changes, asking first if there are any (`NoteEditProfile`).
  Future<void> _cancel() async {
    if (_dirty) {
      final discard = await showStudioConfirm(
        context,
        title: 'Discard your changes?',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  /// "Website" in a sheet: one underline field and Done. An optional link shown under the bio.
  Future<void> _editWebsite() async {
    final value = await showStudioSheet<String>(
      context: context,
      builder: (_) => _WebsiteSheet(initial: _websiteController.text),
    );
    if (value != null && mounted) {
      setState(() => _websiteController.text = value);
    }
  }

  String get _usernameNote {
    if (_canChangeUsername) return 'You can change this once every 30 days.';
    final last = _lastUsernameChangeAt;
    if (last == null) return 'You can change this once every 30 days.';
    final next = last.add(const Duration(days: 30));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'You can change it again on ${months[next.month - 1]} ${next.day}.';
  }

  Future<void> _pickBanner() async {
    final result = await showProfileBannerPicker(context, username: _username);
    if (result == null) return;
    setState(() {
      _bannerTargetType = result.$1;
      _bannerTargetId = result.$2;
      _bannerMediaUrl =
          null; // cleared/changed locally; server confirms on save
      _bannerPinChanged = true;
    });
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 3) return;
      try {
        final result = await AuthService.instance.checkUsername(
          value,
          forCurrentUser: true,
        );
        if (!mounted) return;
        setState(() {
          _usernameError = result.available
              ? null
              : (result.message ?? 'Username taken');
        });
      } catch (_) {}
    });
  }

  Future<String?> _uploadPhoto(String purpose) {
    return pickAndUploadPhoto(context, purpose);
  }

  /// Location is a real place: a city found by search, or the city the phone is in
  /// ("Dallas, TX"), with that city's coordinates for Sellers near you. Never free text, and
  /// never the phone's raw position.
  void _pickLocation() {
    FocusScope.of(context).unfocus();
    ChooseLocationSheet.show(
      context,
      subtitle: 'The city you work from. It shows on your profile.',
      footnote:
          'Only the city shows. Sellers near you uses it to find artists close by.',
      onLocationSelected: (place) => setState(() {
        _locationController.text = place.displayName;
        _latitude = place.lat;
        _longitude = place.lng;
      }),
    );
  }

  Future<void> _save() async {
    if (_usernameError != null) return;
    setState(() => _saving = true);
    try {
      final sessionUser = AuthSession.instance.user;
      if (sessionUser != null &&
          _usernameController.text.trim() != sessionUser.username &&
          _canChangeUsername) {
        await UserService.instance.changeUsername(
          _usernameController.text.trim(),
        );
      }
      await UserService.instance.updateMe(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        pronouns: _pronounsController.text.trim(),
        profilePhotoUrl: _profilePhotoUrl,
        coverPhotoUrl: _coverPhotoUrl,
        latitude: _latitude,
        longitude: _longitude,
        website: _websiteController.text.trim(),
        bannerAutoRule: _bannerAutoRule,
        updateBannerTarget: _bannerPinChanged,
        bannerTargetType: _bannerTargetType,
        bannerTargetId: _bannerTargetId,
      );
      if (!mounted) return;
      showStudioToast(context, 'Profile updated');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showStudioToast(
        context,
        e is ApiException ? e.message : 'Could not save your profile.',
        icon: null,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    const gap = SizedBox(height: 20);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: StudioLoadingGate(
        loading: _loading || _saving,
        child: Scaffold(
          backgroundColor: c.background,
          appBar: StudioTopBar(
            context: context,
            title: 'Edit profile',
            leading: TextButton(
              onPressed: _cancel,
              style: TextButton.styleFrom(
                foregroundColor: c.textPrimary,
                minimumSize: const Size(
                  StudioSize.tapTarget,
                  StudioSize.tapTarget,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                style: StudioType.body15(color: c.textPrimary),
              ),
            ),
            actions: [
              StudioSaveAction(onPressed: _saving || _loading ? null : _save),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.only(
              bottom: 40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              ProfileEditHeader(
                coverUrl: _coverPhotoUrl,
                avatarUrl: _profilePhotoUrl,
                onChangeCover: () async {
                  final url = await _uploadPhoto('cover');
                  if (url != null) setState(() => _coverPhotoUrl = url);
                },
                onChangeAvatar: () async {
                  final url = await _uploadPhoto('profile');
                  if (url != null) setState(() => _profilePhotoUrl = url);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  StudioSpace.marginForm,
                  24,
                  StudioSpace.marginForm,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StudioUnderlineField(
                      label: 'Name',
                      valueSize: 16,
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                    ),
                    gap,
                    StudioUnderlineField(
                      label: 'Username',
                      valueSize: 16,
                      controller: _usernameController,
                      prefix: '@',
                      enabled: _canChangeUsername,
                      onChanged: (v) {
                        setState(() {});
                        _onUsernameChanged(v);
                      },
                      errorText: _usernameError,
                      helper: _usernameNote,
                      helperColor: c.textTertiary,
                    ),
                    gap,
                    StudioUnderlineField(
                      label: 'Bio',
                      valueSize: 16,
                      controller: _bioController,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: _bioLimit,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_bioController.text.characters.length} / $_bioLimit',
                        style: StudioType.mono(11, color: c.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Location: the city search (`ChooseLocationSheet`), never free text.
                    _EditRow(
                      label: 'Location',
                      value: _locationController.text,
                      onTap: _pickLocation,
                    ),
                    _EditRow(
                      label: 'Website',
                      value: _websiteController.text,
                      onTap: _editWebsite,
                    ),
                    gap,
                    StudioUnderlineField(
                      label: 'Pronouns',
                      controller: _pronounsController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SettingsSectionLabel('Pinned banner', top: 34),
                    const SizedBox(height: 4),
                    Text(
                      'A piece or post highlighted on your profile — separate from '
                      'the cover photo above.',
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    LabeledDropdown(
                      label: 'Banner rule',
                      value: _bannerAutoRule,
                      options: _bannerRuleOptions,
                      onChanged: (v) => setState(() => _bannerAutoRule = v),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (_bannerMediaUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              StudioRadius.small,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: _bannerMediaUrl!,
                              height: 64,
                              width: 64,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  ColoredBox(color: c.surface),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        StudioButton(
                          label: _bannerTargetId != null
                              ? 'Change pinned banner'
                              : 'Pin a piece or post',
                          variant: StudioButtonVariant.outline,
                          expand: false,
                          onPressed: _pickBanner,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row on Edit profile (`EditProfile` Mediums, Location, Website): label 15 Ink, the value 14
/// Ink on the right ("Add" in Placeholder when empty) and a 16 chevron; 14 above and below, a
/// Line under.
class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final empty = value.trim().isEmpty;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Text(label, style: StudioType.body15(color: c.textPrimary)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  empty ? 'Add' : value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.body14(
                    color: empty ? c.textPlaceholder : c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              StudioIcon(
                StudioIcons.chevronRight,
                size: 16,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Website sheet: "Website" 22/500, one underline field and Done. It owns its controller, so
/// the field outlives the closing animation.
class _WebsiteSheet extends StatefulWidget {
  const _WebsiteSheet({required this.initial});

  final String initial;

  @override
  State<_WebsiteSheet> createState() => _WebsiteSheetState();
}

class _WebsiteSheetState extends State<_WebsiteSheet> {
  late final _link = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 16,
      children: [
        Text('Website', style: StudioType.title22(color: context.studio.textPrimary)),
        StudioUnderlineField(
          label: 'Link',
          controller: _link,
          hint: 'yourstudio.com',
          autofocus: true,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        StudioButton(label: 'Done', onPressed: () => Navigator.pop(context, _link.text.trim())),
      ],
    );
  }
}

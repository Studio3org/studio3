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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickBanner() async {
    final result = await showProfileBannerPicker(context, username: _username);
    if (result == null) return;
    setState(() {
      _bannerTargetType = result.$1;
      _bannerTargetId = result.$2;
      _bannerMediaUrl = null; // cleared/changed locally; server confirms on save
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
          _usernameError = result.available ? null : (result.message ?? 'Username taken');
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
      footnote: 'Only the city shows. Sellers near you uses it to find artists close by.',
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
        await UserService.instance.changeUsername(_usernameController.text.trim());
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
      showStudioToast(context, e is ApiException ? e.message : 'Could not save your profile.', icon: null);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    const gap = SizedBox(height: 22);
    return StudioLoadingGate(
      loading: _loading || _saving,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(
          context: context,
          title: 'Edit profile',
          actions: [
            StudioSaveAction(onPressed: _saving || _loading ? null : _save),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.only(bottom: 40 + MediaQuery.paddingOf(context).bottom),
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
              padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 24, StudioSpace.marginForm, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StudioUnderlineField(label: 'Name', controller: _nameController),
                  gap,
                  StudioUnderlineField(
                    label: 'Username',
                    controller: _usernameController,
                    enabled: _canChangeUsername,
                    onChanged: _onUsernameChanged,
                    errorText: _usernameError,
                  ),
                  gap,
                  StudioUnderlineField(label: 'Bio', controller: _bioController, maxLines: 4, minLines: 1),
                  gap,
                  // Read-only: tapping opens the city search (`ChooseLocationSheet`).
                  StudioUnderlineField(
                    label: 'Location',
                    controller: _locationController,
                    hint: 'Choose your city',
                    readOnly: true,
                    onTap: _pickLocation,
                    trailing: StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
                  ),
                  gap,
                  StudioUnderlineField(label: 'Pronouns', controller: _pronounsController),
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
                          borderRadius: BorderRadius.circular(StudioRadius.small),
                          child: CachedNetworkImage(
                            imageUrl: _bannerMediaUrl!,
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      StudioButton(
                        label: _bannerTargetId != null ? 'Change pinned banner' : 'Pin a piece or post',
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
    );
  }
}

/// "Use my current location" (or "Location captured"): the location icon 16 and 13/500 Ink,
/// a small spinner while it looks.

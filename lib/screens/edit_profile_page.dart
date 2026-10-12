import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/profile_photo_upload.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/profile_edit_header.dart';
import '../widgets/profile_field.dart';
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
  bool _locating = false;
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

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading || _saving,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            'Edit profile',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving || _loading ? null : _save,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.zero,
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: HomeFeedTokens.detailBackground,
                      borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
                      border: Border.all(
                        color: HomeFeedTokens.textPrimary.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: HomeFeedTokens.textPrimary.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ProfileField(label: 'Name', controller: _nameController),
                        _fieldDivider(),
                        ProfileField(
                          label: 'Username',
                          controller: _usernameController,
                          enabled: _canChangeUsername,
                          onChanged: _onUsernameChanged,
                          error: _usernameError,
                        ),
                        _fieldDivider(),
                        ProfileField(
                            label: 'Bio', controller: _bioController, maxLines: 3),
                        _fieldDivider(),
                        ProfileField(
                            label: 'Location', controller: _locationController),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _locating ? null : _useCurrentLocation,
                            icon: _locating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, size: 18),
                            label: Text(
                              _latitude != null
                                  ? 'Location captured'
                                  : 'Use my current location',
                            ),
                          ),
                        ),
                        _fieldDivider(),
                        ProfileField(
                            label: 'Pronouns', controller: _pronounsController),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pinned banner',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A piece or post highlighted on your profile — separate from '
                    'the cover photo above.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LabeledDropdown(
                    label: 'Banner rule',
                    value: _bannerAutoRule,
                    options: _bannerRuleOptions,
                    onChanged: (v) => setState(() => _bannerAutoRule = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickBanner,
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: Text(
                      _bannerTargetId != null
                          ? 'Change pinned banner'
                          : 'Pin a piece or post',
                    ),
                  ),
                  if (_bannerMediaUrl != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: _bannerMediaUrl!,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldDivider() => Divider(
        height: 24,
        color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08),
      );
}

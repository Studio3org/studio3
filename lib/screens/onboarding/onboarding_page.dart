import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/post_picker_options.dart';
import '../../services/api_exception.dart';
import '../../services/auth_session.dart';
import '../../services/media_service.dart';
import '../../services/permission_service.dart';
import '../../services/user_service.dart';
import '../../widgets/auth_ui.dart';
import '../../widgets/studio/studio.dart';
import '../../widgets/permission_denied_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/profile_cover_image.dart';
import '../../widgets/studio_loading.dart';
import '../signup_page.dart';

/// Multi-step onboarding: role → preferences → photos → complete.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.initialStep = 0});

  /// 0 role, 1 preferences, 2 photos.
  final int initialStep;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late int _step = widget.initialStep.clamp(0, 2);
  bool _loading = false;
  String? _role;
  final Set<String> _mediums = {};
  final Set<String> _styles = {};
  final Set<String> _themes = {};
  final _picker = ImagePicker();
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;
  bool _uploadingPhoto = false;

  static const _roles = [
    ('collector', 'Collecting art', 'Available pieces and prices first'),
    ('artist', 'Sharing my work', 'Post pieces and build a following'),
    ('enthusiast', 'Exploring and events', "A bit of everything, plus what's on at The Space"),
  ];

  static const _themeOptions = [
    'Nature',
    'Urban',
    'Portrait',
    'Abstract',
    'Memory',
    'Identity',
    'Landscape',
    'Still life',
    'Figurative',
    'Surreal',
  ];

  Future<void> _next() async {
    if (_step == 0) {
      if (_role == null) {
        _showError('Please select a role');
        return;
      }
      setState(() => _loading = true);
      try {
        await UserService.instance.setRole(_role!);
        if (!mounted) return;
        setState(() => _step = 1);
      } catch (e) {
        _showError(e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    if (_step == 1) {
      if (_mediums.length < 3 || _styles.length < 3 || _themes.length < 3) {
        _showError('Select at least 3 in each category');
        return;
      }
      setState(() => _loading = true);
      try {
        await UserService.instance.setOnboardingPreferences(
          mediums: _mediums.toList(),
          styles: _styles.toList(),
          themes: _themes.toList(),
        );
        if (!mounted) return;
        setState(() => _step = 2);
      } catch (e) {
        _showError(e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    if (_step == 2) {
      setState(() => _loading = true);
      try {
        if (_profilePhotoUrl == null && SignupExtras.photoPath != null) {
          final url = await MediaService.instance.uploadFile(
            purpose: MediaPurpose.profile,
            file: File(SignupExtras.photoPath!),
          );
          _profilePhotoUrl = url;
          SignupExtras.photoPath = null;
        }
        if (_profilePhotoUrl == null && _coverPhotoUrl == null) {
          await UserService.instance.setOnboardingPhotos(skip: true);
        } else {
          await UserService.instance.setOnboardingPhotos(
            profilePhotoUrl: _profilePhotoUrl,
            coverPhotoUrl: _coverPhotoUrl,
          );
        }
        await UserService.instance.completeOnboarding();
        if (!mounted) return;
        final firstName = AuthSession.instance.user?.name.split(' ').first;
        final navigator = Navigator.of(context);
        navigator.pushReplacementNamed('/');
        final welcome = (firstName == null || firstName.isEmpty)
            ? 'Welcome to Studio 3'
            : 'Welcome to Studio 3, $firstName';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigator.context.mounted) {
            showStudioToast(navigator.context, welcome);
          }
        });
      } catch (e) {
        _showError(e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _uploadPhoto(String purpose) async {
    if (_uploadingPhoto || _loading) return;
    final outcome = await PermissionService.instance
        .requestGalleryAccess(forVideo: false);
    if (outcome == GalleryPermissionOutcome.deniedForever) {
      if (mounted) {
        await showPermissionDeniedSheet(
          context,
          title: 'Photo access needed',
          message: 'Enable photo library access in Settings to upload a photo.',
        );
      }
      return;
    }
    if (outcome == GalleryPermissionOutcome.denied) return;
    setState(() => _uploadingPhoto = true);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final url = await MediaService.instance.uploadFile(
        purpose: purpose,
        file: File(picked.path),
      );
      if (!mounted) return;
      setState(() {
        if (purpose == MediaPurpose.profile) {
          _profilePhotoUrl = url;
        } else {
          _coverPhotoUrl = url;
        }
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading || _uploadingPhoto,
      child: SignInStepScaffold(
        progressCurrent: _step == 0 ? 3 : null,
        bottom: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudioButton(
              label: _step == 2 ? 'Finish' : 'Continue',
              height: 54,
              onPressed: _next,
            ),
            if (_step == 0) ...[
              const SizedBox(height: 4),
              AuthGhostButton(
                label: 'Skip for now',
                onPressed: () => setState(() => _step = 1),
              ),
            ],
          ],
        ),
        body: switch (_step) {
          0 => _buildRoleStep(),
          1 => _buildPreferencesStep(),
          _ => _buildPhotosStep(),
        },
      ),
    );
  }

  Widget _buildRoleStep() {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What brings you to Studio 3?', style: StudioType.title32(color: c.textPrimary)),
        const SizedBox(height: 10),
        Text(
          "We'll use this to get your feed started.",
          style: StudioType.body16(color: c.textSecondary),
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < _roles.length; i++)
          StudioSelectRow(
            title: _roles[i].$2,
            subtitle: _roles[i].$3,
            selected: _role == _roles[i].$1,
            divider: i < _roles.length - 1,
            onTap: () => setState(() => _role = _roles[i].$1),
          ),
      ],
    );
  }

  Widget _buildPreferencesStep() {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your taste', style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Pick at least 3 mediums, styles, and themes.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        const SizedBox(height: 20),
        _ChipSection(
          title: 'Mediums (${_mediums.length}/3+)',
          options: PostMediumOptions.all.map((e) => e.name).toList(),
          selected: _mediums,
          onToggle: (name) {
            final id = PostMediumOptions.all
                .firstWhere((e) => e.name == name)
                .id;
            setState(() {
              if (_mediums.contains(id)) {
                _mediums.remove(id);
              } else {
                _mediums.add(id);
              }
            });
          },
          idForName: (name) =>
              PostMediumOptions.all.firstWhere((e) => e.name == name).id,
        ),
        const SizedBox(height: 16),
        _ChipSection(
          title: 'Styles (${_styles.length}/3+)',
          options: PostStyleOptions.all.map((e) => e.name).toList(),
          selected: _styles,
          onToggle: (name) {
            final id =
                PostStyleOptions.all.firstWhere((e) => e.name == name).id;
            setState(() {
              if (_styles.contains(id)) {
                _styles.remove(id);
              } else {
                _styles.add(id);
              }
            });
          },
          idForName: (name) =>
              PostStyleOptions.all.firstWhere((e) => e.name == name).id,
        ),
        const SizedBox(height: 16),
        _ChipSection(
          title: 'Themes (${_themes.length}/3+)',
          options: _themeOptions,
          selected: _themes,
          onToggle: (name) {
            setState(() {
              if (_themes.contains(name)) {
                _themes.remove(name);
              } else {
                _themes.add(name);
              }
            });
          },
          idForName: (name) => name,
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a photo', style: StudioType.title32(color: c.textPrimary)),
        const SizedBox(height: 10),
        Text(
          'Add a profile photo and cover image, or tap Finish to skip for now.',
          style: StudioType.body16(color: c.textSecondary),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () => _uploadPhoto(MediaPurpose.profile),
          child: Row(
            children: [
              _profilePhotoUrl == null && SignupExtras.photoPath == null
                  ? Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: StudioIcon(StudioIcons.post, size: 26, color: c.textTertiary),
                    )
                  : _profilePhotoUrl != null
                      ? ProfileAvatar(url: _profilePhotoUrl, size: 72)
                      : ClipOval(
                          child: Image.file(
                            File(SignupExtras.photoPath!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profilePhotoUrl == null && SignupExtras.photoPath == null
                        ? 'Add a photo'
                        : 'Profile photo added',
                    style: StudioType.body15(color: c.textPrimary).copyWith(fontWeight: StudioType.medium),
                  ),
                  const SizedBox(height: 2),
                  Text('Optional', style: StudioType.label13(color: c.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _uploadPhoto(MediaPurpose.cover),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ProfileCoverImage(
                  url: _coverPhotoUrl,
                  width: double.infinity,
                  height: 120,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _coverPhotoUrl == null ? 'Add cover photo' : 'Cover photo added',
                      style: StudioType.body15(color: c.textPrimary).copyWith(fontWeight: StudioType.medium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.idForName,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String Function(String name) idForName;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: StudioType.body15(color: c.textPrimary).copyWith(fontWeight: StudioType.medium)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((name) {
            final id = idForName(name);
            return StudioChip(
              label: name,
              selected: selected.contains(id),
              onTap: () => onToggle(name),
            );
          }).toList(),
        ),
      ],
    );
  }
}

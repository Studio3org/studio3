import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/post_picker_options.dart';
import '../../services/api_exception.dart';
import '../../services/media_service.dart';
import '../../services/permission_service.dart';
import '../../services/user_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../../widgets/auth_ui.dart';
import '../../widgets/permission_denied_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/profile_cover_image.dart';
import '../../widgets/studio_loading.dart';

/// Multi-step onboarding: role → preferences → photos → complete.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
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
    ('artist', 'Artist', 'Create and share your work'),
    ('collector', 'Collector', 'Discover and collect art'),
    ('enthusiast', 'Enthusiast', 'Explore and engage with art'),
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
        Navigator.pushReplacementNamed(context, '/');
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
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        title: Text(
          'Set up your profile',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? HomeFeedTokens.textPrimary
                            : HomeFeedTokens.textPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: switch (_step) {
                  0 => _buildRoleStep(),
                  1 => _buildPreferencesStep(),
                  _ => _buildPhotosStep(),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: AuthPrimaryButton(
                label: _step == 2 ? 'Finish' : 'Continue',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What brings you to Studio 3?',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        for (final (id, title, subtitle) in _roles)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoleCard(
              title: title,
              subtitle: subtitle,
              selected: _role == id,
              onTap: () => setState(() => _role = id),
            ),
          ),
      ],
    );
  }

  Widget _buildPreferencesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your taste',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick at least 3 mediums, styles, and themes.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile photos',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add a profile photo and cover image, or tap Finish to skip for now.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => _uploadPhoto(MediaPurpose.profile),
          child: Row(
            children: [
              ProfileAvatar(
                url: _profilePhotoUrl,
                size: 72,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _profilePhotoUrl == null
                      ? 'Add profile photo'
                      : 'Profile photo added',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: HomeFeedTokens.textPrimary.withValues(alpha: 0.35),
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
                  Icon(
                    Icons.image_outlined,
                    color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _coverPhotoUrl == null
                          ? 'Add cover photo'
                          : 'Cover photo added',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: HomeFeedTokens.textPrimary.withValues(alpha: 0.35),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? HomeFeedTokens.textPrimary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? HomeFeedTokens.textPrimary
                  : HomeFeedTokens.textPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((name) {
            final id = idForName(name);
            final isSelected = selected.contains(id);
            return FilterChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (_) => onToggle(name),
              selectedColor: HomeFeedTokens.textPrimary.withValues(alpha: 0.15),
              checkmarkColor: HomeFeedTokens.textPrimary,
            );
          }).toList(),
        ),
      ],
    );
  }
}

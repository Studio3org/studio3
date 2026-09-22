import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/profile_photo_upload.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/loading/section_loader.dart';
import '../widgets/loading/skeleton_primitives.dart';
import '../widgets/studio_loading.dart';
import 'profile_banner_picker_sheet.dart';
import 'profile_settings_page.dart';

const _pronounPresets = ['she/her', 'he/him', 'they/them', 'she/they', 'he/they'];
const _categoryPresets = [
  'Digital Art',
  'Oil & Canvas',
  '3D & Motion',
  'Photography',
  'Illustration',
  'Sculpture',
  'Generative Art',
  'Mixed Media',
];

const _bioTemplates = [
  'Contemporary artist exploring themes of light, shadow, and digital medium.',
  '3D designer and animator crafting immersive visual worlds.',
  'Fine painter combining traditional oil techniques with modern surrealism.',
  'Visual storyteller capturing urban landscapes and quiet moments.',
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
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _tagInputController = TextEditingController();

  int _activeTab = 0; // 0: Identity, 1: Bio & Socials, 2: Hero & Banner
  bool _loading = true;
  bool _saving = false;

  /// Whether the form is populated with the user's real values (from cache
  /// or from the network) rather than empty placeholders.
  bool _hasProfile = false;

  /// Set once the user types into any field. A background cache
  /// revalidation must never overwrite work in progress, so fresh server
  /// values are only adopted while this is false.
  bool _userEdited = false;

  /// Guards [_userEdited] against the controller writes [_applyProfile]
  /// makes itself.
  bool _applyingProfile = false;

  late final List<TextEditingController> _profileControllers = [
    _nameController,
    _bioController,
    _locationController,
    _usernameController,
    _pronounsController,
    _websiteController,
    _instagramController,
    _twitterController,
  ];
  bool _canChangeUsername = true;
  String? _usernameError;
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;
  double? _latitude;
  double? _longitude;
  bool _locating = false;
  Timer? _usernameDebounce;

  String _username = '';
  String _category = 'Digital Art';
  String _bannerAutoRule = 'most_saved';
  String? _bannerTargetType;
  String? _bannerTargetId;
  String? _bannerMediaUrl;
  bool _bannerPinChanged = false;
  List<String> _tags = ['Abstract', 'Digital', 'NFT'];

  @override
  void initState() {
    super.initState();
    // Populate from cache first so a revisit opens straight onto the real
    // form instead of flashing placeholder fields; `_loadProfile` still
    // runs and reconciles silently.
    _applyProfile(UserService.instance.peekMeCached());
    for (final controller in _profileControllers) {
      controller.addListener(_markEdited);
    }
    _loadProfile();
  }

  void _markEdited() {
    if (_applyingProfile || _userEdited) return;
    _userEdited = true;
  }

  @override
  void dispose() {
    for (final controller in _profileControllers) {
      controller.removeListener(_markEdited);
    }
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _usernameController.dispose();
    _pronounsController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _tagInputController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  int get _completionPercentage {
    int score = 0;
    const total = 7;
    if (_nameController.text.trim().isNotEmpty) score++;
    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) score++;
    if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty) score++;
    if (_bioController.text.trim().isNotEmpty) score++;
    if (_locationController.text.trim().isNotEmpty) score++;
    if (_websiteController.text.trim().isNotEmpty) score++;
    if (_tags.isNotEmpty) score++;
    return ((score / total) * 100).round();
  }

  /// Copies [profile] into the form's controllers and local fields.
  ///
  /// Not a `setState` itself — callers decide whether they're seeding
  /// before the first frame or reacting to a later response.
  void _applyProfile(UserProfile? profile) {
    if (profile == null) return;
    _applyingProfile = true;
    _nameController.text = profile.name;
    _bioController.text = profile.bio ?? '';
    _locationController.text = profile.location ?? '';
    _usernameController.text = profile.username;
    _pronounsController.text = profile.pronouns ?? '';
    _websiteController.text = profile.website ?? '';
    _instagramController.text = profile.instagram ?? '';
    _twitterController.text = profile.twitter ?? '';
    _category = profile.category ?? _category;
    _tags = List<String>.from(profile.tags);
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
    _hasProfile = true;
    _applyingProfile = false;
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserService.instance.getMeCached(
        onBackgroundUpdate: (fresh) {
          if (!mounted || _userEdited) return;
          setState(() => _applyProfile(fresh));
        },
      );
      if (!mounted) return;
      setState(() {
        if (!_userEdited) _applyProfile(profile);
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
      _bannerMediaUrl = null;
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
        _locationController.text =
            '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
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
    if (_usernameError != null) {
      setState(() => _activeTab = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usernameError!)),
      );
      return;
    }
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
        website: _websiteController.text.trim(),
        instagram: _instagramController.text.trim(),
        twitter: _twitterController.text.trim(),
        category: _category,
        tags: _tags,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTag(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'^#'), '');
    if (cleaned.isNotEmpty && !_tags.contains(cleaned) && _tags.length < 8) {
      setState(() {
        _tags.add(cleaned);
        _tagInputController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The gate blocks only while a save is in flight (a mutation the user
    // must not interrupt). The initial GET does not block the page: chrome,
    // tab nav and the settings footer are static and paint immediately,
    // while the profile-backed sections placehold individually.
    return StudioLoadingGate(
      loading: _saving,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.detailBackground,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.detailBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: HomeFeedTokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _completionPercentage == 100
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_completionPercentage% Complete',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _saving || _loading ? null : _save,
                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                label: Text(
                  'Save',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeFeedTokens.neutral800,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            SectionLoader(
              hasData: _hasProfile,
              loading: _loading,
              skeleton: (_) => const SkeletonShimmer(
                child: SkeletonBox(height: 216, radius: 18),
              ),
              content: (_) => _buildHeroCard(),
            ),
            const SizedBox(height: 20),
            // Static: the tabs work — and remember the user's choice —
            // before any profile data has arrived.
            _buildSegmentedTabNav(),
            const SizedBox(height: 16),
            SectionLoader(
              hasData: _hasProfile,
              loading: _loading,
              skeleton: (_) => const FormSkeleton(
                fieldCount: 4,
                padding: EdgeInsets.zero,
              ),
              content: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeTab == 0) _buildIdentityTab(),
                  if (_activeTab == 1) _buildBioTab(),
                  if (_activeTab == 2) _buildBannerTab(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Static: pure navigation, no backend dependency.
            _buildSettingsFooterCard(),
          ],
        ),
      ),
    );
  }

  /// Cover Photo & Floating Avatar Card
  Widget _buildHeroCard() {
    return Container(
      decoration: BoxDecoration(
        color: HomeFeedTokens.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Photo
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _coverPhotoUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(color: HomeFeedTokens.skeletonBase),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: InkWell(
                  onTap: () async {
                    final url = await _uploadPhoto('cover');
                    if (url != null) setState(() => _coverPhotoUrl = url);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _coverPhotoUrl != null ? 'Change Cover' : 'Upload Cover',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Floating Avatar
              Positioned(
                left: 16,
                bottom: -32,
                child: GestureDetector(
                  onTap: () async {
                    final url = await _uploadPhoto('profile');
                    if (url != null) setState(() => _profilePhotoUrl = url);
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: HomeFeedTokens.background, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _profilePhotoUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: HomeFeedTokens.skeletonBase,
                                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                          child: const Icon(Icons.camera_alt, size: 22, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'Your Name',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                    Text(
                      '@${_usernameController.text.isNotEmpty ? _usernameController.text : 'handle'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented Tab Navigation Bar
  Widget _buildSegmentedTabNav() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE6DE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabBtn(0, Icons.person_outline, 'Identity'),
          _tabBtn(1, Icons.tune_outlined, 'Bio & Socials'),
          _tabBtn(2, Icons.auto_awesome_outlined, 'Hero Banner'),
        ],
      ),
    );
  }

  Widget _tabBtn(int index, IconData icon, String label) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? HomeFeedTokens.textPrimary : HomeFeedTokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? HomeFeedTokens.textPrimary : HomeFeedTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// TAB 1: IDENTITY
  Widget _buildIdentityTab() {
    return _buildCard(
      title: 'Basic Information',
      subtitle: 'Your public identity across Studio 3',
      children: [
        _buildTextField(
          label: 'Display Name',
          controller: _nameController,
          hint: 'e.g. Alex Vance',
          maxLength: 50,
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Username',
          controller: _usernameController,
          hint: 'username',
          enabled: _canChangeUsername,
          onChanged: _onUsernameChanged,
          errorText: _usernameError,
          prefixText: '@',
        ),
        const SizedBox(height: 16),
        Text(
          'Pronouns',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _pronounPresets.map((p) {
            final selected = _pronounsController.text == p;
            return ChoiceChip(
              label: Text(p),
              selected: selected,
              onSelected: (sel) {
                setState(() => _pronounsController.text = sel ? p : '');
              },
              selectedColor: HomeFeedTokens.neutral800,
              backgroundColor: Colors.white,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                color: selected ? Colors.white : HomeFeedTokens.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected
                      ? HomeFeedTokens.neutral800
                      : HomeFeedTokens.textPrimary.withValues(alpha: 0.15),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          label: '',
          controller: _pronounsController,
          hint: 'Or type custom pronouns (e.g. xe/them)',
        ),
        const SizedBox(height: 16),
        Text(
          'Primary Discipline',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _categoryPresets.length,
          itemBuilder: (context, idx) {
            final cat = _categoryPresets[idx];
            final active = _category == cat;
            return InkWell(
              onTap: () => setState(() => _category = cat),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: active ? HomeFeedTokens.neutral800.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? HomeFeedTokens.neutral800
                        : HomeFeedTokens.textPrimary.withValues(alpha: 0.12),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                    if (active)
                      const Icon(Icons.check_circle, size: 14, color: HomeFeedTokens.neutral800),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// TAB 2: BIO & DETAILS
  Widget _buildBioTab() {
    return _buildCard(
      title: 'Artist Bio & Story',
      subtitle: 'Tell collectors about your art style and inspiration',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bio',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            Text(
              '${_bioController.text.length}/250',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: HomeFeedTokens.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bioController,
          maxLength: 250,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Write a brief artist statement...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: HomeFeedTokens.textSecondary),
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HomeFeedTokens.textPrimary.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HomeFeedTokens.neutral800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Bio starters box
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EEE7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: HomeFeedTokens.neutral800),
                  const SizedBox(width: 4),
                  Text(
                    'QUICK BIO STARTERS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: HomeFeedTokens.neutral800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                children: _bioTemplates.map((tmpl) {
                  return InkWell(
                    onTap: () => setState(() => _bioController.text = tmpl),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '"${tmpl.substring(0, tmpl.length > 42 ? 42 : tmpl.length)}..."',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: HomeFeedTokens.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Location',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: '',
                controller: _locationController,
                hint: 'e.g. Berlin, Germany',
                prefixIcon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.explore_outlined, size: 16),
              label: Text(_locating ? 'Locating...' : 'Detect'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Website / Portfolio',
          controller: _websiteController,
          hint: 'https://yourportfolio.art',
          prefixIcon: Icons.language_outlined,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Instagram',
                controller: _instagramController,
                hint: '@username',
                prefixIcon: Icons.camera_alt_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                label: 'Twitter / X',
                controller: _twitterController,
                hint: '@handle',
                prefixIcon: Icons.alternate_email,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// TAB 3: HERO & BANNER
  Widget _buildBannerTab() {
    return Column(
      children: [
        _buildCard(
          title: 'Banner Auto-Display Rule',
          subtitle: 'Control how artwork dynamically pins to your profile header',
          children: [
            _buildRuleOption(
              keyName: 'most_saved',
              title: 'Most Saved Artwork',
              desc: 'Automatically showcases your highest saved piece in banner',
            ),
            const SizedBox(height: 10),
            _buildRuleOption(
              keyName: 'most_recent',
              title: 'Most Recent Post',
              desc: 'Displays your newest published creation on profile header',
            ),
            const SizedBox(height: 10),
            _buildRuleOption(
              keyName: 'none',
              title: 'Static Cover Image',
              desc: 'Use your uploaded cover photo as a constant profile banner',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickBanner,
              icon: const Icon(Icons.push_pin_outlined, size: 18),
              label: Text(
                _bannerTargetId != null ? 'Change pinned banner' : 'Pin a piece or post',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        const SizedBox(height: 16),
        _buildCard(
          title: 'Discipline & Style Tags',
          subtitle: 'Add up to 8 keywords representing your aesthetic style',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((t) {
                return Chip(
                  label: Text('#$t'),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _tags.remove(t)),
                  backgroundColor: const Color(0xFFEAE6DE),
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                );
              }).toList(),
            ),
            if (_tags.length < 8) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInputController,
                      onSubmitted: _addTag,
                      decoration: InputDecoration(
                        hintText: 'Type a tag (e.g. oil, abstract) & press enter',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: HomeFeedTokens.textSecondary),
                        prefixIcon: const Icon(Icons.tag, size: 16),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.15),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: HomeFeedTokens.neutral800),
                    onPressed: () => _addTag(_tagInputController.text),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRuleOption({
    required String keyName,
    required String title,
    required String desc,
  }) {
    final selected = _bannerAutoRule == keyName;
    return InkWell(
      onTap: () => setState(() => _bannerAutoRule = keyName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? HomeFeedTokens.neutral800.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? HomeFeedTokens.neutral800
                : HomeFeedTokens.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? HomeFeedTokens.neutral800
                      : HomeFeedTokens.textPrimary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: HomeFeedTokens.neutral800,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Account Settings Banner Footer
  Widget _buildSettingsFooterCard() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomeFeedTokens.textPrimary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: HomeFeedTokens.neutral800, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account & Security Settings',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Manage password, privacy, email & notifications',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: HomeFeedTokens.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeFeedTokens.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
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
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    void Function(String)? onChanged,
    String? errorText,
    IconData? prefixIcon,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14, color: HomeFeedTokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: HomeFeedTokens.textSecondary),
            errorText: errorText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: HomeFeedTokens.textSecondary)
                : null,
            prefixText: prefixText,
            prefixStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textSecondary,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF1EEE7),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: HomeFeedTokens.textPrimary.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: HomeFeedTokens.neutral800),
            ),
          ),
        ),
      ],
    );
  }
}

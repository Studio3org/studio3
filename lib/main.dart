import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/auth_session.dart';
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'services/chat_socket_service.dart';
import 'services/deep_link_service.dart';
import 'services/device_service.dart';
import 'services/permission_service.dart';
import 'services/main_nav_service.dart';
import 'services/reels_tab_service.dart';
import 'services/saved_content_store.dart';
import 'services/user_service.dart';
import 'utils/app_routes.dart';
import 'utils/app_state_store.dart';
import 'utils/profile_navigation.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart' show BottomNav, BottomNavIndex;
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/welcome_page.dart';
import 'screens/profile_settings_page.dart';
import 'screens/home_feed_page.dart';
import 'screens/explore_page.dart';
import 'screens/reels_page.dart';
import 'screens/saved_page.dart';
import 'screens/profile_page.dart';
import 'screens/post_page.dart';
import 'screens/inbox_page.dart';
import 'screens/onboarding/onboarding_page.dart';
import 'screens/edit_profile_page.dart';
import 'screens/manage_series_page.dart';
import 'screens/address_list_page.dart';
import 'screens/my_orders_page.dart';
import 'screens/my_sales_page.dart';
import 'screens/change_password_page.dart';
import 'screens/change_email_page.dart';
import 'screens/notification_preferences_page.dart';
import 'screens/blocked_users_page.dart';
import 'screens/privacy_settings_page.dart';
import 'models/auth_user.dart';
import 'models/feed_item.dart';
import 'theme/home_feed_tokens.dart';
import 'utils/scrolls_to_top_on_double_tap.dart';
import 'utils/snappy_page_physics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: HomeFeedTokens.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await AuthSession.instance.initialize();
  await CacheService.instance.init();
  await AppStateStore.instance.initialize();
  await SavedContentStore.instance.load();
  await ConnectivityService.instance.init();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase unavailable (no config yet?): $e');
  }
  await _preloadInterFont();
  runApp(const Studio3App());
}

/// Requests every Inter weight the app uses and waits for them to finish
/// loading before the first frame paints — otherwise the very first time
/// each weight is used in a session (e.g. Home's header right after login),
/// Flutter briefly paints a fallback system font whose slightly different
/// metrics can trip a `RenderFlex` overflow in tightly-fitted layouts (see
/// `_UnderlinedFilterTab` in `widgets/home_feed/home_feed_widgets.dart`).
/// Bounded by a timeout so a genuinely offline first launch can't hang
/// startup — it just falls back to the system font for that session.
Future<void> _preloadInterFont() async {
  for (final weight in const [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ]) {
    GoogleFonts.inter(fontWeight: weight);
  }
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 3));
  } catch (_) {
    // Offline/slow first launch — proceed with the fallback font.
  }
}

class Studio3App extends StatelessWidget {
  const Studio3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studio 3 Discover',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: resolveInitialRoute(),
      navigatorObservers: [routeObserver],
      routes: {
        '/': (context) => const AuthGate(
              child: MainShell(),
            ),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/welcome': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as AuthUser?;
          return WelcomePage(
            user: user ?? const AuthUser(username: '', name: 'Artist', email: ''),
          );
        },
        '/profile-settings': (context) => const ProfileSettingsPage(),
        '/manage-series': (context) => const ManageSeriesPage(),
        '/edit-profile': (context) => const EditProfilePage(),
        '/addresses': (context) => const AddressListPage(),
        '/orders': (context) => const MyOrdersPage(),
        '/sales': (context) => const MySalesPage(),
        '/change-password': (context) => const ChangePasswordPage(),
        '/change-email': (context) => const ChangeEmailPage(),
        '/notification-preferences': (context) => const NotificationPreferencesPage(),
        '/privacy-settings': (context) => const PrivacySettingsPage(),
        '/blocked-users': (context) => const BlockedUsersPage(),
        '/profile': (context) {
          final args = parseProfileRouteArgs(
            ModalRoute.of(context)?.settings.arguments,
          );
          if (args == null) return const ProfilePage();
          return ProfilePage(
            username: args.username,
            viewerMode: args.viewerMode,
          );
        },
        '/post': (context) => const PostPage(),
        // Inquiries deferred to v2 — legacy /chat route redirects to Conversations inbox.
        '/chat': (context) => const InboxPage(initialTab: InboxTab.chats),
        '/inbox': (context) {
          final tab = ModalRoute.of(context)?.settings.arguments as InboxTab?;
          return InboxPage(initialTab: tab ?? InboxTab.notifications);
        },
      },
    );
  }
}

/// Redirects unauthenticated or non-onboarded users.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _deviceRegistered = false;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
      DeepLinkService.instance.start(context);
    });
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onSessionChanged);
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  void _onSessionChanged() => _checkAuth();

  void _checkAuth() {
    if (!mounted) return;
    final session = AuthSession.instance;
    if (session.isLoggedIn && !_deviceRegistered) {
      _deviceRegistered = true;
      DeviceService.instance.registerCurrentDevice();
      PermissionService.instance.requestNotifications();
      ChatSocketService.instance.connect();
      ConnectivityService.instance.addReconnectHook(() async {
        ChatSocketService.instance.connect();
      });
    }
    if (!session.isLoggedIn) {
      _deviceRegistered = false;
      ChatSocketService.instance.disconnect();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    if (!session.isOnboarded) {
      if (kDebugMode) {
        final u = session.user;
        debugPrint(
          '[AuthGate] Redirecting to /onboarding — '
          'user.onboardingComplete=${u?.onboardingComplete}, '
          'username=${u?.username}, isLoggedIn=${session.isLoggedIn}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade900,
              duration: const Duration(seconds: 6),
              content: Text(
                'DEBUG: bounced to onboarding — '
                'onboardingComplete=${u?.onboardingComplete} '
                'for ${u?.username}',
              ),
            ),
          );
        });
      }
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // Page indices for the single swipeable Home/Discover/Reels/Saved
  // sequence. Home is one page (its "All"/"Available" tabs switch by
  // tapping only, entirely within that page — see `HomePage`), so a
  // left/right swipe flows continuously between these 4 top-level
  // sections. Profile is deliberately NOT one of these pages — it's shown
  // as a tap-only overlay (see `_showProfile`) so it can never be swiped
  // into or out of.
  static const _kHomePage = 0;
  static const _kDiscoverPage = 1;
  static const _kReelsPage = 2;
  static const _kSavedPage = 3;

  // How long after a nav-icon tap a second tap on the same (already active)
  // icon still counts as a double-tap → scroll-to-top-and-refresh.
  static const _kDoubleTapWindow = Duration(milliseconds: 350);

  // Always start on the For You/Home tab, regardless of which tab was last
  // open — matching Instagram's "always opens to the main feed" behavior.
  // A ValueNotifier (rather than a plain int + setState) so nav-index
  // changes only rebuild the BottomNav subtree below, instead of the whole
  // MainShell (which would otherwise also re-run on every avatar reload /
  // auth-session change via the shared setState scope).
  final ValueNotifier<int> _selectedNavIndex =
      ValueNotifier(BottomNavIndex.home);
  late final ValueNotifier<bool> _reelsActive =
      ValueNotifier(_selectedNavIndex.value == BottomNavIndex.reels);
  final ValueNotifier<bool> _showProfile = ValueNotifier(false);
  final ValueNotifier<ReelsJumpRequest?> _reelsJumpRequest = ValueNotifier(
    null,
  );

  late final PageController _pageController = PageController(
    initialPage: _kHomePage,
  );
  final HomeFeedStore _homeFeedStore = HomeFeedStore();
  int _currentPage = _kHomePage;

  int? _lastNavTapIndex;
  DateTime? _lastNavTapAt;

  // GlobalKeys so a double-tap on a bottom-nav icon can reach into the
  // already-built page and ask it to scroll to top + refresh
  // (`ScrollsToTopOnDoubleTap`), without rebuilding the page itself.
  final GlobalKey<State<StatefulWidget>> _homeKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _exploreKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _reelsKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _savedKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _profileKey = GlobalKey();

  // Built once — every page widget is `const` where possible so this list
  // never needs to be reconstructed.
  late final List<Widget> _pages = [
    HomePage(key: _homeKey, store: _homeFeedStore),
    ExplorePage(key: _exploreKey),
    ReelsPage(
      key: _reelsKey,
      activeListenable: _reelsActive,
      jumpRequests: _reelsJumpRequest,
    ),
    SavedPage(key: _savedKey),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_onSessionChanged);
    _selectedNavIndex.addListener(_onNavIndexChanged);
    ReelsTabService.instance.register(_openReelsTab);
    MainNavService.instance.register(goHome: _goHome);
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.removeListener(_onSessionChanged);
    _selectedNavIndex.removeListener(_onNavIndexChanged);
    ReelsTabService.instance.unregister();
    MainNavService.instance.unregister();
    _selectedNavIndex.dispose();
    _reelsActive.dispose();
    _showProfile.dispose();
    _reelsJumpRequest.dispose();
    _pageController.dispose();
    _homeFeedStore.dispose();
    super.dispose();
  }

  /// Bridges "open this video" call sites (see `lib/utils/reels_route.dart`)
  /// to this shell's own Reels tab, so a video opens by switching tabs in
  /// place — keeping the bottom nav bar visible — instead of covering it
  /// with a full-screen pushed route.
  void _openReelsTab(List<FeedItem> items, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _reelsJumpRequest.value = ReelsJumpRequest(items: items, index: index);
    _onNavTap(BottomNavIndex.reels);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _onNavTap(BottomNavIndex.home);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AppStateStore.instance.saveNavIndex(_selectedNavIndex.value);
    }
  }

  void _onNavIndexChanged() {
    _reelsActive.value = _selectedNavIndex.value == BottomNavIndex.reels;
  }

  void _onSessionChanged() {
    // Only the avatar (read directly by BottomNav's ValueListenableBuilder
    // below) needs to react to session changes — no setState here avoids
    // rebuilding the whole shell (and therefore every const-canonicalized
    // page reference) for an avatar URL update.
    if (mounted) setState(() {});
  }

  Future<void> _loadProfilePhoto() async {
    try {
      await UserService.instance.getMe();
    } catch (_) {
      // Keep placeholder avatar when profile cannot be loaded.
    } finally {
      if (mounted) setState(() {});
    }
  }

  int _navIndexForPage(int page) {
    switch (page) {
      case _kHomePage:
        return BottomNavIndex.home;
      case _kDiscoverPage:
        return BottomNavIndex.discover;
      case _kReelsPage:
        return BottomNavIndex.reels;
      case _kSavedPage:
      default:
        return BottomNavIndex.bookmark;
    }
  }

  void _onPageChanged(int page) {
    // Covers swipe-to-switch too, not just bottom-nav taps (see _onNavTap).
    FocusManager.instance.primaryFocus?.unfocus();
    _currentPage = page;
    final navIndex = _navIndexForPage(page);
    _selectedNavIndex.value = navIndex;
    AppStateStore.instance.saveNavIndex(navIndex);
  }

  /// Single tap switches to the tapped section (if not already there).
  /// A second tap on the icon for the section that's *already active*,
  /// within [_kDoubleTapWindow], scrolls that page to top and refreshes it
  /// — matching Instagram's bottom-nav double-tap convention.
  void _onNavTap(int navIndex) {
    // Every tab stays mounted in the PageView/Offstage rather than being
    // disposed on switch, so a field focused on one tab (e.g. the Explore
    // search bar) keeps the keyboard open even after navigating away —
    // dismiss it on every tab switch so no tab ever inherits it.
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final isDoubleTap = _selectedNavIndex.value == navIndex &&
        _lastNavTapIndex == navIndex &&
        _lastNavTapAt != null &&
        now.difference(_lastNavTapAt!) <= _kDoubleTapWindow;
    _lastNavTapIndex = navIndex;
    _lastNavTapAt = now;

    if (isDoubleTap) {
      _lastNavTapAt = null; // avoid a third tap re-triggering immediately
      _scrollToTopAndRefresh(navIndex);
      return;
    }

    if (navIndex == BottomNavIndex.profile) {
      _showProfile.value = true;
      _selectedNavIndex.value = BottomNavIndex.profile;
      AppStateStore.instance.saveNavIndex(navIndex);
      _loadProfilePhoto();
      return;
    }
    _showProfile.value = false;
    final targetPage = switch (navIndex) {
      BottomNavIndex.home => _kHomePage,
      BottomNavIndex.discover => _kDiscoverPage,
      BottomNavIndex.reels => _kReelsPage,
      BottomNavIndex.bookmark => _kSavedPage,
      _ => _currentPage,
    };
    _selectedNavIndex.value = navIndex;
    AppStateStore.instance.saveNavIndex(navIndex);
    if (targetPage != _currentPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToTopAndRefresh(int navIndex) {
    final key = switch (navIndex) {
      BottomNavIndex.home => _homeKey,
      BottomNavIndex.discover => _exploreKey,
      BottomNavIndex.reels => _reelsKey,
      BottomNavIndex.bookmark => _savedKey,
      BottomNavIndex.profile => _profileKey,
      _ => null,
    };
    (key?.currentState as ScrollsToTopOnDoubleTap?)?.scrollToTopAndRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView(
            controller: _pageController,
            physics: const SnappyPageScrollPhysics(),
            onPageChanged: _onPageChanged,
            children: _pages,
          ),
          // Offstage (not a conditional widget swap) so ProfilePage stays
          // mounted the whole session — its own data/scroll state survives
          // being hidden, same as it did as an IndexedStack child before.
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _showProfile,
              builder: (context, show, child) => Offstage(
                offstage: !show,
                child: child,
              ),
              child: ProfilePage(key: _profileKey),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _selectedNavIndex,
            builder: (context, index, _) => BottomNav(
              selectedNavIndex: index,
              onNavTap: _onNavTap,
              avatarUrl: AuthSession.instance.user?.profilePhotoUrl,
            ),
          ),
        ],
      ),
    );
  }
}

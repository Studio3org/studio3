import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'screens/event_page.dart';
import 'screens/my_events_page.dart';
import 'screens/my_reports_page.dart';
import 'screens/payout_setup_page.dart';
import 'services/push_router_service.dart';
import 'utils/open_at_top_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/stripe_setup.dart';
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
import 'services/theme_service.dart';
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
import 'screens/terms_page.dart';
import 'screens/debug/studio_gallery_page.dart';
import 'models/auth_user.dart';
import 'models/feed_item.dart';
import 'theme/home_feed_tokens.dart';
import 'utils/scrolls_to_top_on_double_tap.dart';
import 'utils/snappy_page_physics.dart';
import 'utils/require_login.dart';
import 'widgets/terms_acceptance_dialog.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keeps the native/web launch splash on screen through the async setup below — without
  // this the generated splash never gets its removal signal on web.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load(fileName: '.env');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await AuthSession.instance.initialize();
  await ThemeService.instance.initialize();
  await CacheService.instance.init();
  await AppStateStore.instance.initialize();
  await SavedContentStore.instance.load();
  await ConnectivityService.instance.init();
  await StripeSetup.init();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase unavailable (no config yet?): $e');
  }
  await _loadBundledFonts();
  FlutterNativeSplash.remove();
  runApp(const Studio3App());
}

/// Loads every Inter/Geist weight the app uses from the asset bundle
/// (`assets/google_fonts/`) before the first frame paints, so no text waits on the network
/// and a first use of a weight never paints in a fallback font with different metrics.
/// Runtime fetching is off so a weight that isn't bundled shows up in debug instead of
/// quietly going back to downloading (restored from before commit 76f4ef9).
Future<void> _loadBundledFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  try {
    for (final weight in const [
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.inter(fontWeight: weight);
      GoogleFonts.geist(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  } catch (e) {
    debugPrint('Bundled font load failed: $e');
  }
}



class Studio3App extends StatelessWidget {
  const Studio3App({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: ThemeService.instance.overlay,
          child: MaterialApp(
            title: 'Studio 3 Discover',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeService.instance.mode,
            initialRoute: resolveInitialRoute(),
            navigatorObservers: [routeObserver, OpenAtTopObserver()],
            // An emoji fallback for any Text with no style of its own (AppTheme.emojiFallback).
            builder: (context, child) => DefaultTextStyle.merge(
              style: const TextStyle(fontFamilyFallback: AppTheme.emojiFallback),
              child: child!,
            ),
            routes: {
              '/': (context) => const AuthGate(
                    child: MainShell(),
                  ),
              '/login': (context) => const LoginPage(),
              '/signup': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return SignUpPage(initialEmail: args is String ? args : null);
              },
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
              '/terms': (context) => const TermsPage(),
              '/payout-setup': (context) => const PayoutSetupPage(),
              '/my-reports': (context) => const MyReportsPage(),
              '/my-events': (context) => const MyEventsPage(),
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
              // New-UI component gallery; debug builds only.
              if (kDebugMode)
                StudioGalleryPage.routeName: (context) => const StudioGalleryPage(),
            },
          ),
        );
      },
    );
  }
}

/// Sends anyone signed out to sign-in ([kAccountRequired]; without it, guests browse and only a
/// session that just ended goes back to /login), routes non-onboarded accounts to onboarding,
/// and makes accounts agree to the current Terms of Use.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _deviceRegistered = false;
  late bool _wasLoggedIn = AuthSession.instance.isLoggedIn;
  bool _termsPromptOpen = false;

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
    PushRouterService.instance.dispose();
    super.dispose();
  }

  void _onSessionChanged() => _checkAuth();

  void _checkAuth() {
    if (!mounted) return;
    final session = AuthSession.instance;
    if (session.isLoggedIn && !_deviceRegistered) {
      _deviceRegistered = true;
      // Permission first, registration second — on iOS, asking APNs for a token before
      // the user allows notifications returns null, so the device stayed unregistered
      // until the second launch.
      PermissionService.instance.requestNotifications().whenComplete(() {
        DeviceService.instance.registerCurrentDevice();
      });
      PushRouterService.instance.start(context);
      ChatSocketService.instance.connect();
      ConnectivityService.instance.addReconnectHook(() async {
        ChatSocketService.instance.connect();
      });
    }
    if (!session.isLoggedIn) {
      _deviceRegistered = false;
      ChatSocketService.instance.disconnect();
      // An account is required, so signed out always means sign-in. Without that rule,
      // starting signed out is a guest browsing, and only a session that ends while the app
      // is open (logout, revoked refresh token, account deletion) goes back to sign-in.
      if (kAccountRequired || _wasLoggedIn) {
        _wasLoggedIn = false;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
      return;
    }
    _wasLoggedIn = true;
    if (session.isOnboarded &&
        (session.user?.needsTermsAcceptance ?? false) &&
        !_termsPromptOpen) {
      _termsPromptOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showTermsAcceptanceDialog(context);
        _termsPromptOpen = false;
      });
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
  static const _kEventPage = 4;

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
  late final ValueNotifier<bool> _reelsActive = ValueNotifier(false);
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
  final GlobalKey<State<StatefulWidget>> _eventKey = GlobalKey();
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
    EventPage(key: _eventKey),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_onSessionChanged);
    _selectedNavIndex.addListener(_onNavIndexChanged);
    ReelsTabService.instance.register(_openReelsTab);
    MainNavService.instance.register(
      goHome: _goHome,
      goSaved: _goSaved,
      goExplore: _goExplore,
    );
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
    _showReelsPage();
  }

  void _showReelsPage() {
    _showProfile.value = false;
    _currentPage = _kReelsPage;
    _reelsActive.value = true;
    _selectedNavIndex.value = BottomNavIndex.none;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_kReelsPage);
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _onNavTap(BottomNavIndex.home);
  }

  void _goExplore() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _onNavTap(BottomNavIndex.explore);
  }

  void _goSaved() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _showProfile.value = false;
    _currentPage = _kSavedPage;
    _reelsActive.value = false;
    _selectedNavIndex.value = BottomNavIndex.none;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_kSavedPage);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AppStateStore.instance.saveNavIndex(_selectedNavIndex.value);
    }
  }

  void _onNavIndexChanged() {
    _reelsActive.value = _currentPage == _kReelsPage &&
        !_showProfile.value &&
        _selectedNavIndex.value == BottomNavIndex.none;
  }

  void _onSessionChanged() {
    // Only the avatar (read directly by BottomNav's ValueListenableBuilder
    // below) needs to react to session changes — no setState here avoids
    // rebuilding the whole shell (and therefore every const-canonicalized
    // page reference) for an avatar URL update.
    if (mounted) setState(() {});
  }

  Future<void> _loadProfilePhoto() async {
    if (!AuthSession.instance.isLoggedIn) return;
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
        return BottomNavIndex.explore;
      case _kEventPage:
        return BottomNavIndex.events;
      default:
        return BottomNavIndex.none;
    }
  }

  void _onPageChanged(int page) {
    // Covers swipe-to-switch too, not just bottom-nav taps (see _onNavTap).
    FocusManager.instance.primaryFocus?.unfocus();
    _currentPage = page;
    _reelsActive.value = page == _kReelsPage;
    final navIndex = _navIndexForPage(page);
    _selectedNavIndex.value = navIndex;
    AppStateStore.instance.saveNavIndex(navIndex);
  }

  Future<void> _openPost() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to post',
      message: 'Enter your email to join. Log in if you already have an account.',
    )) {
      return;
    }
    if (mounted) Navigator.pushNamed(context, '/post');
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

    if (navIndex == BottomNavIndex.post) {
      _openPost();
      return;
    }

    if (navIndex == BottomNavIndex.profile) {
      if (!AuthSession.instance.isLoggedIn) {
        requireLogin(
          context,
          title: 'Sign in to set up your profile',
          message: 'Enter your email to join. Log in if you already have an account.',
        );
        return;
      }
      _showProfile.value = true;
      _selectedNavIndex.value = BottomNavIndex.profile;
      AppStateStore.instance.saveNavIndex(navIndex);
      _loadProfilePhoto();
      return;
    }
    _showProfile.value = false;
    final targetPage = switch (navIndex) {
      BottomNavIndex.home => _kHomePage,
      BottomNavIndex.explore => _kDiscoverPage,
      BottomNavIndex.events => _kEventPage,
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
      BottomNavIndex.explore => _exploreKey,
      BottomNavIndex.events => _eventKey,
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
          // Guests have no own profile to keep mounted (tapping the avatar
          // asks them to log in instead), and signing in replaces this whole
          // shell, so it's safe to decide this once per build.
          if (AuthSession.instance.isLoggedIn)
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

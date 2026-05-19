import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/folder/folder_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/add_item/add_item_sheet.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../models/category.dart';
import '../utils/haptics.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// Cached synchronously after await initRouter() in main.dart
bool _hasSeenOnboarding = false;

Future<void> initRouter() async {
  final prefs = await SharedPreferences.getInstance();
  _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
}

// Call this before navigating away from onboarding so the redirect allows /login
void markOnboardingComplete() {
  _hasSeenOnboarding = true;
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuth = user != null;
    final path = state.matchedLocation;
    final isAuthRoute = path == '/login' || path == '/signup';
    final isOnboarding = path == '/onboarding';

    // First-time users → onboarding before anything else
    if (!_hasSeenOnboarding && !isOnboarding) return '/onboarding';

    // Onboarding done, not logged in → login
    if (!isAuth && !isAuthRoute && !isOnboarding) return '/login';

    // Already logged in → home
    if (isAuth && (isAuthRoute || isOnboarding)) return '/';

    return null;
  },
  routes: [
    // Onboarding (outside shell — no bottom nav)
    GoRoute(
      path: '/onboarding',
      builder: (c, s) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login',  builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),

    // Main shell with bottom nav
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(
        location: state.matchedLocation,
        child: child,
      ),
      routes: [
        GoRoute(path: '/',        builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/search',  builder: (c, s) => const SearchScreen()),
        GoRoute(path: '/folders', builder: (c, s) => const FolderListScreen()),
        GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        GoRoute(
          path: '/folder/:id',
          builder: (c, s) {
            final cat = s.extra as Category?;
            return FolderScreen(
              category: cat,
              categoryId: s.pathParameters['id']!,
            );
          },
        ),
      ],
    ),
  ],
);

class MainShell extends StatelessWidget {
  final String location;
  final Widget child;

  const MainShell({super.key, required this.location, required this.child});

  int get _currentIndex {
    if (location == '/') return 0;
    if (location == '/search') return 1;
    if (location.startsWith('/folder')) return 3;
    if (location == '/folders') return 3;
    if (location == '/profile') return 4;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    Haptics.tap();
    switch (index) {
      case 0: context.go('/');
      case 1: context.go('/search');
      case 2: _showAdd(context);
      case 3: context.go('/folders');
      case 4: context.go('/profile');
    }
  }

  void _showAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E0),
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavIcon(Icons.home_outlined, Icons.home, 0, _currentIndex, (i) => _onTap(i, context), isDark),
                _NavIcon(Icons.search_outlined, Icons.search, 1, _currentIndex, (i) => _onTap(i, context), isDark),
                _FabBtn(() => _onTap(2, context)),
                _NavIcon(Icons.folder_outlined, Icons.folder, 3, _currentIndex, (i) => _onTap(i, context), isDark),
                _NavIcon(Icons.person_outline, Icons.person, 4, _currentIndex, (i) => _onTap(i, context), isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData outline;
  final IconData filled;
  final int index;
  final int current;
  final Function(int) onTap;
  final bool isDark;

  const _NavIcon(this.outline, this.filled, this.index, this.current, this.onTap, this.isDark);

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Center(
          child: Icon(
            isSelected ? filled : outline,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                : const Color(0xFFB0B0B0),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _FabBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _FabBtn(this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/share_service.dart';
import 'core/utils/haptics.dart';
import 'features/share/share_progress_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await Haptics.load();

  // Load onboarding state before router starts
  await initRouter();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const StashApp(),
    ),
  );
}

class StashApp extends StatefulWidget {
  const StashApp({super.key});

  @override
  State<StashApp> createState() => _StashAppState();
}

class _StashAppState extends State<StashApp> {
  bool _shareCardOpen = false;

  @override
  void initState() {
    super.initState();
    ShareService.init();
    ShareService.onShareReceived = _onShare;
  }

  @override
  void dispose() {
    ShareService.onShareReceived = null;
    ShareService.dispose();
    super.dispose();
  }

  void _onShare(SharePayload payload) {
    void present() {
      final nav = rootNavigatorKey.currentState;
      if (nav == null) {
        // Navigator not ready yet (cold start) — retry next frame.
        WidgetsBinding.instance.addPostFrameCallback((_) => present());
        return;
      }
      if (_shareCardOpen) return;
      _shareCardOpen = true;
      nav
          .push(PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.transparent,
            pageBuilder: (_, __, ___) =>
                ShareProgressScreen(payload: payload),
          ))
          .then((_) => _shareCardOpen = false);
    }

    present();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'Stashh',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

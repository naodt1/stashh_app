import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/share_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

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
  @override
  void initState() {
    super.initState();
    ShareService.init();
  }

  @override
  void dispose() {
    ShareService.dispose();
    super.dispose();
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

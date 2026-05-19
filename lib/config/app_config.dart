import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  /// Public health URL of the yt-dlp service. Pinged when the add/share
  /// sheet opens so the (free-tier) container is warm by the time we
  /// actually need it. Optional — empty disables pre-warming.
  static String get ytdlpHealthUrl => dotenv.env['YTDLP_HEALTH_URL'] ?? '';
}

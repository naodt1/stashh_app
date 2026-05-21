import 'package:supabase_flutter/supabase_flutter.dart';

/// The 15 broad buckets every saved item is forced into (exactly one).
const kPrimaryCategories = <String>[
  'Fitness & Workouts',
  'Sports',
  'Recipes & Cooking',
  'Finance & Money',
  'Self-Improvement / Motivation',
  'Fashion & Beauty',
  'Tech & Gadgets',
  'Education / Tutorials',
  'Comedy / Memes',
  'Edits',
  'Animals & Pets',
  'Travel',
  'Home & DIY',
  'Health & Wellness',
  'Business & Entrepreneurship',
  'Entertainment',
  'News & Current Events',
  'Other / Miscellaneous',
];

const kMoods = ['Motivational', 'Relaxing', 'Intense', 'Funny', 'Informative', 'Emotional'];
const kIntents = ['Learn', 'Inspire', 'Entertain', 'Shop', 'Remember', 'Humor'];
const kSkillLevels = ['Beginner', 'Intermediate', 'Advanced'];
const kVisualStyles = ['Talking Head', 'Text-heavy', 'ASMR', 'Cinematic', 'Screen Recording', 'Unknown'];
const kCreatorTypes = ['Influencer', 'Expert', 'Brand', 'Friend', 'Unknown'];

/// Rich multi-dimensional AI analysis of a saved item.
class AiCategorization {
  // Primary bucket (one of kPrimaryCategories)
  final String primaryCategory;

  // Display metadata
  final String title;
  final String description;
  final String contentType; // link | video | image | text | document

  // Secondary multi-label dimensions
  final String lengthBucket; // short | medium | long | unknown
  final List<String> mood;
  final List<String> intent;
  final String? skillLevel;
  final String visualStyle;
  final String creatorType;
  final String language; // e.g. "English", "Spanish"

  // Advanced layers
  final List<String> topics; // semantic/transcription topics
  final List<String> tags; // general free-form tags

  AiCategorization({
    required this.primaryCategory,
    required this.title,
    required this.description,
    required this.contentType,
    required this.lengthBucket,
    required this.mood,
    required this.intent,
    required this.skillLevel,
    required this.visualStyle,
    required this.creatorType,
    required this.language,
    required this.topics,
    required this.tags,
  });

  factory AiCategorization.fromJson(Map<String, dynamic> j) {
    List<String> arr(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : <String>[];

    var primary = (j['primary_category'] as String?)?.trim() ?? 'Other / Miscellaneous';
    if (!kPrimaryCategories.contains(primary)) {
      // snap to closest valid bucket, else Other
      primary = kPrimaryCategories.firstWhere(
        (c) => c.toLowerCase() == primary.toLowerCase(),
        orElse: () => 'Other / Miscellaneous',
      );
    }

    return AiCategorization(
      primaryCategory: primary,
      title: (j['title'] as String?)?.trim().isNotEmpty == true
          ? (j['title'] as String).trim()
          : 'Untitled',
      description: (j['description'] as String?)?.trim() ?? '',
      contentType: (j['content_type'] as String?)?.trim() ?? 'link',
      lengthBucket: (j['length_bucket'] as String?)?.trim() ?? 'unknown',
      mood: arr(j['mood']).where(kMoods.contains).toList(),
      intent: arr(j['intent']).where(kIntents.contains).toList(),
      skillLevel: kSkillLevels.contains(j['skill_level'])
          ? j['skill_level'] as String
          : null,
      visualStyle: kVisualStyles.contains(j['visual_style'])
          ? j['visual_style'] as String
          : 'Unknown',
      creatorType: kCreatorTypes.contains(j['creator_type'])
          ? j['creator_type'] as String
          : 'Unknown',
      language: (j['language'] as String?)?.trim().isNotEmpty == true
          ? (j['language'] as String).trim()
          : 'Unknown',
      topics: arr(j['topics']).take(8).toList(),
      tags: arr(j['tags']).take(8).toList(),
    );
  }

  /// Bucket a known duration (seconds) into short/medium/long.
  static String lengthFromSeconds(num? secs) {
    if (secs == null || secs <= 0) return 'unknown';
    if (secs < 60) return 'short';
    if (secs <= 600) return 'medium';
    return 'long';
  }
}

/// Cross-platform AI client. Calls the `ai-categorize` Supabase Edge
/// Function so the OpenAI key stays server-side — works identically on
/// Android, iOS and web (no CORS, no key in the client bundle).
class AiService {
  static final _fn = Supabase.instance.client.functions;

  /// Analyzes a saved item across every dimension in one structured call.
  /// [durationSeconds] (from yt-dlp/metadata) overrides the AI length guess.
  static Future<AiCategorization?> categorize(
    String text, {
    num? durationSeconds,
  }) async {
    if (text.trim().isEmpty) return null;
    try {
      final res = await _fn.invoke(
        'ai-categorize',
        body: {'action': 'categorize', 'text': text},
      );
      final data = res.data;
      if (data is! Map || data['error'] != null) return null;

      final result =
          AiCategorization.fromJson(Map<String, dynamic>.from(data));

      // Authoritative duration beats the model's guess.
      if (durationSeconds != null && durationSeconds > 0) {
        final bucketed = AiCategorization.lengthFromSeconds(durationSeconds);
        if (bucketed != result.lengthBucket) {
          return AiCategorization(
            primaryCategory: result.primaryCategory,
            title: result.title,
            description: result.description,
            contentType: result.contentType,
            lengthBucket: bucketed,
            mood: result.mood,
            intent: result.intent,
            skillLevel: result.skillLevel,
            visualStyle: result.visualStyle,
            creatorType: result.creatorType,
            language: result.language,
            topics: result.topics,
            tags: result.tags,
          );
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// 1536-dim embedding for semantic search. Null on failure → callers
  /// degrade to keyword search.
  static Future<List<double>?> embed(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final res = await _fn.invoke(
        'ai-categorize',
        body: {'action': 'embed', 'text': text},
      );
      final data = res.data;
      if (data is! Map || data['embedding'] is! List) return null;
      return (data['embedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      return null;
    }
  }
}

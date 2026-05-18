import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

/// The 15 broad buckets every saved item is forced into (exactly one).
const kPrimaryCategories = <String>[
  'Fitness & Workouts',
  'Recipes & Cooking',
  'Finance & Money',
  'Self-Improvement / Motivation',
  'Fashion & Beauty',
  'Tech & Gadgets',
  'Education / Tutorials',
  'Comedy / Memes',
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

class AiService {
  /// Analyzes a saved item across every dimension in one structured call.
  ///
  /// [text] should be the richest signal available — ideally
  /// "title — description — transcript — url". [durationSeconds] (when known
  /// from yt-dlp/metadata) overrides the AI's length guess.
  static Future<AiCategorization?> categorize(
    String text, {
    num? durationSeconds,
  }) async {
    final apiKey = AppConfig.openAiApiKey;
    if (apiKey.isEmpty || apiKey == 'your-openai-key' || text.trim().isEmpty) {
      return null;
    }

    final system = '''
You are a precise content-cataloguing AI for a personal "second brain" app.
Given whatever signal is available about a saved video/link/note (title,
description, transcript snippets, URL, creator handle), return ONLY a JSON
object with EXACTLY these keys:

{
  "primary_category": one of ${jsonEncode(kPrimaryCategories)},
  "title": short human title (<= 80 chars, no hashtags/emoji spam),
  "description": one concise sentence describing what it is,
  "content_type": one of ["link","video","image","text","document"],
  "length_bucket": one of ["short","medium","long","unknown"],
  "mood": subset of ${jsonEncode(kMoods)},
  "intent": subset of ${jsonEncode(kIntents)},
  "skill_level": one of ["Beginner","Intermediate","Advanced"] or null,
  "visual_style": one of ${jsonEncode(kVisualStyles)},
  "creator_type": one of ${jsonEncode(kCreatorTypes)},
  "language": the human language of the content (e.g. "English"),
  "topics": 2-6 specific semantic topics (e.g. "high-protein meals","stoic philosophy"),
  "tags": 3-6 short lowercase keywords
}

Rules:
- primary_category MUST be one of the listed values, never invent one.
- Pick the single best primary_category even if ambiguous.
- mood/intent are MULTI-label arrays; pick all that genuinely apply (>=1).
- Infer skill_level only for instructional content, else null.
- Be specific in topics — they power semantic search.
- Output strictly valid JSON, no markdown, no commentary.
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'max_tokens': 700,
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': 'Analyze and catalogue this:\n$text'},
          ],
        }),
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final raw = body['choices'][0]['message']['content'] as String;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final result = AiCategorization.fromJson(json);

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

  /// Generates a 1536-dim embedding (text-embedding-3-small) for semantic
  /// search. Returns null on any failure so callers degrade to keyword.
  static Future<List<double>?> embed(String text) async {
    final apiKey = AppConfig.openAiApiKey;
    if (apiKey.isEmpty || apiKey == 'your-openai-key' || text.trim().isEmpty) {
      return null;
    }
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/embeddings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'text-embedding-3-small',
          'input': text.length > 8000 ? text.substring(0, 8000) : text,
        }),
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      final emb = body['data'][0]['embedding'] as List;
      return emb.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }
}

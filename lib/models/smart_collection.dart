import 'package:flutter/material.dart';
import '../core/services/supabase_service.dart';
import 'stash_item.dart';

/// A Smart Collection is a named, auto-updating query spec — not a folder.
/// Items can appear in many collections at once because membership is
/// computed live from the AI dimensions, never stored.
class SmartCollection {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  // Query spec (mirrors SupabaseService.queryItems)
  final String? primaryCategory;
  final String? lengthBucket;
  final String? skillLevel;
  final List<String>? moods;
  final List<String>? intents;
  final List<String>? topics;
  final int? sinceDays;
  final int limit;

  const SmartCollection({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.primaryCategory,
    this.lengthBucket,
    this.skillLevel,
    this.moods,
    this.intents,
    this.topics,
    this.sinceDays,
    this.limit = 50,
  });

  Future<List<StashItem>> resolve() => SupabaseService.queryItems(
        primaryCategory: primaryCategory,
        lengthBucket: lengthBucket,
        skillLevel: skillLevel,
        moods: moods,
        intents: intents,
        topics: topics,
        sinceDays: sinceDays,
        limit: limit,
      );
}

/// Resolves which Smart Collections currently have matching items.
/// Returns id → item count, ONLY for non-empty collections, so the UI
/// can hide collections the AI hasn't populated yet (empty by default).
Future<Map<String, int>> resolveActiveSmartCollections() async {
  final counts = <String, int>{};
  for (final c in kSmartCollections) {
    try {
      final items = await c.resolve();
      if (items.isNotEmpty) counts[c.id] = items.length;
    } catch (_) {
      // ignore — collection simply won't show
    }
  }
  return counts;
}

/// The catalogue of possible AI smart folders. None are shown until the
/// user saves something the AI classifies into them.
const kSmartCollections = <SmartCollection>[
  SmartCollection(
    id: 'recently_saved',
    name: 'Recently Saved',
    subtitle: 'Last 7 days',
    icon: Icons.schedule,
    sinceDays: 7,
  ),
  SmartCollection(
    id: 'watch_next',
    name: 'Watch Next',
    subtitle: 'Recent videos to catch up on',
    icon: Icons.play_circle_outline,
    sinceDays: 30,
    limit: 20,
  ),
  SmartCollection(
    id: 'morning_motivation',
    name: 'Morning Motivation',
    subtitle: 'Motivational & inspiring',
    icon: Icons.wb_sunny_outlined,
    moods: ['Motivational'],
    intents: ['Inspire'],
  ),
  SmartCollection(
    id: 'quick_recipes',
    name: 'Quick Recipes Under 15min',
    subtitle: 'Short & medium cooking clips',
    icon: Icons.restaurant_outlined,
    primaryCategory: 'Recipes & Cooking',
    lengthBucket: 'short',
  ),
  SmartCollection(
    id: 'finance_tips',
    name: 'High-Value Finance Tips',
    subtitle: 'Money lessons worth keeping',
    icon: Icons.account_balance_wallet_outlined,
    primaryCategory: 'Finance & Money',
    intents: ['Learn'],
  ),
  SmartCollection(
    id: 'quick_workouts',
    name: 'Quick Workouts',
    subtitle: 'Short fitness sessions',
    icon: Icons.fitness_center_outlined,
    primaryCategory: 'Fitness & Workouts',
    lengthBucket: 'short',
  ),
  SmartCollection(
    id: 'learn_tutorials',
    name: 'Learn Something',
    subtitle: 'Tutorials & how-tos',
    icon: Icons.school_outlined,
    primaryCategory: 'Education / Tutorials',
    intents: ['Learn'],
  ),
];

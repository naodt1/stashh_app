import 'supabase_service.dart';
import 'settings_service.dart';

/// An AI-detected cluster of un-filed items that share a theme — the
/// app proposes turning it into a folder.
class ClusterSuggestion {
  final String key; // stable id for dismissal
  final String suggestedName; // proposed folder name
  final int count;
  final List<String> itemIds;

  ClusterSuggestion({
    required this.key,
    required this.suggestedName,
    required this.count,
    required this.itemIds,
  });
}

class ClusterService {
  /// Minimum un-filed items sharing a theme before we suggest a folder.
  static const _threshold = 4;

  /// Looks at items that aren't in a folder yet, finds the strongest
  /// shared theme (topic → tag → primary category, most specific first)
  /// and proposes a folder. Returns null if nothing qualifies or the
  /// suggestion was dismissed.
  static Future<ClusterSuggestion?> detect() async {
    final items = await SupabaseService.getUncategorizedItems(limit: 200);
    if (items.length < _threshold) return null;

    final dismissed = await SettingsService.getDismissedClusters();
    final existing = (await SupabaseService.getCategories())
        .map((c) => c.name.toLowerCase())
        .toSet();

    // Tally each signal → set of item ids.
    final byTheme = <String, Set<String>>{};
    for (final it in items) {
      for (final t in it.topics) {
        (byTheme['topic::${t.toLowerCase()}'] ??= {}).add(it.id);
      }
      for (final t in it.tags) {
        (byTheme['tag::${t.toLowerCase()}'] ??= {}).add(it.id);
      }
      if (it.primaryCategory != null) {
        (byTheme['cat::${it.primaryCategory!.toLowerCase()}'] ??= {})
            .add(it.id);
      }
    }

    // Best qualifying theme: highest count, prefer topic > tag > cat.
    int rank(String k) =>
        k.startsWith('topic::') ? 3 : (k.startsWith('tag::') ? 2 : 1);

    MapEntry<String, Set<String>>? best;
    for (final e in byTheme.entries) {
      if (e.value.length < _threshold) continue;
      final label = e.key.split('::').last;
      if (existing.contains(label)) continue;
      if (dismissed.contains(e.key)) continue;
      if (best == null ||
          e.value.length > best.value.length ||
          (e.value.length == best.value.length &&
              rank(e.key) > rank(best.key))) {
        best = e;
      }
    }
    if (best == null) return null;

    final raw = best.key.split('::').last;
    final name = raw
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');

    return ClusterSuggestion(
      key: best.key,
      suggestedName: name,
      count: best.value.length,
      itemIds: best.value.toList(),
    );
  }
}

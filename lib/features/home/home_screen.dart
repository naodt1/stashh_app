import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stash_item.dart';
import '../../models/profile.dart';
import '../add_item/add_item_sheet.dart';
import '../shared/stash_item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Profile? _profile;
  List<StashItem> _recentItems = [];
  Map<String, int> _typeCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getRecentItems(limit: 8),
        SupabaseService.getItems(limit: 200),
      ]);
      final profile = results[0] as Profile?;
      final recent = results[1] as List<StashItem>;
      final all = results[2] as List<StashItem>;

      final Map<String, int> counts = {};
      for (final item in all) {
        counts[item.contentType] = (counts[item.contentType] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _recentItems = recent;
          _typeCounts = counts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemSheet(),
    ).then((saved) {
      if (saved == true) _load();
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final full = _profile?.fullName ??
        SupabaseService.currentUser?.userMetadata?['full_name'] ??
        'there';
    return full.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sort type counts descending for carousel
    final sortedTypes = _typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.black,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  _firstName,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : AppTheme.grey100,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3A3A3A)
                                      : AppTheme.grey200,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _firstName.isNotEmpty
                                      ? _firstName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 20),

                      // Search bar
                      GestureDetector(
                        onTap: () => context.go('/search'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1A1A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : AppTheme.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  color: AppTheme.textSecondary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Search your library...',
                                style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 24),

                      // Section header: Recent
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/search'),
                            style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: Text(
                              'See all',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            // ── Recent items ────────────────────────────────────────────────
            _loading
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: List.generate(
                          4,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ItemShimmer(isDark: isDark),
                          ),
                        ),
                      ),
                    ),
                  )
                : _recentItems.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _EmptyItems(onAdd: _openAdd, isDark: isDark),
                        ),
                      )
                    : SliverPadding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              if (i >= _recentItems.length) return null;
                              final item = _recentItems[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: StashItemCard(
                                  item: item,
                                  isDark: isDark,
                                  onDeleted: _load,
                                  onTogglePin: () async {
                                    await SupabaseService.updateItem(
                                      item.id,
                                      {'is_pinned': !item.isPinned},
                                    );
                                    _load();
                                  },
                                ).animate().fadeIn(
                                    delay: Duration(
                                        milliseconds: 250 + i * 40)),
                              );
                            },
                            childCount: _recentItems.length,
                          ),
                        ),
                      ),

            // ── By Type carousel ────────────────────────────────────────────
            if (!_loading && sortedTypes.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'By Type',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sortedTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final entry = sortedTypes[i];
                      return _TypeCard(
                        type: entry.key,
                        count: entry.value,
                        isDark: isDark,
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: 320 + i * 50));
                    },
                  ),
                ),
              ),
            ],

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Type card (carousel item) ────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final String type;
  final int count;
  final bool isDark;

  const _TypeCard({
    required this.type,
    required this.count,
    required this.isDark,
  });

  IconData get _icon {
    switch (type) {
      case 'video':    return Icons.play_circle_outline;
      case 'image':    return Icons.image_outlined;
      case 'text':     return Icons.notes;
      case 'document': return Icons.description_outlined;
      default:         return Icons.link;
    }
  }

  String get _label {
    switch (type) {
      case 'video':    return 'Videos';
      case 'image':    return 'Images';
      case 'text':     return 'Notes';
      case 'document': return 'Docs';
      default:         return 'Links';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final border = isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder;
    final iconBg = isDark ? const Color(0xFF2A2A2A) : AppTheme.grey100;
    final iconColor = isDark ? AppTheme.grey300 : AppTheme.grey700;

    return Container(
      width: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 16, color: iconColor),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              Text(
                _label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shimmer / empty states ───────────────────────────────────────────────────

class _ItemShimmer extends StatelessWidget {
  final bool isDark;
  const _ItemShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder),
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isDark;

  const _EmptyItems({required this.onAdd, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48,
              color: isDark ? AppTheme.grey500 : AppTheme.grey300),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start saving links, notes, and ideas\nto build your second brain.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add First Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

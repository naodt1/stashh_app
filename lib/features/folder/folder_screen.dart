import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/cluster_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stash_item.dart';
import '../../models/category.dart';
import '../../models/smart_collection.dart';
import '../../models/collection.dart';
import '../add_item/add_item_sheet.dart';
import '../collection/collection_screen.dart';
import '../collection/user_collection_screen.dart';
import '../shared/stash_item_card.dart';

// Maps a category name to a Material icon. Uses substring matching so
// full AI bucket names like "Fitness & Workouts" or user folders both work.
IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('fitness') || n.contains('gym') || n.contains('workout')) {
    return Icons.fitness_center_outlined;
  }
  if (n.contains('sport')) return Icons.sports_soccer_outlined;
  if (n.contains('recipe') || n.contains('cook') || n.contains('food')) {
    return Icons.restaurant_outlined;
  }
  if (n.contains('finance') || n.contains('money')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (n.contains('self-improvement') || n.contains('motivation') ||
      n.contains('inspiration')) {
    return Icons.lightbulb_outline;
  }
  if (n.contains('fashion') || n.contains('beauty')) {
    return Icons.checkroom_outlined;
  }
  if (n.contains('tech') || n.contains('gadget')) {
    return Icons.memory_outlined;
  }
  if (n.contains('education') || n.contains('tutorial') ||
      n.contains('learn')) {
    return Icons.school_outlined;
  }
  if (n.contains('comedy') || n.contains('meme') || n.contains('funny')) {
    return Icons.sentiment_very_satisfied_outlined;
  }
  if (n.contains('edit')) return Icons.movie_filter_outlined;
  if (n.contains('animal') || n.contains('pet')) return Icons.pets;
  if (n.contains('travel')) return Icons.flight_outlined;
  if (n.contains('home') || n.contains('diy')) return Icons.home_outlined;
  if (n.contains('health') || n.contains('wellness')) {
    return Icons.favorite_outline;
  }
  if (n.contains('business') || n.contains('entrepreneur') ||
      n.contains('work')) {
    return Icons.work_outline;
  }
  if (n.contains('entertainment')) return Icons.movie_outlined;
  if (n.contains('news')) return Icons.newspaper_outlined;
  if (n.contains('reading') || n.contains('books')) {
    return Icons.menu_book_outlined;
  }
  if (n.contains('music')) return Icons.music_note_outlined;
  if (n.contains('art') || n.contains('design')) {
    return Icons.palette_outlined;
  }
  if (n.contains('gaming') || n.contains('game')) {
    return Icons.sports_esports_outlined;
  }
  if (n.contains('shopping')) return Icons.shopping_bag_outlined;
  if (n.contains('social')) return Icons.people_outline;
  if (n.contains('nature')) return Icons.eco_outlined;
  if (n.contains('science')) return Icons.science_outlined;
  return Icons.folder_outlined;
}

class FolderListScreen extends StatelessWidget {
  const FolderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FolderScreen(categoryId: null);
  }
}

class FolderScreen extends StatefulWidget {
  final String? categoryId;
  final Category? category;

  const FolderScreen({
    super.key,
    required this.categoryId,
    this.category,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<Category> _categories = [];
  List<Collection> _collections = [];
  List<StashItem> _items = [];
  Map<String, int> _smartCounts = {};
  Map<String, int> _counts = {};
  ClusterSuggestion? _suggestion;
  bool _loading = true;

  bool get _isDetail => widget.categoryId != null;
  Category? _currentCategory;

  // Only Smart Collections the AI has actually populated (≥1 item)
  List<SmartCollection> get _activeSmart => kSmartCollections
      .where((c) => _smartCounts.containsKey(c.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.category;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_isDetail) {
        final items =
            await SupabaseService.getItems(categoryId: widget.categoryId);
        if (mounted) setState(() { _items = items; _loading = false; });
      } else {
        final cats = await SupabaseService.getCategories();
        final cols = await SupabaseService.getCollections();
        final smart = await resolveActiveSmartCollections();
        final counts = await SupabaseService.getCategoryCounts();
        final suggestion = await ClusterService.detect();
        if (mounted) {
          setState(() {
            _categories = cats;
            _collections = cols;
            _smartCounts = smart;
            _counts = counts;
            _suggestion = suggestion;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCollection() async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Collection',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Collection name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.black,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await SupabaseService.createCollection(name);
    _load();
  }

  void _openAddItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddItemSheet(initialCategoryId: widget.categoryId),
    ).then((saved) { if (saved == true) _load(); });
  }

  void _showCreateFolder() {
    final nameCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Folder',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            prefixIcon: const Icon(Icons.folder_outlined,
                color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final user = SupabaseService.currentUser;
              if (user == null) return;
              await SupabaseService.createCategory({
                'id': const Uuid().v4(),
                'user_id': user.id,
                'name': name,
                'icon': 'folder',   // plain string, UI uses _categoryIcon()
                'color': '#000000',
                'item_count': 0,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : AppTheme.black,
              foregroundColor: isDark ? AppTheme.black : Colors.white,
              elevation: 0,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isDetail) return _buildDetailView(isDark);
    return _buildListView(isDark);
  }

  Widget _buildDetailView(bool isDark) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/folders'),
        ),
        title: Row(
          children: [
            Icon(
              _categoryIcon(_currentCategory?.name ?? ''),
              size: 20,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              _currentCategory?.name ?? 'Folder',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddItem,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: AppTheme.textSecondary))
          : _items.isEmpty
              ? _buildEmptyDetail(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    return StashItemCard(
                      item: _items[i],
                      isDark: isDark,
                      onDeleted: _load,
                      onTogglePin: () async {
                        await SupabaseService.updateItem(
                          _items[i].id,
                          {'is_pinned': !_items[i].isPinned},
                        );
                        _load();
                      },
                    ).animate().fadeIn(
                        delay: Duration(milliseconds: i * 40));
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddItem,
        backgroundColor: isDark ? Colors.white : AppTheme.black,
        child: Icon(Icons.add,
            color: isDark ? AppTheme.black : Colors.white),
      ),
    );
  }

  Widget _buildEmptyDetail(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _categoryIcon(_currentCategory?.name ?? ''),
              size: 56,
              color: isDark ? AppTheme.grey500 : AppTheme.grey300,
            ),
            const SizedBox(height: 20),
            Text(
              'Empty folder',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add items to this folder',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFromSuggestion(ClusterSuggestion s) async {
    final id = await SupabaseService.getOrCreateCategory(s.suggestedName);
    if (id != null) {
      await SupabaseService.assignItemsToCategory(s.itemIds, id);
    }
    if (mounted) setState(() => _suggestion = null);
    _load();
  }

  Future<void> _dismissSuggestion(ClusterSuggestion s) async {
    await SettingsService.dismissCluster(s.key);
    if (mounted) setState(() => _suggestion = null);
  }

  void _folderActions(Category cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                cat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
              title: Text(cat.pinned ? 'Unpin folder' : 'Pin folder',
                  style: GoogleFonts.spaceGrotesk(
                      color: isDark ? Colors.white : AppTheme.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                await SupabaseService.setCategoryPinned(
                    cat.id, !cat.pinned);
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete folder',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await SupabaseService.deleteCategory(cat.id);
                _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder;
    final iconColor = isDark ? AppTheme.grey300 : AppTheme.grey700;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    int countFor(Category c) => _counts[c.id] ?? c.itemCount;
    // Always show user-made folders; only hide AI-auto-filed ones when empty.
    final visible = _categories
        .where((c) => !c.autoCreated || countFor(c) > 0)
        .toList();
    final pinned = visible.where((c) => c.pinned).toList();
    final rest = visible.where((c) => !c.pinned).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.black,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Folders',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              )),
                          const SizedBox(width: 10),
                          Text('${visible.length}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showCreateFolder,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    isDark ? Colors.white : AppTheme.black,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add,
                                      size: 16,
                                      color: isDark
                                          ? AppTheme.black
                                          : Colors.white),
                                  const SizedBox(width: 4),
                                  Text('New',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: isDark
                                            ? AppTheme.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'AI sorts new saves automatically. You can override anything.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              if (_suggestion != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 14,
                                  color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text('SMART CLUSTER · NEW',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: AppTheme.textSecondary,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: textColor),
                              children: [
                                TextSpan(
                                    text:
                                        "You've saved ${_suggestion!.count} items that look related. "),
                                const TextSpan(text: 'Make a folder '),
                                TextSpan(
                                  text: '"${_suggestion!.suggestedName}"',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(text: '?'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _createFromSuggestion(_suggestion!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.black,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text('Create folder',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () =>
                                    _dismissSuggestion(_suggestion!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border:
                                        Border.all(color: borderColor),
                                  ),
                                  child: Text('Not now',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (pinned.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        Text('PINNED',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppTheme.textSecondary,
                            )),
                        const Spacer(),
                        Text('${pinned.length}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: pinned.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final c = pinned[i];
                        return GestureDetector(
                          onTap: () => context
                              .push('/folder/${c.id}', extra: c),
                          onLongPress: () => _folderActions(c),
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_categoryIcon(c.name),
                                        size: 18,
                                        color: Colors.white70),
                                    const Spacer(),
                                    const Icon(Icons.push_pin,
                                        size: 14,
                                        color: Colors.white54),
                                  ],
                                ),
                                const Spacer(),
                                Text('${countFor(c)}',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    )),
                                const SizedBox(height: 2),
                                Text(c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('ALL FOLDERS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondary,
                      )),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else if (rest.isEmpty && pinned.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      'No folders yet. Save something — the AI files it automatically.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= rest.length) return null;
                      final c = rest[i];
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/folder/${c.id}', extra: c),
                          onLongPress: () => _folderActions(c),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : AppTheme.grey100,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(_categoryIcon(c.name),
                                      size: 18, color: iconColor),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style:
                                              GoogleFonts.spaceGrotesk(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 15,
                                            color: textColor,
                                          )),
                                      const SizedBox(height: 2),
                                      Text('${countFor(c)} items',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme
                                                  .textSecondary)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppTheme.textSecondary,
                                    size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: rest.length,
                  ),
                ),

              if (_activeSmart.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text('SMART COLLECTIONS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.textSecondary,
                        )),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _activeSmart.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final c = _activeSmart[i];
                        final cnt = _smartCounts[c.id] ?? 0;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CollectionScreen(collection: c),
                            ),
                          ),
                          child: Container(
                            width: 170,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(c.icon,
                                    size: 20, color: iconColor),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style:
                                            GoogleFonts.spaceGrotesk(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: textColor,
                                        )),
                                    const SizedBox(height: 2),
                                    Text('$cnt items',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme
                                                .textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              if (_collections.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        Text('COLLECTIONS',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppTheme.textSecondary,
                            )),
                        const Spacer(),
                        GestureDetector(
                          onTap: _createCollection,
                          child: Icon(Icons.add,
                              size: 18,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.black),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _collections.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final col = _collections[i];
                        return GestureDetector(
                          onTap: () async {
                            final deleted =
                                await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UserCollectionScreen(
                                    collection: col),
                              ),
                            );
                            if (deleted == true) _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    Icons
                                        .collections_bookmark_outlined,
                                    size: 15,
                                    color: iconColor),
                                const SizedBox(width: 6),
                                Text(col.name,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    )),
                                const SizedBox(width: 6),
                                Text('${col.itemCount}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme
                                            .textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

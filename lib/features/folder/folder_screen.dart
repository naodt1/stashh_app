import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stash_item.dart';
import '../../models/category.dart';
import '../../models/smart_collection.dart';
import '../../models/collection.dart';
import '../add_item/add_item_sheet.dart';
import '../collection/collection_screen.dart';
import '../collection/user_collection_screen.dart';
import '../shared/stash_item_card.dart';

// Maps a category name to a Material icon — falls back to folder
IconData _categoryIcon(String name) {
  switch (name.toLowerCase()) {
    case 'food':        return Icons.restaurant_outlined;
    case 'finance':     return Icons.account_balance_wallet_outlined;
    case 'work':        return Icons.work_outline;
    case 'inspiration': return Icons.lightbulb_outline;
    case 'health':      return Icons.fitness_center_outlined;
    case 'travel':      return Icons.flight_outlined;
    case 'reading':
    case 'books':       return Icons.menu_book_outlined;
    case 'music':       return Icons.music_note_outlined;
    case 'art':
    case 'design':      return Icons.palette_outlined;
    case 'home':        return Icons.home_outlined;
    case 'nature':      return Icons.eco_outlined;
    case 'science':     return Icons.science_outlined;
    case 'gaming':      return Icons.sports_esports_outlined;
    case 'shopping':    return Icons.shopping_bag_outlined;
    case 'social':      return Icons.people_outline;
    default:            return Icons.folder_outlined;
  }
}

// Default quick-start folders
const _defaultCategories = [
  {'name': 'Work'},
  {'name': 'Finance'},
  {'name': 'Health'},
  {'name': 'Travel'},
  {'name': 'Inspiration'},
  {'name': 'Reading'},
];

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
        if (mounted) {
          setState(() {
            _categories = cats;
            _collections = cols;
            _smartCounts = smart;
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

  Widget _buildListView(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder;
    final iconColor = isDark ? AppTheme.grey300 : AppTheme.grey700;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Folders',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showCreateFolder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : AppTheme.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add,
                                color: isDark
                                    ? AppTheme.black
                                    : Colors.white,
                                size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'New',
                              style: GoogleFonts.spaceGrotesk(
                                color: isDark
                                    ? AppTheme.black
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Smart Collections — only the ones the AI has populated ───
            if (_activeSmart.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'Smart Collections',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ).animate().fadeIn(delay: 120.ms),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _activeSmart.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final c = _activeSmart[i];
                      final count = _smartCounts[c.id] ?? 0;
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CollectionScreen(collection: c),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(c.icon, size: 20, color: iconColor),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$count item${count == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: 140 + i * 50));
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // ── User-created collections ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Text(
                      'Collections',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _createCollection,
                      child: Icon(Icons.add,
                          size: 20,
                          color: isDark ? Colors.white : AppTheme.black),
                    ),
                  ],
                ),
              ),
            ),
            if (_collections.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Text(
                    'Create collections to group items across folders. '
                    'An item can live in many at once.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _collections.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final col = _collections[i];
                      return GestureDetector(
                        onTap: () async {
                          final deleted = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserCollectionScreen(collection: col),
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
                              Icon(Icons.collections_bookmark_outlined,
                                  size: 15, color: iconColor),
                              const SizedBox(width: 6),
                              Text(
                                col.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('${col.itemCount}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: 60 * i));
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Your Folders',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),

            if (_loading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 110,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                    ),
                    childCount: 6,
                  ),
                ),
              )
            else if (_categories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: _buildDefaultCategories(
                      isDark, cardColor, borderColor, iconColor),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 110,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= _categories.length) return null;
                      final cat = _categories[i];
                      return GestureDetector(
                        onTap: () =>
                            context.push('/folder/${cat.id}', extra: cat),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(cat.name),
                                  size: 22, color: iconColor),
                              const Spacer(),
                              Text(
                                cat.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${cat.itemCount} items',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: i * 60));
                    },
                    childCount: _categories.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCategories(
      bool isDark, Color cardColor, Color borderColor, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick start with these folders:',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 110,
          ),
          itemCount: _defaultCategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (_, idx) {
            final cat = _defaultCategories[idx];
            final name = cat['name']!;
            return GestureDetector(
              onTap: () async {
                final user = SupabaseService.currentUser;
                if (user == null) return;
                await SupabaseService.createCategory({
                  'id': const Uuid().v4(),
                  'user_id': user.id,
                  'name': name,
                  'icon': 'folder',
                  'color': '#000000',
                  'item_count': 0,
                });
                _load();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_categoryIcon(name), size: 22, color: iconColor),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.add,
                            size: 15, color: AppTheme.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/collection.dart';
import '../../models/stash_item.dart';
import '../shared/stash_item_card.dart';

class UserCollectionScreen extends StatefulWidget {
  final Collection collection;
  const UserCollectionScreen({super.key, required this.collection});

  @override
  State<UserCollectionScreen> createState() => _UserCollectionScreenState();
}

class _UserCollectionScreenState extends State<UserCollectionScreen> {
  List<StashItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items =
        await SupabaseService.getCollectionItems(widget.collection.id);
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.collection.name,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                await SupabaseService.deleteCollection(widget.collection.id);
                if (mounted) Navigator.pop(context, true);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete collection')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.textSecondary))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.collections_bookmark_outlined,
                            size: 56,
                            color: isDark
                                ? AppTheme.grey500
                                : AppTheme.grey300),
                        const SizedBox(height: 20),
                        Text('Empty collection',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Long-press any item → “Add to collection”',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.black,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => StashItemCard(
                      item: _items[i],
                      isDark: isDark,
                      onDeleted: _load,
                      onTogglePin: () async {
                        await SupabaseService.updateItem(_items[i].id,
                            {'is_pinned': !_items[i].isPinned});
                        _load();
                      },
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 35)),
                  ),
                ),
    );
  }
}

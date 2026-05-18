import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/smart_collection.dart';
import '../../models/stash_item.dart';
import '../shared/stash_item_card.dart';

/// Live results for a Smart Collection — recomputed every time it opens,
/// so it always reflects the latest AI-classified items.
class CollectionScreen extends StatefulWidget {
  final SmartCollection collection;
  const CollectionScreen({super.key, required this.collection});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<StashItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.collection.resolve();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(widget.collection.icon,
                size: 20,
                color: isDark ? Colors.white : AppTheme.textPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.collection.name,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.textSecondary))
          : _items.isEmpty
              ? _empty(isDark)
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
                        await SupabaseService.updateItem(
                          _items[i].id,
                          {'is_pinned': !_items[i].isPinned},
                        );
                        _load();
                      },
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 35)),
                  ),
                ),
    );
  }

  Widget _empty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.collection.icon,
                size: 56,
                color: isDark ? AppTheme.grey500 : AppTheme.grey300),
            const SizedBox(height: 20),
            Text(
              'Nothing here yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.collection.subtitle,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

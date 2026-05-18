import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/collection.dart';

/// Multi-select picker — an item can live in many collections at once.
/// Pass [itemIds] (one or many for bulk add).
class AddToCollectionSheet extends StatefulWidget {
  final List<String> itemIds;
  const AddToCollectionSheet({super.key, required this.itemIds});

  @override
  State<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<AddToCollectionSheet> {
  List<Collection> _collections = [];
  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  bool get _isBulk => widget.itemIds.length > 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cols = await SupabaseService.getCollections();
    Set<String> sel = {};
    if (!_isBulk) {
      sel = await SupabaseService.getCollectionIdsForItem(widget.itemIds.first);
    }
    if (mounted) {
      setState(() {
        _collections = cols;
        _selected = sel;
        _loading = false;
      });
    }
  }

  Future<void> _createInline() async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
    final created = await SupabaseService.createCollection(name);
    setState(() {
      _collections = [..._collections, created];
      _selected = {..._selected, created.id};
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    if (_isBulk) {
      for (final cid in _selected) {
        await SupabaseService.addItemsToCollection(cid, widget.itemIds);
      }
    } else {
      final itemId = widget.itemIds.first;
      final before = await SupabaseService.getCollectionIdsForItem(itemId);
      for (final cid in _selected.difference(before)) {
        await SupabaseService.addItemToCollection(cid, itemId);
      }
      for (final cid in before.difference(_selected)) {
        await SupabaseService.removeItemFromCollection(cid, itemId);
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111111) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    _isBulk
                        ? 'Add ${widget.itemIds.length} items to…'
                        : 'Add to collections',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _createInline,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                    style: TextButton.styleFrom(
                        foregroundColor: textColor),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.textSecondary),
              )
            else if (_collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.collections_bookmark_outlined,
                        size: 40,
                        color:
                            isDark ? AppTheme.grey500 : AppTheme.grey300),
                    const SizedBox(height: 12),
                    Text('No collections yet',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(height: 4),
                    const Text('Tap “New” to create one',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _collections.map((c) {
                    final on = _selected.contains(c.id);
                    return CheckboxListTile(
                      value: on,
                      activeColor: AppTheme.black,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(c.name,
                          style: GoogleFonts.spaceGrotesk(
                              color: textColor,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text('${c.itemCount} items',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      onChanged: (v) => setState(() => v == true
                          ? _selected.add(c.id)
                          : _selected.remove(c.id)),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Done',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

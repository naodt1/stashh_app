import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stash_item.dart';
import '../collection/add_to_collection_sheet.dart';
import '../detail/item_detail_screen.dart';

class StashItemCard extends StatelessWidget {
  final StashItem item;
  final bool isDark;
  final VoidCallback? onDeleted;
  final VoidCallback? onTogglePin;

  const StashItemCard({
    super.key,
    required this.item,
    required this.isDark,
    this.onDeleted,
    this.onTogglePin,
  });

  IconData get _typeIcon {
    switch (item.contentType) {
      case 'link':     return Icons.link;
      case 'image':    return Icons.image_outlined;
      case 'video':    return Icons.play_circle_outline;
      case 'document': return Icons.description_outlined;
      default:         return Icons.notes;
    }
  }

  Future<void> _openUrl() async {
    if (item.url == null) return;
    final uri = Uri.tryParse(item.url!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showActions(BuildContext context) {
    final border = isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder;
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
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (item.url != null)
              ListTile(
                leading: Icon(Icons.open_in_new,
                    color: isDark ? Colors.white : AppTheme.textPrimary),
                title: Text('Open Link',
                    style: GoogleFonts.spaceGrotesk(
                        color: isDark ? Colors.white : AppTheme.textPrimary)),
                onTap: () { Navigator.pop(context); _openUrl(); },
              ),
            ListTile(
              leading: Icon(
                item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
              title: Text(item.isPinned ? 'Unpin' : 'Pin',
                  style: GoogleFonts.spaceGrotesk(
                      color: isDark ? Colors.white : AppTheme.textPrimary)),
              onTap: () { Navigator.pop(context); onTogglePin?.call(); },
            ),
            ListTile(
              leading: Icon(Icons.collections_bookmark_outlined,
                  color: isDark ? Colors.white : AppTheme.textPrimary),
              title: Text('Add to collection',
                  style: GoogleFonts.spaceGrotesk(
                      color: isDark ? Colors.white : AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      AddToCollectionSheet(itemIds: [item.id]),
                );
              },
            ),
            Container(height: 1, color: border, margin: const EdgeInsets.symmetric(horizontal: 16)),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await SupabaseService.deleteItem(item.id);
                onDeleted?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String? get _platformShort {
    final p = item.platform?.toLowerCase();
    if (p == null) return null;
    if (p.contains('tiktok')) return 'tt';
    if (p.contains('youtube')) return 'yt';
    if (p.contains('instagram')) return 'ig';
    if (p.contains('pinterest')) return 'pin';
    if (p == 'x' || p.contains('twitter')) return 'x';
    if (p.contains('facebook')) return 'fb';
    if (p.contains('reddit')) return 're';
    return p.length <= 3 ? p : p.substring(0, 2);
  }

  String get _subtitle {
    if (item.url != null) {
      final host = Uri.tryParse(item.url!)?.host.replaceFirst('www.', '');
      if (host != null && host.isNotEmpty) return host;
    }
    if (item.rawContent != null && item.rawContent!.isNotEmpty) return 'Note';
    return item.platform ?? 'Saved';
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? AppTheme.grey300 : AppTheme.grey700;
    final thumbBg = isDark ? const Color(0xFF2A2A2A) : AppTheme.grey100;
    final chipBg = isDark ? const Color(0xFF2A2A2A) : AppTheme.grey100;
    final hasThumbnail =
        item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty;

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 100,
        height: 116,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumbnail)
              CachedNetworkImage(
                imageUrl: item.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: thumbBg),
                errorWidget: (_, __, ___) => Container(
                  color: thumbBg,
                  child: Icon(_typeIcon, color: iconColor, size: 28),
                ),
              )
            else
              Container(
                color: thumbBg,
                child: Icon(_typeIcon, color: iconColor, size: 28),
              ),
            if (item.contentType == 'video')
              Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            if (_platformShort != null)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _platformShort!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (item.durationSeconds != null && item.durationSeconds! > 0)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.durationSeconds! ~/ 60}:${(item.durationSeconds! % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Widget tagChip(String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(item: item),
        ),
      ),
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            thumb,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.isPinned) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 4),
                          child: Icon(Icons.push_pin,
                              size: 13,
                              color: isDark
                                  ? AppTheme.grey300
                                  : AppTheme.grey700),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.25,
                            color:
                                isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_subtitle · ${timeago.format(item.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...item.tags.take(2).map(tagChip),
                      if (item.primaryCategory != null &&
                          item.primaryCategory!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined,
                                size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              item.primaryCategory!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

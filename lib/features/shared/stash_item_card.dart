import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stash_item.dart';
import '../collection/add_to_collection_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark ? const Color(0xFF2A2A2A) : AppTheme.grey100;
    final iconColor = isDark ? AppTheme.grey300 : AppTheme.grey700;

    final hasThumbnail = item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: item.url != null ? _openUrl : null,
      onLongPress: () => _showActions(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail banner ─────────────────────────────────────────
            if (hasThumbnail)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.thumbnailUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : AppTheme.grey100,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 160,
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : AppTheme.grey100,
                        child: Icon(_typeIcon, color: iconColor, size: 32),
                      ),
                    ),
                    if (item.contentType == 'video')
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                  ],
                ),
              ),

            // ── Content row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon — only shown when there's no thumbnail
                  if (!hasThumbnail) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_typeIcon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.isPinned) ...[
                              Icon(Icons.push_pin, size: 12,
                                  color: isDark ? AppTheme.grey300 : AppTheme.grey700),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                item.title,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.url != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            Uri.tryParse(item.url!)?.host ?? item.url!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.grey500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (item.tags.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : AppTheme.grey100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.tags.first,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (item.tags.length > 1) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '+${item.tags.length - 1}',
                                  style: const TextStyle(
                                      fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                              const SizedBox(width: 8),
                            ],
                            Text(
                              timeago.format(item.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showActions(context),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.more_vert,
                          size: 18, color: AppTheme.textSecondary),
                    ),
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

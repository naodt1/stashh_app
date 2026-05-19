import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/platform_detect.dart';
import '../../models/stash_item.dart';
import '../detail/item_detail_screen.dart';

enum _Step { pending, active, done, skipped }

/// Compact, scrim-backed progress card shown when something is shared
/// to Stashh — the full app never renders. Honors the auto-save toggle:
/// on → save + return to the previous app; off → wait for Edit / Open.
class ShareProgressScreen extends StatefulWidget {
  final SharePayload payload;
  const ShareProgressScreen({super.key, required this.payload});

  @override
  State<ShareProgressScreen> createState() => _ShareProgressScreenState();
}

class _ShareProgressScreenState extends State<ShareProgressScreen> {
  _Step _fetch = _Step.pending;
  _Step _transcribe = _Step.pending;
  _Step _embed = _Step.pending;
  _Step _file = _Step.pending;

  String _sourceLine = '';
  String? _fetchMeta; // e.g. "1080p" / size
  String? _transcribeMeta;
  String? _tagMeta;
  String? _folderMeta;

  bool _done = false;
  bool _failed = false;
  bool _autoSave = false;
  StashItem? _saved;

  final _stopwatch = Stopwatch()..start();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    _run();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _set(void Function() f) {
    if (mounted) setState(f);
  }

  Future<void> _run() async {
    try {
      _autoSave = await SettingsService.getAutoSaveShares();
      final p = widget.payload;
      final isUrl = p.isUrl;
      final content = p.content;
      final itemId = const Uuid().v4();

      String title = '';
      String description = '';
      String selectedType = isUrl
          ? 'link'
          : (p.isVideo ? 'video' : (p.isImage ? 'image' : 'text'));
      String? remoteThumb;
      String? transcript;
      int? durationSeconds;

      // ── Step 1: fetch ───────────────────────────────────────────────
      _set(() {
        _fetch = _Step.active;
        _sourceLine = isUrl
            ? (detectPlatform(content) ?? Uri.tryParse(content)?.host ?? 'Link')
            : (p.isVideo ? 'Video' : p.isImage ? 'Image' : 'Note');
      });

      if (isUrl) {
        final meta = await MetadataService.fetch(content);
        if (meta != null) {
          if (meta.title?.isNotEmpty ?? false) title = meta.title!;
          if (meta.description?.isNotEmpty ?? false) {
            description = meta.description!;
          }
          remoteThumb = meta.imageUrl;
          transcript = meta.transcript;
          if (meta.durationSeconds != null && meta.durationSeconds! > 0) {
            durationSeconds = meta.durationSeconds!.round();
          }
        }
        if (_isVideoHost(content)) selectedType = 'video';
        final d = durationSeconds;
        final durLabel = d == null
            ? null
            : '${d ~/ 60}:${(d % 60).toString().padLeft(2, '0')}';
        _set(() {
          _fetch = _Step.done;
          _fetchMeta = durLabel;
        });
      } else {
        // local media
        title = _fileName(p.filePath ?? '');
        if (p.isVideo && p.filePath != null && !kIsWeb) {
          try {
            final bytes = await VideoThumbnailPlus.thumbnailData(
              video: p.filePath!,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 800,
              quality: 80,
            );
            if (bytes != null) {
              remoteThumb =
                  await SupabaseService.uploadThumbnail(itemId, bytes);
            }
          } catch (_) {}
        }
        _set(() => _fetch = _Step.done);
      }

      // ── Step 2: transcribe ──────────────────────────────────────────
      _set(() => _transcribe = _Step.active);
      if (transcript != null && transcript.trim().isNotEmpty) {
        _set(() {
          _transcribe = _Step.done;
          _transcribeMeta = 'captured';
        });
      } else {
        _set(() {
          _transcribe = _Step.skipped;
          _transcribeMeta = 'no captions';
        });
      }

      // ── Step 3: embed & tag ─────────────────────────────────────────
      _set(() => _embed = _Step.active);
      final aiInput = [
        if (title.isNotEmpty) title,
        if (description.isNotEmpty) description,
        if (transcript != null && transcript.isNotEmpty)
          (transcript.length > 2000
              ? transcript.substring(0, 2000)
              : transcript),
        if (isUrl) content,
      ].join(' — ');

      final ai = await AiService.categorize(aiInput,
          durationSeconds: durationSeconds);
      if (ai != null) {
        if (title.isEmpty && ai.title.isNotEmpty && ai.title != 'Untitled') {
          title = ai.title;
        }
        if (description.isEmpty) description = ai.description;
      }
      final embedding = await AiService.embed([
        title,
        description,
        ai?.topics.join(' ') ?? '',
        ai?.tags.join(' ') ?? '',
        transcript ?? '',
      ].where((s) => s.trim().isNotEmpty).join('. '));
      _set(() {
        _embed = _Step.done;
        _tagMeta = ai?.tags.take(3).join(' · ');
      });

      // ── Step 4: file into folder ────────────────────────────────────
      _set(() => _file = _Step.active);

      // Title fallback — never the raw URL
      if (title.trim().isEmpty) {
        if (isUrl) {
          final host = Uri.tryParse(content)?.host ?? '';
          title = host.isNotEmpty ? host.replaceFirst('www.', '') : 'Saved link';
        } else {
          title = content.length > 60
              ? '${content.substring(0, 60)}…'
              : content;
        }
      }

      String? categoryId;
      if (ai?.primaryCategory != null && ai!.primaryCategory.isNotEmpty) {
        categoryId =
            await SupabaseService.getOrCreateCategory(ai.primaryCategory);
        _set(() => _folderMeta = ai.primaryCategory);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final saved = await SupabaseService.createItem({
        'id': itemId,
        'user_id': SupabaseService.currentUser?.id,
        'category_id': categoryId,
        'title': title,
        'description': description.isEmpty ? null : description,
        'url': isUrl ? content : null,
        'content_type': selectedType,
        'raw_content': isUrl ? null : content,
        'source': 'share',
        'tags': ai?.tags ?? const [],
        'thumbnail_url': remoteThumb,
        'primary_category': ai?.primaryCategory,
        'length_bucket': ai?.lengthBucket,
        'mood': ai?.mood ?? const [],
        'intent': ai?.intent ?? const [],
        'skill_level': ai?.skillLevel,
        'visual_style': ai?.visualStyle,
        'creator_type': ai?.creatorType,
        'language': ai?.language,
        'topics': ai?.topics ?? const [],
        'platform': isUrl ? detectPlatform(content) : null,
        'transcript': transcript,
        'duration_seconds': durationSeconds,
        if (embedding != null) 'embedding': embedding,
        'is_pinned': false,
        'is_favorite': false,
        'created_at': now,
        'updated_at': now,
      });

      _set(() {
        _file = _Step.done;
        _saved = saved;
        _done = true;
      });
      Haptics.success();

      if (_autoSave) {
        await Future.delayed(const Duration(milliseconds: 1100));
        if (mounted) Navigator.of(context).maybePop();
        if (!kIsWeb) await SystemNavigator.pop();
      }
    } catch (_) {
      _set(() => _failed = true);
    }
  }

  bool _isVideoHost(String url) {
    final u = url.toLowerCase();
    return u.contains('instagram.com/reel') ||
        u.contains('tiktok.com') ||
        u.contains('youtube.com/watch') ||
        u.contains('youtu.be/') ||
        u.contains('youtube.com/shorts') ||
        u.contains('vimeo.com') ||
        u.contains('instagram.com/p/');
  }

  String _fileName(String path) {
    if (path.isEmpty) return 'Shared file';
    final n = path.split('/').last;
    final d = n.lastIndexOf('.');
    return d > 0 ? n.substring(0, d) : n;
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;
  // Accent that stays visible on either theme's card.
  Color get _accent => _isDark ? Colors.white : AppTheme.black;
  Color get _onAccent => _isDark ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF161616) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      body: GestureDetector(
        onTap: _done && !_autoSave ? _close : null,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 340,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _saved?.thumbnailUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: _saved!.thumbnailUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                      Icons.bolt,
                                      color: _onAccent,
                                      size: 18),
                                ),
                              )
                            : Icon(Icons.bolt,
                                color: _onAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _failed
                                  ? 'Couldn\'t save'
                                  : _done
                                      ? 'Saved to Stashh'
                                      : 'Saving to Stashh',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              _sourceLine,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_stopwatch.elapsed.inSeconds}s',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _row('Fetched video', _fetch, _fetchMeta, isDark),
                  const SizedBox(height: 14),
                  _row('Transcribing audio', _transcribe, _transcribeMeta,
                      isDark),
                  const SizedBox(height: 14),
                  _row('Embedding & tagging', _embed, _tagMeta, isDark),
                  const SizedBox(height: 14),
                  _row(
                      _folderMeta != null
                          ? 'Adding to $_folderMeta'
                          : 'Filing it away',
                      _file,
                      null,
                      isDark),

                  const SizedBox(height: 20),

                  if (_failed)
                    SizedBox(
                      width: double.infinity,
                      child: _btn('Close', filled: true, onTap: _close),
                    )
                  else if (_done && !_autoSave)
                    Row(
                      children: [
                        Expanded(
                          child: _btn('Edit', filled: false, onTap: () {
                            if (_saved == null) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ItemDetailScreen(item: _saved!),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _btn('Open in Stashh',
                              filled: true, onTap: _close),
                        ),
                      ],
                    )
                  else if (_done && _autoSave)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('Taking you back…',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, _Step s, String? meta, bool isDark) {
    Widget leading;
    switch (s) {
      case _Step.done:
        leading = Icon(Icons.check_circle, size: 22, color: _accent);
        break;
      case _Step.active:
        leading = SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: _accent),
        );
        break;
      case _Step.skipped:
        leading = Icon(Icons.remove_circle_outline,
            size: 22, color: AppTheme.grey300);
        break;
      case _Step.pending:
        leading = Icon(Icons.circle_outlined,
            size: 22, color: AppTheme.grey300);
        break;
    }
    final dim = s == _Step.pending || s == _Step.skipped;
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: dim
                  ? AppTheme.textSecondary
                  : (isDark ? Colors.white : AppTheme.textPrimary),
            ),
          ),
        ),
        if (meta != null)
          Flexible(
            child: Text(
              meta,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _btn(String label,
      {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        Haptics.impact();
        onTap();
      },
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(
                  color: _isDark ? Colors.white24 : AppTheme.grey300),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: filled
                ? _onAccent
                : (_isDark ? Colors.white : AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}

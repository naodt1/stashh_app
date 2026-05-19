import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/platform_detect.dart';
import '../../core/theme/app_theme.dart';
import '../../models/category.dart';

class AddItemSheet extends StatefulWidget {
  final String? initialContent;
  final String? initialCategoryId;
  final SharePayload? sharePayload;

  const AddItemSheet({
    super.key,
    this.initialContent,
    this.initialCategoryId,
    this.sharePayload,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  void _addTag(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return;
    setState(() {
      if (!_tags.contains(t)) _tags.add(t);
      _tagCtrl.clear();
    });
  }

  // AI-filled fields (user can optionally edit via "Edit details" expander).
  // Persistent controllers = single source of truth (no rebuild churn).
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String get _title => _titleCtrl.text;
  set _title(String v) => _titleCtrl.text = v;
  String get _description => _descCtrl.text;
  set _description(String v) => _descCtrl.text = v;
  String _selectedType = 'link';
  String? _selectedCategoryId;
  List<String> _tags = [];

  // Full multi-dimensional AI analysis (null until categorization runs)
  AiCategorization? _ai;
  String? _transcript;
  int? _durationSeconds;

  List<Category> _categories = [];
  bool _loading = false;
  bool _aiLoading = false;
  bool _saved = false;
  bool _showDetails = false;
  String? _error;

  // Video thumbnail preview (local file → bytes we upload)
  Uint8List? _thumbnailBytes;
  bool _thumbLoading = false;

  // Remote thumbnail (og:image from a shared link — already a URL)
  String? _remoteThumbnailUrl;

  // Auto-save: when on, a shared item saves itself with no Save tap
  bool _autoSave = false;
  bool _autoSaveTriggered = false;

  // The raw URL or text being saved
  String get _rawContent => _contentCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;

    // Defer all network / AI work until AFTER the sheet's open animation
    // has run — otherwise the setState storm janks the entrance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Wake the yt-dlp container now so it's warm by extraction time.
      MetadataService.prewarm();
      if (widget.sharePayload != null) {
        _initFromPayload(widget.sharePayload!);
        SettingsService.getAutoSaveShares().then((v) {
          if (!mounted) return;
          setState(() => _autoSave = v);
          if (v) {
            Future.delayed(
                const Duration(milliseconds: 1600), _maybeAutoSave);
          }
        });
      } else if (widget.initialContent != null) {
        _initFromString(widget.initialContent!);
      }
      _loadCategories();
    });
  }

  /// Saves automatically when auto-save is on and we came from a share —
  /// guarded so it only fires once and never mid-save.
  void _maybeAutoSave() {
    if (!_autoSave ||
        _autoSaveTriggered ||
        _saved ||
        _loading ||
        widget.sharePayload == null ||
        !mounted) {
      return;
    }
    _autoSaveTriggered = true;
    _save();
  }

  void _initFromPayload(SharePayload payload) {
    if (payload.isVideo && !payload.isUrl) {
      // Local video file → generate a thumbnail from the file itself
      _selectedType = 'video';
      _contentCtrl.text = payload.filePath ?? payload.content;
      _title = _fileNameWithoutExt(payload.filePath ?? '');
      if (payload.filePath != null) {
        _generateThumbnail(payload.filePath!);
      }
    } else if (payload.isImage && !payload.isUrl) {
      _selectedType = 'image';
      _contentCtrl.text = payload.filePath ?? payload.content;
      _title = _fileNameWithoutExt(payload.filePath ?? '');
    } else if (payload.isUrl) {
      // Any shared link (Instagram, TikTok, YouTube, article, …)
      _selectedType = _isVideoHost(payload.content) ? 'video' : 'link';
      _contentCtrl.text = payload.content;
      _enrichFromUrl(payload.content);
    } else {
      _selectedType = 'text';
      _contentCtrl.text = payload.content;
      _runAiCategorization(payload.content);
    }
  }

  void _initFromString(String c) {
    _contentCtrl.text = c;
    if (c.startsWith('http://') || c.startsWith('https://')) {
      _selectedType = _isVideoHost(c) ? 'video' : 'link';
      _enrichFromUrl(c);
    } else {
      _selectedType = 'text';
      _runAiCategorization(c);
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

  /// Fetches Open Graph metadata for a link, then runs AI categorization.
  /// Metadata gives us the real title + thumbnail; AI handles folder/tags.
  Future<void> _enrichFromUrl(String url) async {
    setState(() => _aiLoading = true);

    final meta = await MetadataService.fetch(url);
    if (meta != null && mounted) {
      setState(() {
        if (meta.title != null && meta.title!.isNotEmpty) {
          _title = meta.title!;
        }
        if (meta.description != null && meta.description!.isNotEmpty) {
          _description = meta.description!;
        }
        if (meta.imageUrl != null && meta.imageUrl!.isNotEmpty) {
          _remoteThumbnailUrl = meta.imageUrl;
        }
      });
    }
    final durationSeconds = meta?.durationSeconds;
    if (durationSeconds != null && durationSeconds > 0) {
      _durationSeconds = durationSeconds.round();
    }
    if (meta?.transcript != null && meta!.transcript!.isNotEmpty) {
      _transcript = meta.transcript;
    }

    // Feed the richer text (title + description + transcript) to the AI for
    // better categorisation; it must NOT clobber a good metadata title.
    final aiInput = [
      if (_title.isNotEmpty) _title,
      if (_description.isNotEmpty) _description,
      if (_transcript != null && _transcript!.isNotEmpty)
        _transcript!.length > 2000
            ? _transcript!.substring(0, 2000)
            : _transcript!,
      url,
    ].join(' — ');

    final result = await AiService.categorize(
      aiInput,
      durationSeconds: durationSeconds,
    );
    if (result != null && mounted) {
      setState(() {
        _ai = result;
        if (_title.isEmpty && result.title.isNotEmpty &&
            result.title != 'Untitled') {
          _title = result.title;
        }
        if (_description.isEmpty && result.description.isNotEmpty) {
          _description = result.description;
        }
        _tags = result.tags.take(8).toList();
        _matchFolder(result.primaryCategory);
      });
    }

    if (mounted) setState(() => _aiLoading = false);
    _maybeAutoSave();
  }

  /// Maps the AI's broad primary category onto an existing user folder
  /// (by name) if one happens to match — folders stay optional.
  void _matchFolder(String primaryCategory) {
    final match = _categories.where((c) {
      final n = c.name.toLowerCase();
      final p = primaryCategory.toLowerCase();
      return p.contains(n) || n.contains(p.split(' ').first);
    }).firstOrNull;
    if (match != null) _selectedCategoryId = match.id;
  }

  String _fileNameWithoutExt(String path) {
    if (path.isEmpty) return '';
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> _generateThumbnail(String filePath) async {
    // Local-file thumbnailing is a native plugin — unsupported on web.
    // (Web shares are links anyway, which use the remote og:image.)
    if (kIsWeb) return;
    setState(() => _thumbLoading = true);
    try {
      final bytes = await VideoThumbnailPlus.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 800,
        quality: 80,
      );
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _thumbLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _thumbLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    final cats = await SupabaseService.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _runAiCategorization(String content) async {
    if (content.isEmpty) return;
    setState(() => _aiLoading = true);
    final result = await AiService.categorize(content);
    if (result != null && mounted) {
      setState(() {
        _ai = result;
        _title = result.title;
        _description = result.description;
        _tags = result.tags.take(8).toList();
        _selectedType = result.contentType;
        _matchFolder(result.primaryCategory);
      });
    }
    if (mounted) setState(() => _aiLoading = false);
    _maybeAutoSave();
  }

  Future<void> _save() async {
    Haptics.impact();
    setState(() { _loading = true; _error = null; });
    try {
      final user = SupabaseService.currentUser;
      if (user == null) throw Exception('Not signed in');

      final content = _rawContent;
      final isUrl = content.startsWith('http://') || content.startsWith('https://');

      // Title fallback — never show the raw URL. Prefer the host name.
      String title = _title.trim();
      if (title.isEmpty) {
        if (isUrl) {
          final host = Uri.tryParse(content)?.host ?? '';
          title = host.isNotEmpty
              ? host.replaceFirst('www.', '')
              : 'Saved link';
        } else {
          title = content.length > 60
              ? '${content.substring(0, 60)}…'
              : content;
        }
      }

      // Generate a stable ID so we can name the thumbnail after it
      final itemId = const Uuid().v4();

      // Thumbnail: remote og:image (link) wins; else upload captured bytes
      String? thumbnailUrl = _remoteThumbnailUrl;
      if (thumbnailUrl == null && _thumbnailBytes != null) {
        thumbnailUrl = await SupabaseService.uploadThumbnail(itemId, _thumbnailBytes!);
      }

      final platform = isUrl ? detectPlatform(content) : null;

      // AI auto-filing: if the user didn't pick a folder, file the item
      // into a folder named after the AI's primary category (created on
      // demand). The user can always override via the folder picker.
      var categoryId = _selectedCategoryId;
      if (categoryId == null &&
          _ai?.primaryCategory != null &&
          _ai!.primaryCategory.isNotEmpty) {
        categoryId =
            await SupabaseService.getOrCreateCategory(_ai!.primaryCategory);
      }

      // Embedding for semantic search — built from every text signal we have.
      final embedSource = [
        title,
        _description,
        _ai?.topics.join(' ') ?? '',
        _tags.join(' '),
        _transcript ?? '',
      ].where((s) => s.trim().isNotEmpty).join('. ');
      final embedding = await AiService.embed(embedSource);

      final now = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.createItem({
        'id': itemId,
        'user_id': user.id,
        'category_id': categoryId,
        'title': title,
        'description': _description.isEmpty ? null : _description,
        'url': isUrl ? content : null,
        'content_type': _selectedType,
        'raw_content': isUrl ? null : content,
        'source': widget.sharePayload != null ? 'share' : 'manual',
        'tags': _tags,
        'thumbnail_url': thumbnailUrl,
        // ── AI multi-dimensional classification ──────────────────────
        'primary_category': _ai?.primaryCategory,
        'length_bucket': _ai?.lengthBucket,
        'mood': _ai?.mood ?? const [],
        'intent': _ai?.intent ?? const [],
        'skill_level': _ai?.skillLevel,
        'visual_style': _ai?.visualStyle,
        'creator_type': _ai?.creatorType,
        'language': _ai?.language,
        'topics': _ai?.topics ?? const [],
        'platform': platform,
        'transcript': _transcript,
        'duration_seconds': _durationSeconds,
        if (embedding != null) 'embedding': embedding,
        'is_pinned': false,
        'is_favorite': false,
        'created_at': now,
        'updated_at': now,
      });

      Haptics.success();
      if (!mounted) return;

      if (widget.sharePayload != null) {
        // Came from share sheet — show confirmation then return to previous app
        setState(() { _saved = true; _loading = false; });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop(true);
        // "Return to previous app" only makes sense on mobile.
        if (!kIsWeb) await SystemNavigator.pop();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111111) : Colors.white;
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = AppTheme.textSecondary;

    // ── Saved confirmation ────────────────────────────────────────────────
    if (_saved) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SizedBox(
          height: 260,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : const Color(0xFF000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check,
                    color: isDark ? Colors.black : Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Saved to Stashh',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Taking you back…',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: subColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Main sheet ────────────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle + header ──────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Save to Stashh',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: subColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Thumbnail preview ────────────────────────────────
                  if (_thumbLoading ||
                      _thumbnailBytes != null ||
                      _remoteThumbnailUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _thumbLoading
                          ? Container(
                              height: 180,
                              color: isDark
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFFF5F5F5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_thumbnailBytes != null)
                                  Image.memory(
                                    _thumbnailBytes!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  CachedNetworkImage(
                                    imageUrl: _remoteThumbnailUrl!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      height: 180,
                                      color: isDark
                                          ? const Color(0xFF1A1A1A)
                                          : const Color(0xFFF5F5F5),
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                if (_selectedType == 'video')
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Content preview / input ─────────────────────────
                  _ContentPreview(
                    controller: _contentCtrl,
                    type: _selectedType,
                    isDark: isDark,
                    border: border,
                    onChanged: (v) {
                      if (v.length > 10) _runAiCategorization(v);
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── AI status chip ───────────────────────────────────
                  _AiStatusChip(
                    loading: _aiLoading,
                    title: _title,
                    category: _selectedCategoryId != null
                        ? _categories
                            .where((c) => c.id == _selectedCategoryId)
                            .firstOrNull
                            ?.name
                        : null,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 16),

                  // ── Folder picker ────────────────────────────────────
                  if (_categories.isNotEmpty) ...[
                    Text(
                      'FOLDER',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: subColor,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FolderPicker(
                      categories: _categories,
                      selected: _selectedCategoryId,
                      onSelected: (id) =>
                          setState(() => _selectedCategoryId = id),
                      isDark: isDark,
                      border: border,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── "Edit details" expander ──────────────────────────
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showDetails = !_showDetails),
                    child: Row(
                      children: [
                        Text(
                          'Edit details',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: subColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showDetails
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: subColor,
                        ),
                      ],
                    ),
                  ),

                  if (_showDetails) ...[
                    const SizedBox(height: 12),
                    // Title override
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'Title (optional)',
                        hintStyle: TextStyle(color: subColor),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFF5F5F5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      style: GoogleFonts.spaceGrotesk(
                          color: textColor, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    // Note / description
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a note (optional)',
                        hintStyle: TextStyle(color: subColor),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFF5F5F5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      style: GoogleFonts.spaceGrotesk(
                          color: textColor, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    // ── Tags (AI-generated + user-added) ───────────────
                    Text(
                      'TAGS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: subColor,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in _tags)
                          Container(
                            padding: const EdgeInsets.only(
                                left: 10, right: 4, top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tag,
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 12, color: textColor)),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _tags.remove(tag)),
                                  child: Icon(Icons.close,
                                      size: 14, color: subColor),
                                ),
                              ],
                            ),
                          ),
                        // Add-tag input chip
                        IntrinsicWidth(
                          child: TextField(
                            controller: _tagCtrl,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 12, color: textColor),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '+ add tag',
                              hintStyle:
                                  TextStyle(color: subColor, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: _addTag,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Error ────────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],

                  // ── Auto-save toggle (only for shares) ───────────────
                  if (widget.sharePayload != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final v = !_autoSave;
                        setState(() => _autoSave = v);
                        await SettingsService.setAutoSaveShares(v);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.bolt_outlined,
                              size: 18, color: subColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Auto-save shared links next time',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                color: subColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Switch(
                            value: _autoSave,
                            onChanged: (v) async {
                              setState(() => _autoSave = v);
                              await SettingsService.setAutoSaveShares(v);
                            },
                            activeColor: const Color(0xFF000000),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Save button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 16,
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

// ── Content preview widget ───────────────────────────────────────────────────

class _ContentPreview extends StatelessWidget {
  final TextEditingController controller;
  final String type;
  final bool isDark;
  final Color border;
  final ValueChanged<String> onChanged;

  const _ContentPreview({
    required this.controller,
    required this.type,
    required this.isDark,
    required this.border,
    required this.onChanged,
  });

  IconData get _icon {
    switch (type) {
      case 'video': return Icons.play_circle_outline;
      case 'image': return Icons.image_outlined;
      case 'text':  return Icons.notes;
      default:      return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subColor = AppTheme.textSecondary;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_icon, size: 18, color: subColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: null,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: type == 'text'
                    ? 'Paste or type your note…'
                    : 'Paste a link…',
                hintStyle: TextStyle(color: subColor, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI status chip ───────────────────────────────────────────────────────────

class _AiStatusChip extends StatelessWidget {
  final bool loading;
  final String title;
  final String? category;
  final bool isDark;

  const _AiStatusChip({
    required this.loading,
    required this.title,
    required this.category,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AI is reading this…',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (title.isEmpty && category == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              [
                if (title.isNotEmpty) title,
                if (category != null) '· $category',
              ].join(' '),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Folder picker ────────────────────────────────────────────────────────────

// Maps a folder name to a Material icon (no emojis — B&W design).
IconData _folderIconFor(String name) {
  switch (name.toLowerCase()) {
    case 'food':
    case 'recipes':     return Icons.restaurant_outlined;
    case 'finance':
    case 'money':       return Icons.account_balance_wallet_outlined;
    case 'work':        return Icons.work_outline;
    case 'inspiration': return Icons.lightbulb_outline;
    case 'health':      return Icons.favorite_outline;
    case 'fitness':     return Icons.fitness_center_outlined;
    case 'travel':      return Icons.flight_outlined;
    case 'reading':
    case 'books':       return Icons.menu_book_outlined;
    case 'music':       return Icons.music_note_outlined;
    case 'art':
    case 'design':      return Icons.palette_outlined;
    case 'home':        return Icons.home_outlined;
    case 'tech':        return Icons.memory_outlined;
    case 'shopping':    return Icons.shopping_bag_outlined;
    case 'social':      return Icons.people_outline;
    default:            return Icons.folder_outlined;
  }
}

class _FolderPicker extends StatelessWidget {
  final List<Category> categories;
  final String? selected;
  final Function(String?) onSelected;
  final bool isDark;
  final Color border;

  const _FolderPicker({
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.isDark,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "No folder" chip
          _FolderChip(
            label: 'No folder',
            leadingIcon: null,
            selected: selected == null,
            onTap: () => onSelected(null),
            isDark: isDark,
            border: border,
          ),
          const SizedBox(width: 8),
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FolderChip(
              label: cat.name,
              leadingIcon: _folderIconFor(cat.name),
              selected: selected == cat.id,
              onTap: () => onSelected(cat.id),
              isDark: isDark,
              border: border,
            ),
          )),
        ],
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color border;

  const _FolderChip({
    required this.label,
    required this.leadingIcon,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF000000)
              : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF000000) : border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon,
                  size: 14,
                  color: selected
                      ? Colors.white
                      : AppTheme.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

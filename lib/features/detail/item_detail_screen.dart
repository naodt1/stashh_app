import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stash_item.dart';

class ItemDetailScreen extends StatefulWidget {
  final StashItem item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late StashItem _item = widget.item;
  bool _showTranscript = false;
  bool _rerunning = false;
  final _tagCtrl = TextEditingController();

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  String get _host {
    if (_item.url == null) return _item.platform ?? 'Saved';
    return Uri.tryParse(_item.url!)?.host.replaceFirst('www.', '') ??
        _item.url!;
  }

  String? get _durationLabel {
    final s = _item.durationSeconds;
    if (s == null || s <= 0) return null;
    final m = s ~/ 60, sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _openOriginal() async {
    if (_item.url == null) return;
    final uri = Uri.tryParse(_item.url!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveTags(List<String> tags) async {
    setState(() => _item = _item.copyWith(tags: tags));
    await SupabaseService.updateItem(_item.id, {'tags': tags});
  }

  void _addTag(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty || _item.tags.contains(t)) {
      _tagCtrl.clear();
      return;
    }
    _saveTags([..._item.tags, t]);
    _tagCtrl.clear();
  }

  Future<void> _rerunAi() async {
    setState(() => _rerunning = true);
    final text = [
      _item.title,
      _item.description ?? '',
      _item.transcript ?? '',
      _item.url ?? '',
    ].where((s) => s.trim().isNotEmpty).join(' — ');
    final r = await AiService.categorize(text,
        durationSeconds: _item.durationSeconds);
    if (r != null) {
      final updates = {
        'primary_category': r.primaryCategory,
        'description': r.description.isEmpty ? _item.description : r.description,
        'tags': r.tags,
        'topics': r.topics,
        'mood': r.mood,
        'intent': r.intent,
      };
      await SupabaseService.updateItem(_item.id, updates);
      if (mounted) {
        setState(() {
          _item = _item.copyWith(
            primaryCategory: r.primaryCategory,
            description:
                r.description.isEmpty ? _item.description : r.description,
            tags: r.tags,
            topics: r.topics,
            mood: r.mood,
            intent: r.intent,
          );
        });
      }
    }
    if (mounted) setState(() => _rerunning = false);
  }

  void _copyLink() {
    if (_item.url == null) return;
    Clipboard.setData(ClipboardData(text: _item.url!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111111) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF7F7F7);
    final border = isDark ? const Color(0xFF2A2A2A) : AppTheme.cardBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              _item.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: textColor,
              ),
            ),
          ),

          // ── AI summary card ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text('AI SUMMARY',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.textSecondary,
                        )),
                    const Spacer(),
                    const Text('GPT-4O MINI',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  (_item.description?.isNotEmpty ?? false)
                      ? _item.description!
                      : 'No summary yet — tap the ✦ button to generate one.',
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: textColor),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final t in _item.tags)
                      _tagChip(t, isDark, onRemove: () {
                        _saveTags(
                            _item.tags.where((x) => x != t).toList());
                      }),
                    _addTagField(isDark),
                  ],
                ),
              ],
            ),
          ),

          // ── Transcript (collapsible) ─────────────────────────────────
          if (_item.transcript != null && _item.transcript!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () => setState(
                        () => _showTranscript = !_showTranscript),
                    leading: const Icon(Icons.subject,
                        size: 20, color: AppTheme.textSecondary),
                    title: Text('Transcript',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    trailing: Icon(
                        _showTranscript
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppTheme.textSecondary),
                  ),
                  if (_showTranscript)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        _item.transcript!,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
            ),

          // ── Metadata table ───────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _metaRow('SOURCE', _host, border),
                _metaRow(
                    'SAVED',
                    timeago.format(_item.createdAt),
                    border),
                if (_durationLabel != null)
                  _metaRow('DURATION', _durationLabel!, border),
                _metaRow('PLATFORM', _item.platform ?? '—', border,
                    last: true),
              ],
            ),
          ),

          // ── Bottom action bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_outlined,
                            size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          _item.primaryCategory ?? 'Unfiled',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600,
                              color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _squareBtn(
                  icon: Icons.ios_share,
                  onTap: _copyLink,
                  border: border,
                  cardBg: cardBg,
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _rerunning ? null : _rerunAi,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _rerunning
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(bool isDark) {
    final placeholder = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFF1A1A1A);
    final hasThumb =
        _item.thumbnailUrl != null && _item.thumbnailUrl!.isNotEmpty;

    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: hasThumb
              ? CachedNetworkImage(
                  imageUrl: _item.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: placeholder),
                  errorWidget: (_, __, ___) =>
                      Container(color: placeholder),
                )
              : Container(color: placeholder),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _circleBtn(Icons.arrow_back,
                    () => Navigator.of(context).pop()),
                const Spacer(),
                _circleBtn(Icons.ios_share, _copyLink),
              ],
            ),
          ),
        ),
        if (_item.url != null)
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: _openOriginal,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.black, size: 34),
                ),
              ),
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  [
                    if (_item.platform != null) _item.platform,
                    if (_durationLabel != null) _durationLabel,
                  ].whereType<String>().join(' · '),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (_item.url != null)
                GestureDetector(
                  onTap: _openOriginal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new,
                            color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text('Open original',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      );

  Widget _squareBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color border,
    required Color cardBg,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: const Icon(Icons.ios_share,
              size: 18, color: AppTheme.textSecondary),
        ),
      );

  Widget _tagChip(String label, bool isDark, {VoidCallback? onRemove}) =>
      Container(
        padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF3A3A3A)
                  : AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : AppTheme.textPrimary)),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close,
                    size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      );

  Widget _addTagField(bool isDark) => SizedBox(
        width: 110,
        child: TextField(
          controller: _tagCtrl,
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : AppTheme.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: '+ add tag',
            hintStyle:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF3A3A3A)
                      : AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF3A3A3A)
                      : AppTheme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.black),
            ),
          ),
          onSubmitted: _addTag,
        ),
      );

  Widget _metaRow(String k, String v, Color border, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      );
}

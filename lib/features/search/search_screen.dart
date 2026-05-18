import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stash_item.dart';
import '../../models/smart_collection.dart';
import '../../core/utils/platform_detect.dart';
import '../collection/collection_screen.dart';
import '../shared/stash_item_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<StashItem> _results = [];
  bool _loading = false;
  bool _hasQueried = false;
  Timer? _debounce;
  Map<String, int> _smartCounts = {};

  @override
  void initState() {
    super.initState();
    resolveActiveSmartCollections().then((m) {
      if (mounted) setState(() => _smartCounts = m);
    });
  }

  List<SmartCollection> get _activeSmart => kSmartCollections
      .where((c) => _smartCounts.containsKey(c.id))
      .toList();

  // Active filters
  String? _length; // short | medium | long
  String? _source; // share | manual  (mapped from chip)
  String? _contentType; // video | link
  String? _platform; // Instagram | TikTok | YouTube | …
  bool _semantic = true; // AI meaning-based search (default on)
  final Set<String> _moods = {};

  bool get _hasFilters =>
      _length != null ||
      _source != null ||
      _contentType != null ||
      _platform != null ||
      _moods.isNotEmpty;

  bool get _isIdle =>
      _searchCtrl.text.trim().isEmpty && !_hasFilters && !_hasQueried;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runQuery);
  }

  Future<void> _runQuery() async {
    final text = _searchCtrl.text.trim();
    if (text.isEmpty && !_hasFilters) {
      setState(() {
        _results = [];
        _hasQueried = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      List<StashItem> results;

      if (_semantic && text.isNotEmpty) {
        // Meaning-based search: embed the query, cosine-match, then apply
        // the active filters client-side (RPC returns by relevance only).
        final emb = await AiService.embed(text);
        final hits = emb == null
            ? <StashItem>[]
            : await SupabaseService.semanticSearch(emb, matchCount: 60);
        results = hits.where(_passesFilters).toList();

        // Degrade to keyword if embeddings unavailable or nothing matched.
        if (results.isEmpty) {
          results = await SupabaseService.queryItems(
            text: text,
            lengthBucket: _length,
            source: _source,
            contentType: _contentType,
            platform: _platform,
            moods: _moods.isEmpty ? null : _moods.toList(),
            limit: 60,
          );
        }
      } else {
        results = await SupabaseService.queryItems(
          text: text.isEmpty ? null : text,
          lengthBucket: _length,
          source: _source,
          contentType: _contentType,
          platform: _platform,
          moods: _moods.isEmpty ? null : _moods.toList(),
          limit: 60,
        );
      }

      if (mounted) {
        setState(() {
          _results = results;
          _hasQueried = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _passesFilters(StashItem it) {
    if (_length != null && it.lengthBucket != _length) return false;
    if (_contentType != null && it.contentType != _contentType) return false;
    if (_platform != null && it.platform != _platform) return false;
    if (_source != null && it.source != _source) return false;
    if (_moods.isNotEmpty && !it.mood.any(_moods.contains)) return false;
    return true;
  }

  void _toggleSingle(String? current, String value,
      void Function(String?) set) {
    set(current == value ? null : value);
    _runQuery();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchCtrl,
                    autofocus: false,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search titles, topics, tags...',
                      prefixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.textSecondary),
                              ),
                            )
                          : const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _runQuery();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),
                  _filterBar(isDark),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _filterBar(bool isDark) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('✦ Smart', _semantic, isDark, () {
            setState(() => _semantic = !_semantic);
            _runQuery();
          }),
          _divider(),
          for (final p in kFilterPlatforms)
            _chip(p, _platform == p, isDark,
                () => _toggleSingle(_platform, p,
                    (v) => setState(() => _platform = v))),
          _divider(),
          _chip('Videos', _contentType == 'video', isDark,
              () => _toggleSingle(_contentType, 'video',
                  (v) => setState(() => _contentType = v))),
          _chip('Links', _contentType == 'link', isDark,
              () => _toggleSingle(_contentType, 'link',
                  (v) => setState(() => _contentType = v))),
          _divider(),
          _chip('Short', _length == 'short', isDark,
              () => _toggleSingle(_length, 'short',
                  (v) => setState(() => _length = v))),
          _chip('Medium', _length == 'medium', isDark,
              () => _toggleSingle(_length, 'medium',
                  (v) => setState(() => _length = v))),
          _chip('Long', _length == 'long', isDark,
              () => _toggleSingle(_length, 'long',
                  (v) => setState(() => _length = v))),
          _divider(),
          _chip('Shared', _source == 'share', isDark,
              () => _toggleSingle(_source, 'share',
                  (v) => setState(() => _source = v))),
          _divider(),
          for (final m in ['Motivational', 'Funny', 'Informative', 'Relaxing'])
            _chip(m, _moods.contains(m), isDark, () {
              setState(() =>
                  _moods.contains(m) ? _moods.remove(m) : _moods.add(m));
              _runQuery();
            }),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: AppTheme.grey300,
      );

  Widget _chip(String label, bool active, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.black
                : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppTheme.black
                  : (isDark
                      ? const Color(0xFF2A2A2A)
                      : AppTheme.cardBorder),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active
                  ? Colors.white
                  : (isDark ? Colors.white70 : AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    // Idle → show Smart Collections (only those the AI has populated)
    if (_isIdle) {
      if (_activeSmart.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search,
                  size: 48,
                  color: isDark ? AppTheme.grey500 : AppTheme.grey300),
              const SizedBox(height: 16),
              Text(
                'Search your library',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Smart Collections appear here as you save',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          Text(
            'Smart Collections',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Auto-updating — built from AI understanding',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ..._activeSmart.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CollectionScreen(collection: c),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : AppTheme.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : AppTheme.grey100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(c.icon,
                              size: 19,
                              color: isDark
                                  ? AppTheme.grey300
                                  : AppTheme.grey700),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_smartCounts[c.id] ?? 0} items · ${c.subtitle}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ).animate().fadeIn(
                    delay: Duration(
                        milliseconds:
                            120 + _activeSmart.indexOf(c) * 40)),
              )),
        ],
      );
    }

    if (_hasQueried && _results.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48,
                color: isDark ? AppTheme.grey500 : AppTheme.grey300),
            const SizedBox(height: 16),
            Text(
              'No results',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords or filters',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        return StashItemCard(
          item: _results[i],
          isDark: isDark,
          onDeleted: () => setState(() => _results.removeAt(i)),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
      },
    );
  }
}

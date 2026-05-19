import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

/// Open Graph / page metadata pulled from a shared URL.
class LinkMetadata {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final num? durationSeconds; // from yt-dlp tier when available
  final String? transcript; // captions/subtitles from yt-dlp tier

  const LinkMetadata({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.durationSeconds,
    this.transcript,
  });

  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      (imageUrl == null || imageUrl!.isEmpty);

  factory LinkMetadata.fromJson(Map<String, dynamic> j) => LinkMetadata(
        title: (j['title'] as String?)?.trim(),
        description: (j['description'] as String?)?.trim(),
        imageUrl: (j['imageUrl'] as String?)?.trim(),
        siteName: (j['siteName'] as String?)?.trim(),
        durationSeconds: j['duration'] is num ? j['duration'] as num : null,
        transcript: (j['transcript'] as String?)?.trim(),
      );
}

class MetadataService {
  /// Fire-and-forget ping to wake the (free-tier) yt-dlp container so it's
  /// warm by the time extraction runs. Safe to call repeatedly; never
  /// throws and never blocks the UI.
  static void prewarm() {
    final url = AppConfig.ytdlpHealthUrl;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Short timeout, errors swallowed — this is best-effort.
    http.get(uri).timeout(
          const Duration(seconds: 4),
          onTimeout: () => http.Response('', 408),
        ).catchError((_) => http.Response('', 0));
  }

  /// Resolves link metadata. Strategy:
  ///   1. Server-side `extract-metadata` Edge Function — handles the hard
  ///      cases (Instagram / TikTok login wall) via oEmbed + yt-dlp.
  ///   2. If that yields nothing, fall back to on-device OG scraping
  ///      (works fine for normal article / blog / YouTube links).
  static Future<LinkMetadata?> fetch(String url) async {
    final viaServer = await _viaEdgeFunction(url);
    if (viaServer != null && !viaServer.isEmpty) return viaServer;

    final viaDevice = await _viaOnDeviceScrape(url);
    if (viaDevice != null && !viaDevice.isEmpty) return viaDevice;

    return viaServer ?? viaDevice;
  }

  // ── Tier 1: server-side extraction ─────────────────────────────────────────
  static Future<LinkMetadata?> _viaEdgeFunction(String url) async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('extract-metadata', body: {'url': url})
          .timeout(const Duration(seconds: 28));

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final meta = LinkMetadata.fromJson(data);
        return meta.isEmpty ? null : meta;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Tier 2: on-device Open Graph scrape (last resort) ──────────────────────
  static Future<LinkMetadata?> _viaOnDeviceScrape(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/120.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;
      final html = resp.body;

      final title = _meta(html, 'og:title') ??
          _meta(html, 'twitter:title') ??
          _titleTag(html);
      final description = _meta(html, 'og:description') ??
          _meta(html, 'twitter:description') ??
          _meta(html, 'description');
      var image = _meta(html, 'og:image') ??
          _meta(html, 'og:image:secure_url') ??
          _meta(html, 'twitter:image') ??
          _meta(html, 'twitter:image:src');
      final siteName = _meta(html, 'og:site_name');

      if (image != null && image.isNotEmpty) {
        image = _absoluteUrl(image, url);
      }

      final meta = LinkMetadata(
        title: _clean(title),
        description: _clean(description),
        imageUrl: image,
        siteName: _clean(siteName),
      );
      return meta.isEmpty ? null : meta;
    } catch (_) {
      return null;
    }
  }

  static String? _meta(String html, String key) {
    final escaped = RegExp.escape(key);
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)\\s*=\\s*["\']$escaped["\'][^>]*?content\\s*=\\s*["\']([^"\']*)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content\\s*=\\s*["\']([^"\']*)["\'][^>]*?(?:property|name)\\s*=\\s*["\']$escaped["\']',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null && m.group(1) != null && m.group(1)!.trim().isNotEmpty) {
        return m.group(1)!.trim();
      }
    }
    return null;
  }

  static String? _titleTag(String html) {
    final m = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1)?.trim();
  }

  static String _absoluteUrl(String src, String pageUrl) {
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    final base = Uri.tryParse(pageUrl);
    if (base == null) return src;
    if (src.startsWith('//')) return '${base.scheme}:$src';
    if (src.startsWith('/')) return '${base.scheme}://${base.host}$src';
    return src;
  }

  static String? _clean(String? s) {
    if (s == null) return null;
    var out = s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
    out = out.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out.isEmpty ? null : out;
  }
}

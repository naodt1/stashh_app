/// Maps a URL to a human platform name used for source filtering.
String? detectPlatform(String? url) {
  if (url == null || url.isEmpty) return null;
  final u = url.toLowerCase();
  if (u.contains('instagram.com') || u.contains('instagr.am')) return 'Instagram';
  if (u.contains('tiktok.com')) return 'TikTok';
  if (u.contains('youtube.com') || u.contains('youtu.be')) return 'YouTube';
  if (u.contains('pinterest.') || u.contains('pin.it')) return 'Pinterest';
  if (u.contains('twitter.com') || u.contains('x.com')) return 'X';
  if (u.contains('facebook.com') || u.contains('fb.watch')) return 'Facebook';
  if (u.contains('reddit.com')) return 'Reddit';
  if (u.contains('linkedin.com')) return 'LinkedIn';
  if (u.contains('vimeo.com')) return 'Vimeo';
  if (u.contains('threads.net')) return 'Threads';
  if (u.contains('twitch.tv')) return 'Twitch';
  if (u.startsWith('http')) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '');
    return (host == null || host.isEmpty) ? 'Web' : host;
  }
  return null;
}

/// The platforms we surface as quick filter chips.
const kFilterPlatforms = ['Instagram', 'TikTok', 'YouTube', 'Pinterest', 'X'];

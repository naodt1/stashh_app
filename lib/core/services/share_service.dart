import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

/// Wraps a share payload with type info so the UI knows how to present it.
class SharePayload {
  final String content;            // URL or text caption
  final String? filePath;          // local file path for media (video/image)
  final SharedMediaType mediaType;

  const SharePayload({
    required this.content,
    required this.mediaType,
    this.filePath,
  });

  bool get isUrl =>
      content.startsWith('http://') || content.startsWith('https://');

  bool get isVideo =>
      mediaType == SharedMediaType.video ||
      (filePath != null && _isVideoPath(filePath!));

  bool get isImage =>
      mediaType == SharedMediaType.image ||
      (filePath != null && _isImagePath(filePath!));

  static bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'm4v'].contains(ext);
  }

  static bool _isImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'].contains(ext);
  }

  String get displayContent => filePath ?? content;
}

class ShareService {
  static StreamSubscription<List<SharedMediaFile>>? _subscription;

  /// Registered by HomeScreen (or any screen that wants to handle shares)
  static Function(SharePayload)? _onShareReceived;

  /// Buffered while no handler is registered (app cold-started via share)
  static SharePayload? _buffered;

  static set onShareReceived(Function(SharePayload)? handler) {
    _onShareReceived = handler;
    if (handler != null && _buffered != null) {
      final payload = _buffered!;
      _buffered = null;
      // Defer a frame so the widget tree is fully mounted
      Future.delayed(const Duration(milliseconds: 300), () => handler(payload));
    }
  }

  static SharePayload? _extractPayload(List<SharedMediaFile> files) {
    if (files.isEmpty) return null;
    final file = files.first;

    // Android: text/URL shares come in file.path; iOS puts it in message
    final msg = file.message?.trim() ?? '';
    final path = file.path.trim();

    if (msg.isNotEmpty) {
      return SharePayload(
        content: msg,
        mediaType: file.type,
        filePath: path.isNotEmpty ? path : null,
      );
    }
    if (path.isNotEmpty) {
      return SharePayload(
        content: path,
        mediaType: file.type,
        filePath: path,
      );
    }
    return null;
  }

  static void _dispatch(List<SharedMediaFile> files) {
    final payload = _extractPayload(files);
    if (payload == null) return;

    if (_onShareReceived != null) {
      _onShareReceived!(payload);
    } else {
      _buffered = payload; // held until HomeScreen mounts
    }
  }

  static void init() {
    // Share intents are an Android/iOS-only concept — the plugin has no
    // web implementation, so skip entirely on web.
    if (kIsWeb) return;

    // Live stream (app already running, share comes in)
    _subscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(_dispatch);

    // Cold-start share (app was not running)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _dispatch(files);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  static void dispose() {
    _subscription?.cancel();
    _onShareReceived = null;
  }
}

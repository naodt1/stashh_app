class StashItem {
  final String id;
  final String userId;
  final String? categoryId; // user folder (manual)
  final String title;
  final String? description;
  final String? url;
  final String? thumbnailUrl;
  final String source;
  final String contentType;
  final String? rawContent;
  final bool isPinned;
  final bool isFavorite;
  final List<String> tags;
  final Map<String, dynamic>? metadata;

  // ── AI multi-dimensional classification ──────────────────────────────────
  final String? primaryCategory; // one of the 15 broad buckets
  final String? lengthBucket; // short | medium | long | unknown
  final List<String> mood;
  final List<String> intent;
  final String? skillLevel;
  final String? visualStyle;
  final String? creatorType;
  final String? language;
  final List<String> topics; // semantic/transcription topics
  final String? platform; // Instagram | TikTok | YouTube | …
  final String? transcript;
  final int? durationSeconds;

  final DateTime createdAt;
  final DateTime updatedAt;

  StashItem({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.title,
    this.description,
    this.url,
    this.thumbnailUrl,
    this.source = 'manual',
    this.contentType = 'link',
    this.rawContent,
    this.isPinned = false,
    this.isFavorite = false,
    this.tags = const [],
    this.metadata,
    this.primaryCategory,
    this.lengthBucket,
    this.mood = const [],
    this.intent = const [],
    this.skillLevel,
    this.visualStyle,
    this.creatorType,
    this.language,
    this.topics = const [],
    this.platform,
    this.transcript,
    this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  static List<String> _strList(dynamic v) =>
      (v is List) ? v.map((e) => e.toString()).toList() : const <String>[];

  factory StashItem.fromJson(Map<String, dynamic> json) {
    return StashItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      source: json['source'] as String? ?? 'manual',
      contentType: json['content_type'] as String? ?? 'link',
      rawContent: json['raw_content'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      tags: _strList(json['tags']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      primaryCategory: json['primary_category'] as String?,
      lengthBucket: json['length_bucket'] as String?,
      mood: _strList(json['mood']),
      intent: _strList(json['intent']),
      skillLevel: json['skill_level'] as String?,
      visualStyle: json['visual_style'] as String?,
      creatorType: json['creator_type'] as String?,
      language: json['language'] as String?,
      topics: _strList(json['topics']),
      platform: json['platform'] as String?,
      transcript: json['transcript'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'category_id': categoryId,
        'title': title,
        'description': description,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'source': source,
        'content_type': contentType,
        'raw_content': rawContent,
        'is_pinned': isPinned,
        'is_favorite': isFavorite,
        'tags': tags,
        'metadata': metadata,
        'primary_category': primaryCategory,
        'length_bucket': lengthBucket,
        'mood': mood,
        'intent': intent,
        'skill_level': skillLevel,
        'visual_style': visualStyle,
        'creator_type': creatorType,
        'language': language,
        'topics': topics,
        'platform': platform,
        'transcript': transcript,
        'duration_seconds': durationSeconds,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  StashItem copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? title,
    String? description,
    String? url,
    String? thumbnailUrl,
    String? source,
    String? contentType,
    String? rawContent,
    bool? isPinned,
    bool? isFavorite,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    String? primaryCategory,
    String? lengthBucket,
    List<String>? mood,
    List<String>? intent,
    String? skillLevel,
    String? visualStyle,
    String? creatorType,
    String? language,
    List<String>? topics,
    String? platform,
    String? transcript,
    int? durationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StashItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      source: source ?? this.source,
      contentType: contentType ?? this.contentType,
      rawContent: rawContent ?? this.rawContent,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      lengthBucket: lengthBucket ?? this.lengthBucket,
      mood: mood ?? this.mood,
      intent: intent ?? this.intent,
      skillLevel: skillLevel ?? this.skillLevel,
      visualStyle: visualStyle ?? this.visualStyle,
      creatorType: creatorType ?? this.creatorType,
      language: language ?? this.language,
      topics: topics ?? this.topics,
      platform: platform ?? this.platform,
      transcript: transcript ?? this.transcript,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

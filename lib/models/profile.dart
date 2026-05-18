class Profile {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final bool isPro;
  final int itemsCount;
  final int foldersCount;
  final int streakDays;
  final double storageUsedMb;
  final double storageLimitMb;

  Profile({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.isPro = false,
    this.itemsCount = 0,
    this.foldersCount = 0,
    this.streakDays = 0,
    this.storageUsedMb = 0,
    this.storageLimitMb = 1024,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String?,
      isPro: json['is_pro'] as bool? ?? false,
      itemsCount: json['items_count'] as int? ?? 0,
      foldersCount: json['folders_count'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      storageUsedMb: (json['storage_used_mb'] as num?)?.toDouble() ?? 0,
      storageLimitMb: (json['storage_limit_mb'] as num?)?.toDouble() ?? 1024,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'is_pro': isPro,
        'items_count': itemsCount,
        'folders_count': foldersCount,
        'streak_days': streakDays,
        'storage_used_mb': storageUsedMb,
        'storage_limit_mb': storageLimitMb,
      };

  Profile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    bool? isPro,
    int? itemsCount,
    int? foldersCount,
    int? streakDays,
    double? storageUsedMb,
    double? storageLimitMb,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPro: isPro ?? this.isPro,
      itemsCount: itemsCount ?? this.itemsCount,
      foldersCount: foldersCount ?? this.foldersCount,
      streakDays: streakDays ?? this.streakDays,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
      storageLimitMb: storageLimitMb ?? this.storageLimitMb,
    );
  }
}

class Category {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final int itemCount;
  final bool pinned;
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    this.itemCount = 0,
    this.pinned = false,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'folder',
      color: json['color'] as String? ?? '#000000',
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Category copyWith({int? itemCount, bool? pinned}) => Category(
        id: id,
        userId: userId,
        name: name,
        icon: icon,
        color: color,
        itemCount: itemCount ?? this.itemCount,
        pinned: pinned ?? this.pinned,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'icon': icon,
        'color': color,
        'item_count': itemCount,
        'pinned': pinned,
      };
}

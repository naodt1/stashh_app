/// A user-created collection. Items can belong to many collections at once
/// (membership lives in the collection_items join table).
class Collection {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final int position;
  final int itemCount; // populated by joined count when available
  final DateTime createdAt;

  Collection({
    required this.id,
    required this.userId,
    required this.name,
    this.icon = 'collections_bookmark',
    this.position = 0,
    this.itemCount = 0,
    required this.createdAt,
  });

  factory Collection.fromJson(Map<String, dynamic> j) {
    int count = 0;
    final ci = j['collection_items'];
    if (ci is List && ci.isNotEmpty && ci.first is Map) {
      count = (ci.first['count'] as num?)?.toInt() ?? 0;
    } else if (j['item_count'] != null) {
      count = (j['item_count'] as num).toInt();
    }
    return Collection(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      name: j['name'] as String? ?? 'Untitled',
      icon: j['icon'] as String? ?? 'collections_bookmark',
      position: (j['position'] as num?)?.toInt() ?? 0,
      itemCount: count,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile.dart';
import '../../models/category.dart';
import '../../models/stash_item.dart';
import '../../models/collection.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;

  // Auth
  static User? get currentUser => _client.auth.currentUser;
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Profile
  static Future<Profile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('profiles').update(updates).eq('id', user.id);
  }

  // Categories
  static Future<List<Category>> getCategories() async {
    final user = currentUser;
    if (user == null) return [];

    final data = await _client
        .from('categories')
        .select()
        .eq('user_id', user.id)
        .order('name');

    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  static Future<Category> createCategory(Map<String, dynamic> data) async {
    final result = await _client
        .from('categories')
        .insert(data)
        .select()
        .single();
    return Category.fromJson(result);
  }

  static Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  /// Returns the id of the user's folder with [name] (case-insensitive),
  /// creating it if it doesn't exist. Powers AI auto-filing.
  static Future<String?> getOrCreateCategory(String name) async {
    final user = currentUser;
    if (user == null || name.trim().isEmpty) return null;
    final clean = name.trim();

    final existing = await _client
        .from('categories')
        .select('id')
        .eq('user_id', user.id)
        .ilike('name', clean)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await _client
        .from('categories')
        .insert({
          'user_id': user.id,
          'name': clean,
          'icon': 'folder',
          'color': '#000000',
          'item_count': 0,
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  // Stash Items
  static Future<List<StashItem>> getItems({String? categoryId, int limit = 50}) async {
    final user = currentUser;
    if (user == null) return [];

    var query = _client
        .from('stash_items')
        .select()
        .eq('user_id', user.id);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final data = await query
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => StashItem.fromJson(e)).toList();
  }

  static Future<List<StashItem>> getRecentItems({int limit = 10}) async {
    final user = currentUser;
    if (user == null) return [];

    final data = await _client
        .from('stash_items')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => StashItem.fromJson(e)).toList();
  }

  static Future<StashItem> createItem(Map<String, dynamic> data) async {
    final result = await _client
        .from('stash_items')
        .insert(data)
        .select()
        .single();
    return StashItem.fromJson(result);
  }

  static Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    await _client.from('stash_items').update(updates).eq('id', id);
  }

  static Future<void> deleteItem(String id) async {
    await _client.from('stash_items').delete().eq('id', id);
  }

  static Future<List<StashItem>> searchItems(String query) async {
    return queryItems(text: query);
  }

  /// Unified filtered query powering Smart Collections + advanced search.
  /// All filters are optional and AND-combined; multi-label dimensions
  /// (mood/intent/topics) use array-overlap ("any of").
  static Future<List<StashItem>> queryItems({
    String? text,
    String? primaryCategory,
    String? lengthBucket,
    String? skillLevel,
    String? source,
    String? contentType,
    String? platform,
    List<String>? moods,
    List<String>? intents,
    List<String>? topics,
    int? sinceDays,
    int limit = 50,
  }) async {
    final user = currentUser;
    if (user == null) return [];

    var q = _client.from('stash_items').select().eq('user_id', user.id);

    if (text != null && text.trim().isNotEmpty) {
      final t = text.trim();
      q = q.or(
        'title.ilike.%$t%,description.ilike.%$t%,raw_content.ilike.%$t%',
      );
    }
    if (primaryCategory != null) q = q.eq('primary_category', primaryCategory);
    if (lengthBucket != null) q = q.eq('length_bucket', lengthBucket);
    if (skillLevel != null) q = q.eq('skill_level', skillLevel);
    if (source != null) q = q.eq('source', source);
    if (contentType != null) q = q.eq('content_type', contentType);
    if (platform != null) q = q.eq('platform', platform);
    if (moods != null && moods.isNotEmpty) q = q.overlaps('mood', moods);
    if (intents != null && intents.isNotEmpty) {
      q = q.overlaps('intent', intents);
    }
    if (topics != null && topics.isNotEmpty) {
      q = q.overlaps('topics', topics);
    }
    if (sinceDays != null) {
      final since = DateTime.now()
          .toUtc()
          .subtract(Duration(days: sinceDays))
          .toIso8601String();
      q = q.gte('created_at', since);
    }

    final data = await q
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => StashItem.fromJson(e)).toList();
  }

  // Storage — thumbnails
  static Future<String?> uploadThumbnail(String itemId, Uint8List bytes) async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final path = '${user.id}/$itemId.jpg';
      await _client.storage
          .from('stash-thumbnails')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      return _client.storage.from('stash-thumbnails').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  static Future<int> getItemCount() async {
    final user = currentUser;
    if (user == null) return 0;

    final data = await _client
        .from('stash_items')
        .select('id')
        .eq('user_id', user.id);

    return (data as List).length;
  }

  // ── Semantic search (pgvector) ────────────────────────────────────────────
  /// Cosine-similarity search over item embeddings. [queryEmbedding] is a
  /// 1536-dim vector from AiService.embed(). Falls back to [] on error so
  /// callers can degrade to keyword search.
  static Future<List<StashItem>> semanticSearch(
    List<double> queryEmbedding, {
    int matchCount = 30,
  }) async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final data = await _client.rpc('match_stash_items', params: {
        'query_embedding': queryEmbedding,
        'match_user_id': user.id,
        'match_count': matchCount,
      });
      return (data as List).map((e) => StashItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── User-created collections ──────────────────────────────────────────────
  static Future<List<Collection>> getCollections() async {
    final user = currentUser;
    if (user == null) return [];
    final data = await _client
        .from('collections')
        .select('*, collection_items(count)')
        .eq('user_id', user.id)
        .order('position')
        .order('created_at');
    return (data as List).map((e) => Collection.fromJson(e)).toList();
  }

  static Future<Collection> createCollection(String name,
      {String icon = 'collections_bookmark'}) async {
    final user = currentUser!;
    final result = await _client
        .from('collections')
        .insert({'user_id': user.id, 'name': name, 'icon': icon})
        .select()
        .single();
    return Collection.fromJson(result);
  }

  static Future<void> deleteCollection(String id) async {
    await _client.from('collections').delete().eq('id', id);
  }

  static Future<void> renameCollection(String id, String name) async {
    await _client.from('collections').update({'name': name}).eq('id', id);
  }

  static Future<void> reorderCollections(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _client
          .from('collections')
          .update({'position': i}).eq('id', orderedIds[i]);
    }
  }

  static Future<void> addItemToCollection(
      String collectionId, String itemId) async {
    await _client.from('collection_items').upsert(
      {'collection_id': collectionId, 'item_id': itemId},
      onConflict: 'collection_id,item_id',
    );
  }

  static Future<void> removeItemFromCollection(
      String collectionId, String itemId) async {
    await _client
        .from('collection_items')
        .delete()
        .eq('collection_id', collectionId)
        .eq('item_id', itemId);
  }

  /// Bulk-add many items to a collection in one call.
  static Future<void> addItemsToCollection(
      String collectionId, List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    await _client.from('collection_items').upsert(
          itemIds
              .map((id) => {'collection_id': collectionId, 'item_id': id})
              .toList(),
          onConflict: 'collection_id,item_id',
        );
  }

  static Future<List<StashItem>> getCollectionItems(String collectionId) async {
    final data = await _client
        .from('collection_items')
        .select('stash_items(*)')
        .eq('collection_id', collectionId)
        .order('added_at', ascending: false);
    return (data as List)
        .map((e) => e['stash_items'])
        .where((e) => e != null)
        .map((e) => StashItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Collection IDs a given item currently belongs to (for the picker).
  static Future<Set<String>> getCollectionIdsForItem(String itemId) async {
    final data = await _client
        .from('collection_items')
        .select('collection_id')
        .eq('item_id', itemId);
    return (data as List).map((e) => e['collection_id'] as String).toSet();
  }
}

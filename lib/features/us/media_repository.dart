import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// 共同歌单 + 一起看片仓储。
class MediaRepository {
  Future<String?> _coupleId() => currentCoupleId();

  Future<List<Map<String, dynamic>>> songs() async {
    final cid = await _coupleId();
    if (cid == null) return [];
    final rows = await supabase
        .from('songlist')
        .select()
        .eq('couple_id', cid)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addSong(String title, String? artist) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    if (cid == null) return;
    await supabase.from('songlist').insert({
      'couple_id': cid,
      'added_by': uid,
      'title': title,
      'artist': artist,
    });
  }

  Future<void> removeSong(String id) async =>
      supabase.from('songlist').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> watch() async {
    final cid = await _coupleId();
    if (cid == null) return [];
    final rows = await supabase
        .from('watchlist')
        .select()
        .eq('couple_id', cid)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addWatch(String title, String? note) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    if (cid == null) return;
    await supabase.from('watchlist').insert({
      'couple_id': cid,
      'added_by': uid,
      'title': title,
      'note': note,
    });
  }

  Future<void> toggleWatched(String id, bool v) async =>
      supabase.from('watchlist').update({'watched': v}).eq('id', id);

  Future<void> removeWatch(String id) async =>
      supabase.from('watchlist').delete().eq('id', id);
}

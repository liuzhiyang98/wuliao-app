import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/local_db.dart';
import '../../core/supabase.dart';
import '../../models/memory.dart';

class MemoriesRepository {
  /// 读取两人共享的回忆（联网读 Supabase，无网读本地缓存）
  Future<List<Memory>> list() async {
    final cid = await _coupleId();
    if (cid == null) return [];
    try {
      final rows = await supabase
          .from('memories')
          .select()
          .eq('couple_id', cid)
          .order('created_at', ascending: false);
      for (final r in rows) {
        await LocalDb.cacheMemory(r);
      }
      return rows.map((r) => Memory.fromJson(r)).toList();
    } catch (_) {
      final cached = await LocalDb.cachedMemories();
      return cached.map((m) => Memory.fromJson(m)).toList();
    }
  }

  /// 新增一条回忆（文字或照片），同步到 Supabase
  Future<void> add(Memory m) async {
    final cid = await _coupleId();
    if (cid == null) return;
    final row = {
      ...m.toJson(),
      'couple_id': cid,
      'author_id': supabase.auth.currentUser!.id,
    };
    await supabase.from('memories').insert(row);
    await LocalDb.cacheMemory(row);
  }

  /// 选一张照片：上传到 Supabase Storage，存可访问链接
  Future<void> addPhoto(String localPath) async {
    final cid = await _coupleId();
    if (cid == null) return;
    final file = File(localPath);
    final path = '$cid/${const Uuid().v4()}.jpg';
    await supabase.storage.from('memories').upload(path, file);
    final url = supabase.storage.from('memories').getPublicUrl(path);
    await add(Memory(
      uuid: const Uuid().v4(),
      type: 'photo',
      content: url,
      createdAt: DateTime.now(),
    ));
  }

  String newUuid() => const Uuid().v4();

  Future<String?> _coupleId() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final r = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', uid)
        .single();
    return r['couple_id'];
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// 100 件小事的共享完成集合（int 数组存在 couple_meta.done_bucket）。
class CoupleMetaRepository {
  Future<String?> _coupleId() => currentCoupleId();

  Future<List<int>> doneBucket() async {
    final cid = await _coupleId();
    if (cid == null) return [];
    final r = await supabase
        .from('couple_meta')
        .select('done_bucket')
        .eq('couple_id', cid)
        .maybeSingle();
    if (r == null) {
      await supabase
          .from('couple_meta')
          .insert({'couple_id': cid, 'done_bucket': []});
      return [];
    }
    final v = r['done_bucket'];
    if (v == null) return [];
    return List<int>.from(v);
  }

  Future<void> toggle(int index, bool done) async {
    final cid = await _coupleId();
    if (cid == null) return;
    final cur = await doneBucket();
    final set = Set<int>.from(cur);
    if (done) {
      set.add(index);
    } else {
      set.remove(index);
    }
    final sorted = set.toList()..sort();
    await supabase.from('couple_meta').upsert(
      {
        'couple_id': cid,
        'done_bucket': sorted,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'couple_id',
    );
  }
}

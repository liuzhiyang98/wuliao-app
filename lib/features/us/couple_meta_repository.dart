import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// 100 件小事的共享完成集合。
/// 数据库 schema: couple_meta(couple_id PK, display_name, notes, widget_config JSONB, updated_at)
/// 注意：数据库没有 done_bucket 字段，使用 widget_config 来存储进度
class CoupleMetaRepository {
  Future<String?> _coupleId() => currentCoupleId();

  /// 获取已完成的 100件小事 索引列表
  Future<List<int>> doneBucket() async {
    final cid = await _coupleId();
    if (cid == null) return [];
    final r = await supabase
        .from('couple_meta')
        .select('widget_config')
        .eq('couple_id', cid)
        .maybeSingle();
    if (r == null) {
      // 初始化记录
      await supabase.from('couple_meta').insert({
        'couple_id': cid,
        'widget_config': {'done_bucket': []},
      });
      return [];
    }
    final config = r['widget_config'];
    if (config == null || config is! Map) return [];
    // 从 widget_config JSONB 中提取 done_bucket 数组
    final bucket = config['done_bucket'];
    if (bucket == null) return [];
    return List<int>.from(bucket);
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

    // 更新 widget_config 中的 done_bucket
    await supabase.from('couple_meta').upsert(
      {
        'couple_id': cid,
        'widget_config': {'done_bucket': sorted},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'couple_id',
    );
  }
}

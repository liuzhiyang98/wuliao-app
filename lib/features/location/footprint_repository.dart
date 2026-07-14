import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// 爱情足迹地图的数据仓储。
/// - history：两人历史位置点（按天筛选），用于绘制轨迹折线。
/// - memoriesWithLocation：带坐标的回忆，作为足迹上的「回忆点」。
/// - geofences：自动报备地点，作为足迹上的「地点」标记。
class FootprintRepository {
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

  Future<List<Map<String, dynamic>>> history({int days = 30}) async {
    final cid = await _coupleId();
    if (cid == null) return [];
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();
    final rows = await supabase
        .from('location_history')
        .select('user_id, lat, lng, created_at')
        .eq('couple_id', cid)
        .gte('created_at', since)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> memoriesWithLocation() async {
    final cid = await _coupleId();
    if (cid == null) return [];
    final rows = await supabase
        .from('memories')
        .select('id, content, lat, lng, created_at')
        .eq('couple_id', cid);
    final list = List<Map<String, dynamic>>.from(rows);
    // 只保留带坐标的回忆（Dart 侧过滤，避开 is-null 的 API 歧义）
    return list.where((m) => m['lat'] != null && m['lng'] != null).toList();
  }

  Future<List<Map<String, dynamic>>> geofences() async {
    final rows = await supabase
        .from('geofences')
        .select('name, latitude, longitude, radius_m');
    return List<Map<String, dynamic>>.from(rows);
  }
}

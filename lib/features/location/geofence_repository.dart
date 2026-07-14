import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import 'background_credentials.dart';
import 'notification_service.dart';
import 'place_emoji.dart';

/// 地理围栏（自动报备地点）的前台仓储 + 伴侣实时报备监听。
class GeofenceRepository {
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

  Future<List<Map<String, dynamic>>> list() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('geofences')
        .select()
        .eq('owner_id', uid)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> add({
    required String name,
    required double lat,
    required double lng,
    required double radiusM,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    await supabase.from('geofences').insert({
      'owner_id': uid,
      'couple_id': cid,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'radius_m': radiusM,
    });
    // 刷新后台凭证里的围栏名称缓存
    await refreshBgCredentials();
  }

  Future<void> remove(String id) async {
    await supabase.from('geofences').delete().eq('id', id);
  }

  /// 监听伴侣的自动报备事件：对方一进门/出门，这边立刻弹本地通知。
  /// 返回 RealtimeChannel，页面 dispose 时调用 .unsubscribe()。
  /// 注意：伴侣 App 必须存活（前台或后台）才能收到；被杀死后需接入 FCM/APNs。
  RealtimeChannel watchPartnerCheckins() {
    final uid = supabase.auth.currentUser!.id;
    final channel = supabase.channel('checkins_$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'checkins',
      // 注意：新版 realtime_client 的 PostgresChangeFilter 使用命名参数，
      // 为兼容性，这里在回调内过滤（版本无关方案）
      callback: (payload) {
        final row = payload.newRecord;
        // 只处理伴侣的报备事件（忽略自己的）
        if (row['user_id'] == uid) return;
        final name = (row['place_name'] as String?) ?? '某个地点';
        final isEnter = row['event_type'] == 'enter';
        final emoji = placeEmoji(name);
        final title = isEnter ? '$emoji 自动报备' : '🚪 自动报备';
        final body = isEnter ? 'Ta 到了$name' : 'Ta 离开了$name';
        NotificationService.show(
          id: (row['id'] ?? name).hashCode,
          title: title,
          body: body,
        );
      },
    );
    channel.subscribe();
    return channel;
  }
}

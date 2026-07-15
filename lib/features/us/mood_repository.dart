import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// 远程早晚安 + 当天心情仓储。
/// 数据库 schema:
///   greetings: (from_user_id, to_user_id, greeting_type, message)
///   moods: (user_id, mood_type, intensity, note, shared_with_partner)
class MoodRepository {
  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<String?> _coupleId() => currentCoupleId();

  Future<Map<String, dynamic>> status() async {
    final cid = await _coupleId();
    if (cid == null) return {
      'morningMe': false, 'eveningMe': false,
      'morningPartner': false, 'eveningPartner': false,
      'myMood': null, 'myNote': null, 'partnerMood': null,
    };

    final me = supabase.auth.currentUser!.id;

    // 获取情侣双方 ID
    final couple = await supabase
        .from('couples')
        .select('user_a, user_b')
        .eq('id', cid)
        .maybeSingle();
    if (couple == null) return {};

    final partnerId = couple['user_a'] == me ? couple['user_b'] : couple['user_a'];

    // 问候（greetings 表用 from_user_id + greeting_type）
    // 注意：数据库没有日期过滤，需要获取最近的记录
    bool morningMe = false, eveningMe = false;
    bool morningP = false, eveningP = false;
    try {
      final todayGreet = await supabase
          .from('greetings')
          .select()
          .or('from_user_id.eq.$me,from_user_id.eq.$partnerId')
          .gte('created_at', '${_today()}T00:00:00');
      for (final r in todayGreet) {
        final isMe = r['from_user_id'] == me;
        final type = r['greeting_type'] ?? '';
        if (type.contains('morning') || type.contains('goodmorning')) {
          if (isMe) morningMe = true; else morningP = true;
        } else if (type.contains('night') || type.contains('goodnight')) {
          if (isMe) eveningMe = true; else eveningP = true;
        }
      }
    } catch (_) {}

    // 心情（moods 表用 mood_type 而不是 mood，没有日期字段）
    String? myMood, myNote, partnerMood;
    try {
      final allMoods = await supabase
          .from('moods')
          .select()
          .or('user_id.eq.$me,user_id.eq.$partnerId')
          .order('created_at', ascending: false)
          .limit(2);
      for (final r in allMoods) {
        if (r['user_id'] == me) {
          myMood = r['mood_type'];
          myNote = r['note'];
        } else {
          partnerMood = r['mood_type'];
        }
      }
    } catch (_) {}

    return {
      'morningMe': morningMe,
      'eveningMe': eveningMe,
      'morningPartner': morningP,
      'eveningPartner': eveningP,
      'myMood': myMood,
      'myNote': myNote,
      'partnerMood': partnerMood,
    };
  }

  Future<void> greet(String kind) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    if (cid == null) return;

    // 获取伴侣的 user_id
    final couple = await supabase
        .from('couples')
        .select('user_a, user_b')
        .eq('id', cid)
        .single();
    final partnerId = couple['user_a'] == uid ? couple['user_b'] : couple['user_a'];

    // greetings 表: from_user_id, to_user_id, greeting_type, message
    final greetingType = kind == 'morning' ? 'goodmorning' : 'goodnight';
    await supabase.from('greetings').insert({
      'from_user_id': uid,
      'to_user_id': partnerId,
      'greeting_type': greetingType,
      'message': kind == 'morning' ? '早安 ☀️' : '晚安 🌙',
    });
  }

  Future<void> saveMood(String mood, String note) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    if (cid == null) return;

    // moods 表: user_id, mood_type, intensity, note, shared_with_partner
    await supabase.from('moods').insert({
      'user_id': uid,
      'mood_type': mood,
      'intensity': 5,
      'note': note,
      'shared_with_partner': true,
    });
  }
}

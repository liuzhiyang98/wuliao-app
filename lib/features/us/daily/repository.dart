import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import 'us_data.dart';

/// 每日一问：按日期确定性出题，两人都答完后互相可见。
/// 数据库 schema: daily_answers(id, couple_id, question_date, question_text, answer_a, answer_b, ...)
class DailyRepository {
  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String todayQuestion() {
    final epoch = DateTime(2024, 1, 1);
    final idx = DateTime.now().difference(epoch).inDays % dailyQuestions.length;
    return dailyQuestions[idx];
  }

  Future<String?> _coupleId() => currentCoupleId();

  /// 返回 {question, mine, partner, both}
  /// 数据库用 answer_a/answer_b (基于 user_a/user_b 的位置) 而不是 user_id
  Future<Map<String, dynamic>> status() async {
    final cid = await _coupleId();
    if (cid == null) return {'question': todayQuestion(), 'mine': null, 'partner': null, 'both': false};
    final q = todayQuestion();
    final rows = await supabase
        .from('daily_answers')
        .select()
        .eq('couple_id', cid)
        .eq('question_date', _today());

    // 获取当前用户在 couple 中的角色（a 还是 b）
    final me = supabase.auth.currentUser!.id;
    String? myAnswer;
    String? partnerAnswer;
    bool both = false;

    if (rows.isNotEmpty) {
      final r = rows.first;
      // 判断当前用户是 a 还是 b，然后取对应字段
      final couple = await supabase.from('couples').select('user_a, user_b').eq('id', cid).maybeSingle();
      if (couple != null) {
        final isUserA = couple['user_a'] == me;
        myAnswer = isUserA ? r['answer_a'] : r['answer_b'];
        partnerAnswer = isUserA ? r['answer_b'] : r['answer_a'];
      }
      both = myAnswer != null && partnerAnswer != null;
    }

    return {
      'question': q,
      'mine': myAnswer,
      'partner': partnerAnswer,
      'both': both,
    };
  }

  Future<void> answer(String text) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    if (cid == null) return;

    // 获取或创建记录，更新对应字段
    final existing = await supabase
        .from('daily_answers')
        .select()
        .eq('couple_id', cid)
        .eq('question_date', _today())
        .maybeSingle();

    final couple = await supabase.from('couples').select('user_a').eq('id', cid).single();
    final isUserA = couple['user_a'] == uid;
    final answerField = isUserA ? 'answer_a' : 'answer_b';
    const timeFieldA = 'answered_at_a';
    const timeFieldB = 'answered_at_b';
    final timeField = isUserA ? timeFieldA : timeFieldB;

    if (existing != null) {
      await supabase.from('daily_answers').update({
        answerField: text,
        timeField: DateTime.now().toUtc().toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      // 新建时需要同时填入双方字段（NOT NULL 约束）
      await supabase.from('daily_answers').insert({
        'couple_id': cid,
        'question_date': _today(),
        'question_text': todayQuestion(),
        'answer_a': isUserA ? text : null,
        'answer_b': isUserA ? null : text,
        isUserA ? timeField : timeFieldB: DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}

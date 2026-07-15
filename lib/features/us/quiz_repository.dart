import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import 'us_data.dart';

/// 默契测试：两人各自悄悄选 A/B，都选完揭示是否一致。
/// 数据库 schema: quiz_rounds(id, couple_id, question_text, options JSONB,
///   correct_index, answer_a_index, answer_b_index, score_a, score_b, ...)
class QuizRepository {
  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, String> todayQuestion() {
    final epoch = DateTime(2024, 1, 1);
    final idx = DateTime.now().difference(epoch).inDays % quizQuestions.length;
    return quizQuestions[idx];
  }

  Future<String?> _coupleId() => currentCoupleId();

  Future<Map<String, dynamic>> status() async {
    final cid = await _coupleId();
    if (cid == null) return {'q': todayQuestion(), 'myChoice': null, 'partnerChoice': null, 'both': false, 'match': false};
    final q = todayQuestion();
    final rows = await supabase
        .from('quiz_rounds')
        .select()
        .eq('couple_id', cid)
        .gte('created_at', '${_today()}T00:00:00');

    final me = supabase.auth.currentUser!.id;
    String? mine;
    String? partner;
    bool both = false;

    if (rows.isNotEmpty) {
      // 获取当前用户角色（a 还是 b）
      final couple = await supabase.from('couples').select('user_a').eq('id', cid).maybeSingle();
      if (couple != null) {
        final isUserA = couple['user_a'] == me;
        for (final r in rows) {
          final myIdx = isUserA ? r['answer_a_index'] : r['answer_b_index'];
          final partnerIdx = isUserA ? r['answer_b_index'] : r['answer_a_index'];
          if (myIdx != null) mine = myIdx == 0 ? 'a' : 'b';  // 简化：用 a/b 表示选项
          if (partnerIdx != null) partner = partnerIdx == 0 ? 'a' : 'b';
        }
      }
      both = mine != null && partner != null;
    }

    return {
      'q': q,
      'myChoice': mine,
      'partnerChoice': partner,
      'both': both,
      'match': both && mine == partner,
    };
  }

  Future<void> choose(String choice) async {
    final uid = supabase.auth.currentUser!.id;
    final cid = await _coupleId();
    if (cid == null) return;
    final q = todayQuestion();

    // 获取用户角色
    final couple = await supabase.from('couples').select('user_a').eq('id', cid).single();
    final isUserA = couple['user_a'] == uid;
    const idxFieldA = 'answer_a_index';
    const idxFieldB = 'answer_b_index';
    const scoreFieldA = 'score_a';
    const scoreFieldB = 'score_b';
    
    final idxChoice = choice.toLowerCase() == 'a' ? 0 : 1;
    final idxField = isUserA ? idxFieldA : idxFieldB;

    // 检查今日是否已有记录
    final existing = await supabase
        .from('quiz_rounds')
        .select()
        .eq('couple_id', cid)
        .gte('created_at', '${_today()}T00:00:00')
        .maybeSingle();

    if (existing != null) {
      await supabase.from('quiz_rounds').update({
        idxField: idxChoice,
        isUserA ? scoreFieldA : scoreFieldB: 10,
        'status': 'active',
      }).eq('id', existing['id']);
    } else {
      await supabase.from('quiz_rounds').insert({
        'couple_id': cid,
        'question_text': q['q'],
        'options': [q['a'], q['b']],  // 存为 JSONB 数组
        isUserA ? idxFieldA : idxFieldB: idxChoice,
        isUserA ? scoreFieldA : scoreFieldB: 10,
        'status': 'active',
      });
    }
  }
}

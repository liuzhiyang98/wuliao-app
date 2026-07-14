import 'package:supabase_flutter/supabase_flutter.dart';

// ⚠️ 必须配置：在 https://supabase.com 新建免费项目，
// 打开 Project Settings → API，复制下面两个值填入。
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

/// 检查 Supabase 是否已配置（占位符未替换时返回 false）
bool get isSupabaseConfigured =>
    supabaseUrl != 'YOUR_SUPABASE_URL' &&
    supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
    supabaseUrl.startsWith('http');

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;

/// 当前用户所在的情侣空间 id（隐私校验依赖它）。
Future<String?> currentCoupleId() async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  try {
    final r = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', uid)
        .single();
    return r['couple_id'] as String?;
  } catch (_) {
    return null;
  }
}

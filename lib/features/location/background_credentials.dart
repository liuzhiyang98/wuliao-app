import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// 后台隔离（isolate）无法直接访问前台 Supabase 客户端，
/// 因此把「发往 Supabase 所需的最小凭证」存进系统安全存储，
/// 后台回调里再读出来用原生 HTTP 直写 REST 接口。
const _storage = FlutterSecureStorage();
const _kCreds = 'wuliao.bg_credentials';

class BgCredentials {
  final String url;
  final String anonKey;
  final String accessToken;
  final String userId;
  final String? coupleId;

  BgCredentials({
    required this.url,
    required this.anonKey,
    required this.accessToken,
    required this.userId,
    this.coupleId,
  });

  Map<String, String> toMap() => {
        'url': url,
        'anonKey': anonKey,
        'accessToken': accessToken,
        'userId': userId,
        if (coupleId != null) 'coupleId': coupleId!,
      };

  static BgCredentials? fromMap(Map<String, String> m) {
    if (m['url'] == null ||
        m['anonKey'] == null ||
        m['accessToken'] == null ||
        m['userId'] == null) {
      return null;
    }
    return BgCredentials(
      url: m['url']!,
      anonKey: m['anonKey']!,
      accessToken: m['accessToken']!,
      userId: m['userId']!,
      coupleId: m['coupleId'],
    );
  }
}

Future<void> saveBgCredentials(BgCredentials c) async {
  final map = <String, String>{};
  c.toMap().forEach((k, v) => map[k] = v);
  await _storage.write(key: _kCreds, value: jsonEncode(map));
}

Future<BgCredentials?> loadBgCredentials() async {
  final s = await _storage.read(key: _kCreds);
  if (s == null) return null;
  try {
    final decoded = Map<String, dynamic>.from(jsonDecode(s));
    final map = <String, String>{};
    decoded.forEach((k, v) => map[k] = v?.toString() ?? '');
    return BgCredentials.fromMap(map);
  } catch (_) {
    return null;
  }
}

/// 登录成功 / 配对完成后调用，刷新后台所需凭证（含最新 couple_id）。
Future<void> refreshBgCredentials() async {
  final user = supabase.auth.currentUser;
  final session = supabase.auth.currentSession;
  if (user == null || session == null) return;
  String? coupleId;
  try {
    final r = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', user.id)
        .single();
    coupleId = r['couple_id'];
  } catch (_) {
    // 尚未绑定，coupleId 留空，后台定位会在绑定后再启动
  }
  await saveBgCredentials(BgCredentials(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    accessToken: session.accessToken,
    userId: user.id,
    coupleId: coupleId,
  ));
}

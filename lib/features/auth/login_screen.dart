import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../location/background_credentials.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 点击邮件里的魔法链接登录后，自动进入首页
    supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        await refreshBgCredentials();
        context.go('/');
      }
    });
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;

    // 检查 Supabase 是否已配置
    if (!isSupabaseConfigured) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ 需要配置 Supabase'),
            content: const Text(
              'App 还没有连接到后端数据库。\n\n'
              '请开发者到 supabase.com 创建免费项目，'
              '然后将 URL 和 Anon Key 填入代码中。\n\n'
              '（这只需要做一次）',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOtp(
        email: email,
        // Web 下把回跳地址锁定为当前站点（含 /wuliao_app 子路径）。
        // 这样即使 Supabase 后台 Site URL 配错，邮件里的魔法链接也不会 404。
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录链接已发到邮箱，打开即可进入 💌')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('出错了：$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('吾俩',
                  style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE96A8B))),
              const SizedBox(height: 8),
              const Text('只属于我们两个人的小世界'),
              const SizedBox(height: 28),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _loading
                  ? const CircularProgressIndicator()
                  : FilledButton(onPressed: _send, child: const Text('发送登录邮件')),
              const SizedBox(height: 12),
              const Text('用邮箱魔法链接登录，无需密码，两人各登各的。',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

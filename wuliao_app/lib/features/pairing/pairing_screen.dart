import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../core/supabase.dart';
import '../location/background_credentials.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _code = TextEditingController();
  String? _myCode;
  bool _loading = false;

  /// 生成 6 位大写字母配对码
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 去掉易混淆字符
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final code = _generateCode();

      // 创建情侣空间（只有 user_a，等待对方加入）
      await supabase.from('couples').insert({
        'user_a': uid,
        'status': 'active',
        'invite_code': code,
      });
      await refreshBgCredentials();
      setState(() => _myCode = code);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final code = _code.text.trim().toUpperCase();

      // 查找匹配的情侣空间并加入（设置 user_b）
      final res = await supabase
          .from('couples')
          .update({'user_b': uid})
          .eq('invite_code', code)
          .filter('user_b', 'is', 'null') // 确保还没人加入
          .select('id')
          .maybeSingle();

      if (res == null) {
        _err('绑定码无效或已被使用');
        return;
      }
      await refreshBgCredentials();
      if (mounted) context.go('/');
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(dynamic e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('出错了：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('绑定彼此')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('一人创建，一人加入，用同一个 6 位码把彼此绑在一起 💞'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _create,
              child: const Text('创建情侣空间'),
            ),
            if (_myCode != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText('你的绑定码：$_myCode',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            const Divider(height: 40),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: '输入对方的绑定码',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loading ? null : _join,
              child: const Text('加入'),
            ),
          ],
        ),
      ),
    );
  }
}

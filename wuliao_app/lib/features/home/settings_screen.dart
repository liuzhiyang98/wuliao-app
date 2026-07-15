import 'package:flutter/material.dart';

/// 设置页面（存根）
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: const Center(child: Text('设置功能开发中...')),
  );
}

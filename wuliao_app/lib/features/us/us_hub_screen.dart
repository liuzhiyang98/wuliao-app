import 'package:flutter/material.dart';

/// "我们"中心页面（存根）
class UsHubScreen extends StatelessWidget {
  const UsHubScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我们')),
    body: const Center(child: Text('我们功能开发中...')),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase.dart';
import 'features/home/home_screen.dart';
import 'features/pairing/pairing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initSupabase();

  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      if (session == null && !state.matchedLocation.contains('/login')) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingScreen(),
      ),
    ],
  );

  runApp(WuliaoApp(router: router));
}

class WuliaoApp extends StatelessWidget {
  final GoRouter router;

  const WuliaoApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '吾俩',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE91E63),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      routerConfig: router,
    );
  }
}

/// 邮箱登录页面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邮箱和密码')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册成功！请查收验证邮件')),
          );
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) context.go('/');
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / Title
              const Icon(Icons.favorite, size: 64, color: Color(0xFFE91E63)),
              const SizedBox(height: 16),
              const Text(
                '吾俩',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? '创建账户' : '欢迎回来',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isSignUp ? '注册' : '登录'),
              ),
              const SizedBox(height: 16),

              // Toggle sign up / login
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? '已有账号？去登录' : '没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

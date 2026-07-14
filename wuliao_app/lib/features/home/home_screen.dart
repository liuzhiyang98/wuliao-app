import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../location/background_credentials.dart';
import '../location/background_location_service.dart';
import '../location/geofence_repository.dart';
import '../location/notification_service.dart';
import '../location/app_settings.dart';
import '../location/push_service.dart';
import '../memories/memories_screen.dart';
import 'settings_screen.dart';
import '../location/map_screen.dart';
import '../location/footprint_screen.dart';
import '../us/us_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  RealtimeChannel? _partnerChannel;

  @override
  void initState() {
    super.initState();
    _checkPairing();
  }

  Future<void> _checkPairing() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) context.go('/login');
      return;
    }
    // 从 couples 表检查是否已配对
    final r = await supabase
        .from('couples')
        .select('id')
        .or('user_a.eq.$uid,user_b.eq.$uid')
        .eq('status', 'active')
        .maybeSingle();
    if (r == null) {
      if (mounted) context.go('/pairing');
      return;
    }
    await refreshBgCredentials();
    await NotificationService.init();

    // FCM 初始化（被杀也能收推送）。失败则优雅降级到 Realtime 监听。
    await PushService.init();

    if (await getBgEnabled()) {
      await BackgroundLocationService().start();
    }

    // 已接入 FCM：通知由 Edge Function 经系统通道下发，不依赖 App 存活，
    // 因此不需要 Realtime 监听（也避免与 FCM 重复弹通知）。
    // 未接入 FCM（没配 Firebase）：退回 Realtime 监听，伴侣 App 存活时仍可收通知。
    if (!PushService.fcmReady) {
      _partnerChannel = GeofenceRepository().watchPartnerCheckins();
    }
  }

  @override
  void dispose() {
    _partnerChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('吾俩'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          UsHubScreen(),
          MapScreen(),
          MemoriesScreen(),
          FootprintScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline), label: '我们'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '位置'),
          BottomNavigationBarItem(
              icon: Icon(Icons.photo_album_outlined), label: '回忆'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined), label: '足迹'),
        ],
      ),
    );
  }
}

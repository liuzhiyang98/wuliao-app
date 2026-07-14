import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/login_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/settings_screen.dart';
import '../features/location/geofence_screen.dart';
import '../features/location/footprint_screen.dart';
import '../features/us/us_hub_screen.dart';
import '../features/us/milestones_screen.dart';
import '../features/us/daily_question_screen.dart';
import '../features/us/bucket_list_screen.dart';
import '../features/us/today_screen.dart';
import '../features/us/media_screen.dart';
import '../features/us/quiz_screen.dart';
import '../features/us/ar_photo_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      // 未登录先去登录；配对校验在 HomeScreen 内处理（无 couple_id 跳 /pairing）
      if (session == null) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/pairing', builder: (c, s) => const PairingScreen()),
      GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/geofences', builder: (c, s) => const GeofenceScreen()),
      GoRoute(path: '/footprint', builder: (c, s) => const FootprintScreen()),
      GoRoute(path: '/us', builder: (c, s) => const UsHubScreen()),
      GoRoute(path: '/milestones', builder: (c, s) => const MilestonesScreen()),
      GoRoute(path: '/daily', builder: (c, s) => const DailyQuestionScreen()),
      GoRoute(path: '/bucket', builder: (c, s) => const BucketListScreen()),
      GoRoute(path: '/today', builder: (c, s) => const TodayScreen()),
      GoRoute(path: '/media', builder: (c, s) => const MediaScreen()),
      GoRoute(path: '/quiz', builder: (c, s) => const QuizScreen()),
      GoRoute(path: '/arphoto', builder: (c, s) => const ArPhotoScreen()),
    ],
  );
});

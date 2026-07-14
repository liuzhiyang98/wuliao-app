import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:background_locator_2/background_locator_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart' hide LocationAccuracy;
import 'package:http/http.dart' as http;
import 'app_settings.dart';
import 'background_credentials.dart';
import 'notification_service.dart';
import 'place_emoji.dart';

const _storage = FlutterSecureStorage();
const _kGeofenceNames = 'wuliao.geofence_names';

/// 后台持续定位 + 地理围栏（自动报备）。
/// 用 background_locator_2 在 App 退到后台甚至被杀死后仍持续上报位置，
/// 围栏事件则触发自动报备：本地通知 + 写入 checkins（伴侣端实时收到）。
class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService _i = BackgroundLocationService._();
  factory BackgroundLocationService() => _i;

  bool _running = false;
  bool get isRunning => _running;

  Future<bool> _ensurePermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      p = await Geolocator.requestPermission();
    }
    return p != LocationPermission.denied &&
        p != LocationPermission.deniedForever;
  }

  /// 启动后台定位。未登录 / 未绑定会直接返回，等绑定后重试。
  Future<void> start() async {
    if (_running) return;
    if (!await _ensurePermission()) return;

    final creds = await loadBgCredentials();
    if (creds == null || creds.coupleId == null) return;

    await NotificationService.init();
    try {
      await BackgroundLocator.initialize();
    } catch (_) {}

    await BackgroundLocator.registerLocationUpdate(
      backgroundLocationCallback,
      initCallback: backgroundInitCallback,
      disposeCallback: backgroundDisposeCallback,
      autoStop: false,
      androidSettings: const AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: 60000, // 后台 60s 一次，足够顺滑又省电
        distanceFilter: 25,
        client: LocationClient.google,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: '吾俩后台位置',
          notificationTitle: '吾俩正在守护你们的位置',
          notificationMsg: '轻点返回，随时都能看到彼此 💞',
          notificationBigMsg: '后台定位已开启，随时都能看到彼此 💞',
          notificationIconColor: Color(0xFFE96A8B),
        ),
      ),
      iosSettings: const IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 25,
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: false,
      ),
    );

    final auto = await getAutoEnabled();
    if (auto) {
      final geofences = await _fetchGeofences(creds);
      if (geofences.isNotEmpty) {
        await BackgroundLocator.registerGeofence(
          geofenceCallback,
          initCallback: backgroundInitCallback,
          geofences: geofences,
        );
      }
    }

    _running = true;
  }

  Future<void> stop() async {
    if (!_running) return;
    await BackgroundLocator.unRegisterLocationUpdate();
    _running = false;
  }

  /// 围栏增删后调用：停掉再重启，即可重新注册最新围栏。
  Future<void> refreshGeofences() async {
    if (!_running) return;
    await stop();
    await start();
  }

  Future<List<Geofence>> _fetchGeofences(BgCredentials creds) async {
    try {
      final res = await http.get(
        Uri.parse(
            '${creds.url}/rest/v1/geofences?select=*&owner_id=eq.${creds.userId}'),
        headers: {
          'apikey': creds.anonKey,
          'Authorization': 'Bearer ${creds.accessToken}',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode != 200) return [];
      final rows = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      final names = <String, dynamic>{};
      final list = rows.map((r) {
        final id = r['id'] as String;
        names[id] = {'name': r['name'], 'emoji': placeEmoji(r['name'])};
        return Geofence(
          id: id,
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
          radius: [Radius((r['radius_m'] as num).toDouble(), LengthUnit.Meter)],
        );
      }).toList();
      await _storage.write(key: _kGeofenceNames, value: jsonEncode(names));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> _readNames() async {
    final s = await _storage.read(key: _kGeofenceNames);
    if (s == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s));
    } catch (_) {
      return {};
    }
  }

  /// 后台隔离里判断 FCM 是否已就绪（isolate 间不共享内存，读安全存储）。
  static Future<bool> _fcmReady() async {
    try {
      final v = await _storage.read(key: 'wuliao.fcm_ready');
      return v == '1';
    } catch (_) {
      return false;
    }
  }
}

// ---- 以下为后台隔离回调（必须是顶层函数，且加 entry-point 注解）----

@pragma('vm:entry-point')
void backgroundInitCallback([Map? _]) {
  NotificationService.init();
}

@pragma('vm:entry-point')
void backgroundDisposeCallback() {}

@pragma('vm:entry-point')
void backgroundLocationCallback(LocationDto dto) async {
  await NotificationService.init();
  final creds = await loadBgCredentials();
  if (creds == null || creds.coupleId == null) return;
  try {
    await http.post(
      Uri.parse('${creds.url}/rest/v1/live_locations'),
      headers: {
        'apikey': creds.anonKey,
        'Authorization': 'Bearer ${creds.accessToken}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode({
        'user_id': creds.userId,
        'couple_id': creds.coupleId,
        'lat': dto.latitude,
        'lng': dto.longitude,
        'accuracy': dto.accuracy,
        'sharing': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  } catch (_) {}

    // 同时写入历史轨迹（爱情足迹地图），与实时位置分开存储
    try {
      await http.post(
        Uri.parse('${creds.url}/rest/v1/location_history'),
        headers: {
          'apikey': creds.anonKey,
          'Authorization': 'Bearer ${creds.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': creds.userId,
          'couple_id': creds.coupleId,
          'lat': dto.latitude,
          'lng': dto.longitude,
          'accuracy': dto.accuracy,
        }),
      );
    } catch (_) {}
  }

@pragma('vm:entry-point')
void geofenceCallback(GeofenceEvent event, Geofence geofence) async {
  await NotificationService.init();
  final creds = await loadBgCredentials();
  if (creds == null || creds.coupleId == null) return;

  final names = await BackgroundLocationService._readNames();
  final info = names[geofence.id];
  final name = (info?['name'] as String?) ?? '某个地点';
  final emoji = (info?['emoji'] as String?) ?? '📍';
  final isEnter = event == GeofenceEvent.enter;
  final title = isEnter ? '$emoji 自动报备' : '🚪 自动报备';
  final body = isEnter ? '你到了$name' : '你离开了$name';

  // 若已接入 FCM（伴侣被杀也能收），则跳过本地自我通知，避免与 FCM 重复；
  // 仅未接入 FCM（没配 Firebase）时，用本地通知即时反馈「报备成功」。
  if (!await BackgroundLocationService._fcmReady()) {
    await NotificationService.show(
      id: geofence.id.hashCode,
      title: title,
      body: body,
    );
  }

  // 写入 checkins：FCM 就绪时由数据库 webhook → Edge Function 经系统通道下发推送；
  // 未接入 FCM 时，伴侣端靠 Realtime 监听（App 存活）收到通知。
  try {
    await http.post(
      Uri.parse('${creds.url}/rest/v1/checkins'),
      headers: {
        'apikey': creds.anonKey,
        'Authorization': 'Bearer ${creds.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': creds.userId,
        'couple_id': creds.coupleId,
        'geofence_id': geofence.id,
        'event_type': isEnter ? 'enter' : 'exit',
        'place_name': name,
        'latitude': geofence.latitude,
        'longitude': geofence.longitude,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  } catch (_) {}
}

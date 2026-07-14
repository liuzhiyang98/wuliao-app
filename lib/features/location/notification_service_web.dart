/// Web 平台的本地通知占位实现。
///
/// 浏览器不支持系统级本地通知（且 Web 端也不依赖它做自动报备），
/// 这里保留与原生实现一致的接口，方法体为空操作。
class NotificationService {
  static const String channelId = 'wuliao_auto';
  static const String channelName = '自动报备';
  static const String channelDesc = '到家 / 出门自动报备提醒';

  static Future<void> init() async {}

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}
}

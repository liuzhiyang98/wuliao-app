// 条件导出：原生平台用 flutter_local_notifications 实现，Web 平台用占位实现。
export 'notification_service_native.dart' if (dart.library.html) 'notification_service_web.dart';

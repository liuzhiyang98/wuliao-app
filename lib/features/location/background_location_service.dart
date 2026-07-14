// 条件导出：原生平台用 background_locator_2 实现后台定位与地理围栏，
// Web 平台用占位实现（浏览器安全限制不允许后台持续定位）。
// 实时位置仍由 location_service（geolocator web）在前台提供。
export 'background_location_service_native.dart'
    if (dart.library.html) 'background_location_service_web.dart';

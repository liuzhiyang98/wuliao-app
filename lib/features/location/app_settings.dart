import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 本机开关（每台设备各自决定，符合「信任优先」的隐私设计）。
const _storage = FlutterSecureStorage();
const _kBg = 'wuliao.bg_enabled';
const _kAuto = 'wuliao.auto_enabled';

Future<bool> getBgEnabled() async => (await _storage.read(key: _kBg)) == '1';
Future<void> setBgEnabled(bool v) async =>
    _storage.write(key: _kBg, value: v ? '1' : '0');

Future<bool> getAutoEnabled() async =>
    (await _storage.read(key: _kAuto)) == '1';
Future<void> setAutoEnabled(bool v) async =>
    _storage.write(key: _kAuto, value: v ? '1' : '0');

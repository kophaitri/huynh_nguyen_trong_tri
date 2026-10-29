import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_failure.dart';

class DeviceIdentityService {
  static const _key = 'triwork.attendance.installation-id';
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static Future<String>? _pending;
  Future<String> getId() =>
      _pending ??= _load().whenComplete(() => _pending = null);
  static Future<String> _load() async {
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null && existing.isNotEmpty) return existing;
      final random = Random.secure();
      final id = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      await _storage.write(key: _key, value: id);
      return id;
    } catch (_) {
      throw const ApiFailure(
        'Không thể lưu mã thiết bị an toàn. Không gửi chấm công.',
      );
    }
  }
}

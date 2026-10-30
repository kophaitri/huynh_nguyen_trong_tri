import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../core/validation/profile_validators.dart';
import '../models/local_profile_model.dart';

abstract interface class LocalProfileStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLocalProfileStore implements LocalProfileStore {
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class LocalProfileException implements Exception {
  const LocalProfileException(this.message);
  final String message;
}

/// Isolated from AuthService/JWT. Used exclusively by presentation widgets.
class LocalProfileService extends ChangeNotifier {
  LocalProfileService({
    LocalProfileStore? store,
    Future<Directory> Function()? directory,
  }) : _store = store ?? SecureLocalProfileStore(),
       _directory = directory ?? getApplicationSupportDirectory;
  final LocalProfileStore _store;
  final Future<Directory> Function() _directory;
  String? _userId;
  LocalProfile? _value;
  String? _avatarPath;
  String? _serverDisplayName;
  int _generation = 0;
  bool _disposed = false;
  bool _writing = false;
  Future<void> _loading = Future.value();
  bool loaded = true;
  Future<void> get ready => _loading;
  String? error;
  static String _account(String id) =>
      base64Url.encode(utf8.encode(id)).replaceAll('=', '');
  static String _key(String id) => 'triwork.local-profile.v1.${_account(id)}';
  static bool _managedName(String name) =>
      RegExp(r'^avatar_[0-9]+\.img$').hasMatch(name);
  LocalProfile? forUser(String id) => id == _userId ? _value : null;
  String? avatarFor(String id) => id == _userId ? _avatarPath : null;
  String displayName(String id, String serverName) =>
      forUser(id)?.fullName ??
      (id == _userId ? _serverDisplayName : null) ??
      serverName;
  bool readyFor(String id) => id == _userId && loaded && error == null;
  bool belongsTo(String id) => id == _userId;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<Directory> _accountDirectory(String id) async => Directory(
    '${(await _directory()).path}${Platform.pathSeparator}triwork_profiles${Platform.pathSeparator}${_account(id)}',
  );
  Future<File?> _avatarFile(String id, String? name) async {
    if (name == null || !_managedName(name)) return null;
    return File(
      '${(await _accountDirectory(id)).path}${Platform.pathSeparator}$name',
    );
  }

  Future<void> bindUser(String? id) {
    if (_userId == id) return _loading;
    _userId = id;
    final generation = ++_generation;
    _value = null;
    _avatarPath = null;
    _serverDisplayName = null;
    error = null;
    loaded = id == null;
    _changed();
    if (id == null) return _loading = Future.value();
    return _loading = _load(id, generation);
  }

  Future<void> reloadFor(String id) {
    if (_userId != id || _writing || _disposed) return Future.value();
    loaded = false;
    error = null;
    final generation = ++_generation;
    _changed();
    return _loading = _load(id, generation);
  }

  Future<void> _load(String id, int generation) async {
    try {
      final raw = await _store
          .read(_key(id))
          .timeout(const Duration(seconds: 5));
      final value = raw == null
          ? null
          : LocalProfile.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
      String? avatar;
      try {
        final file = await _avatarFile(
          id,
          value?.avatarFileName,
        ).timeout(const Duration(seconds: 3));
        if (file != null &&
            await file.exists().timeout(const Duration(seconds: 2))) {
          avatar = file.path;
        }
      } catch (_) {
        /* An unavailable avatar must not block the editable text profile. */
      }
      if (_disposed || generation != _generation) return;
      _value = value;
      _avatarPath = avatar;
    } catch (_) {
      if (generation == _generation) {
        error = 'Chưa đọc được thông tin trên thiết bị. Hãy thử mở lại hồ sơ.';
      }
    } finally {
      if (generation == _generation) {
        loaded = true;
        _changed();
      }
    }
  }

  void _requireAccount(String id, {bool allowReadError = false}) {
    if (_disposed || _userId != id || !loaded) {
      throw const LocalProfileException(
        'Tài khoản đã thay đổi. Vui lòng mở lại hồ sơ.',
      );
    }
    if (!allowReadError && error != null) {
      throw const LocalProfileException(
        'Chưa đọc được thông tin đã lưu. Bấm Thử đọc lại trước khi lưu để giữ dữ liệu cũ.',
      );
    }
  }

  Future<void> save({
    required String userId,
    required String fullName,
    required String phone,
    required String address,
    String? selectedImagePath,
  }) async {
    _requireAccount(userId);
    if (_writing) {
      throw const LocalProfileException('Đang lưu thông tin. Vui lòng chờ.');
    }
    final invalid =
        ProfileValidators.fullName(fullName) ??
        ProfileValidators.phone(phone) ??
        ProfileValidators.address(address);
    if (invalid != null) throw LocalProfileException(invalid);
    _writing = true;
    final generation = _generation;
    final previous = _value;
    File? created;
    var committed = false;
    try {
      String? avatarName = previous?.avatarFileName;
      if (selectedImagePath != null) {
        final source = File(selectedImagePath);
        final size = await source.length();
        if (size <= 0 || size > 8 * 1024 * 1024) {
          throw const LocalProfileException(
            'Ảnh cần nhỏ hơn 8 MB và không được rỗng.',
          );
        }
        final directory = await _accountDirectory(userId);
        await directory.create(recursive: true);
        avatarName = 'avatar_${DateTime.now().microsecondsSinceEpoch}.img';
        created = await source.copy(
          '${directory.path}${Platform.pathSeparator}$avatarName',
        );
      }
      _requireAccount(userId);
      if (generation != _generation) {
        throw const LocalProfileException(
          'Phiên hồ sơ đã thay đổi. Hãy mở lại.',
        );
      }
      final next = LocalProfile(
        fullName: fullName.trim(),
        phone: phone.trim(),
        address: address.trim(),
        avatarFileName: avatarName,
      );
      final file = await _avatarFile(userId, avatarName);
      _requireAccount(userId);
      await _store.write(_key(userId), jsonEncode(next.toJson()));
      committed = true;
      if (!_disposed && generation == _generation) {
        _value = next;
        _avatarPath = file?.path;
        error = null;
        _changed();
      }
      if (previous?.avatarFileName != avatarName) {
        await _deleteAvatar(userId, previous?.avatarFileName);
      }
    } on LocalProfileException {
      rethrow;
    } catch (_) {
      throw const LocalProfileException(
        'Chưa lưu được thông tin trên thiết bị. Vui lòng thử lại.',
      );
    } finally {
      if (!committed && created != null) {
        try {
          await created.delete();
        } catch (_) {}
      }
      _writing = false;
    }
  }

  /// Call only after a fresh /me succeeds; removes this account's overrides only.
  Future<void> restore(String userId, {required String serverName}) async {
    _requireAccount(userId, allowReadError: true);
    if (_writing) {
      throw const LocalProfileException('Đang lưu thông tin. Vui lòng chờ.');
    }
    _writing = true;
    final generation = _generation;
    final previous = _value;
    try {
      await _store.delete(_key(userId));
      if (!_disposed && generation == _generation) {
        _value = null;
        _avatarPath = null;
        _serverDisplayName = serverName;
        error = null;
        _changed();
      }
      await _deleteAvatar(userId, previous?.avatarFileName);
    } catch (_) {
      throw const LocalProfileException(
        'Chưa khôi phục được thông tin trên thiết bị. Vui lòng thử lại.',
      );
    } finally {
      _writing = false;
    }
  }

  Future<void> _deleteAvatar(String id, String? name) async {
    // Only files with our generated names inside this account's app directory.
    try {
      final file = await _avatarFile(id, name);
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      /* Metadata is already committed; orphan cleanup is best effort. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class LocalProfileScope extends InheritedNotifier<LocalProfileService> {
  const LocalProfileScope({
    super.key,
    required LocalProfileService service,
    required super.child,
  }) : super(notifier: service);
  static LocalProfileService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocalProfileScope>()?.notifier;
}

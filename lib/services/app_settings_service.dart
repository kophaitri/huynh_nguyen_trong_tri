import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

abstract interface class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesSettingsStore implements SettingsStore {
  final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _preferences.getString(key);
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

class AppSettingsService extends ChangeNotifier {
  AppSettingsService({SettingsStore? store})
    : _store = store ?? PreferencesSettingsStore();
  final SettingsStore _store;
  AppSettings _value = const AppSettings();
  AppSettings get value => _value;
  String? _userId;
  String? get userId => _userId;
  bool loaded = true;
  bool saving = false;
  bool get canEdit => _userId != null && loaded;
  ThemeMode get effectiveThemeMode =>
      _userId == null ? ThemeMode.light : _value.themeMode;
  bool readyFor(String id) => _userId == id && loaded;
  String? error;
  bool _disposed = false;
  int _generation = 0;
  int _revision = 0;
  Future<void> _loading = Future.value();
  final Map<String, Future<void>> _writes = {};
  static String keyFor(String id) =>
      'triwork.settings.user.${Uri.encodeComponent(id)}';
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> bindUser(String? id) {
    if (_disposed || _userId == id) return _loading;
    _userId = id;
    final generation = ++_generation;
    _revision++;
    _value = const AppSettings();
    loaded = id == null;
    saving = false;
    error = null;
    _changed();
    if (id == null) return _loading = Future.value();
    return _loading = _load(id, generation);
  }

  Future<void> _load(String id, int generation) async {
    try {
      // Wait for this account's outstanding saves, not another account's writes.
      final raw = await (() async {
        await (_writes[id] ?? Future<void>.value());
        return _store.read(keyFor(id));
      })().timeout(const Duration(seconds: 4));
      final value = raw == null
          ? const AppSettings()
          : AppSettings.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
      if (_disposed || generation != _generation) return;
      _value = value;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Không đọc được cài đặt tài khoản. Đang dùng giao diện mặc định.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loaded = true;
        _changed();
      }
    }
  }

  Future<void> update(AppSettings settings) async {
    final id = _userId;
    if (_disposed || id == null || !loaded) return;
    final generation = _generation;
    final revision = ++_revision;
    _value = settings;
    error = null;
    saving = true;
    _changed();
    // Capture the account/key before any await. Logout never deletes settings.
    final operation = (_writes[id] ?? Future<void>.value()).then(
      (_) => _store.write(keyFor(id), jsonEncode(settings.toJson())),
    );
    final tail = operation.catchError((Object _) {});
    _writes[id] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_writes[id], tail)) _writes.remove(id);
      }),
    );
    try {
      await operation;
    } catch (_) {
      if (generation == _generation && revision == _revision) {
        error = 'Đã áp dụng nhưng chưa lưu được. Hãy thử chọn lại.';
      }
    } finally {
      if (!_disposed && generation == _generation && revision == _revision) {
        saving = false;
        _changed();
      }
    }
  }

  Future<void> reset() => update(const AppSettings());
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsService> {
  const AppSettingsScope({
    super.key,
    required AppSettingsService service,
    required super.child,
  }) : super(notifier: service);
  static AppSettingsService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;
  static AppSettingsService of(BuildContext context) => maybeOf(context)!;
}

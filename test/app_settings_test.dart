import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/app/app_theme.dart';
import 'package:huynh_nguyen_trong_tri/models/app_settings_model.dart';
import 'package:huynh_nguyen_trong_tri/services/app_settings_service.dart';
import 'package:huynh_nguyen_trong_tri/screens/settings/settings_screen.dart';
import 'package:huynh_nguyen_trong_tri/app/app.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/screens/auth/login_screen.dart';
import 'package:huynh_nguyen_trong_tri/screens/employee/employee_dashboard.dart';
import 'package:huynh_nguyen_trong_tri/services/local_profile_service.dart';

import 'support/auth_fakes.dart';

class _MemoryStore implements SettingsStore {
  final data = <String, String>{};
  bool fail = false;
  Future<String?> Function(String)? readOverride;
  Future<void> Function(String, String)? writeOverride;
  @override
  Future<String?> read(String key) async =>
      readOverride != null ? readOverride!(key) : data[key];
  @override
  Future<void> write(String key, String value) async {
    if (writeOverride != null) return writeOverride!(key, value);
    await Future<void>.value();
    if (fail) throw StateError('Unavailable storage');
    data[key] = value;
  }
}

class _ProfileStore implements LocalProfileStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  testWidgets(
    'A edits profile/theme; logout is light navy; B isolated; A restores appearance/profile',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      var account = 'A';
      final h = AuthHarness((r) {
        if (r.path == ApiConfig.me) {
          return jsonResponse({...userJson(), 'id': account});
        }
        if (r.path == ApiConfig.myAttendance) return jsonResponse([]);
        throw StateError('Unexpected API');
      }, token: testToken);
      final settings = AppSettingsService(store: _MemoryStore());
      final profiles = LocalProfileService(store: _ProfileStore());
      await tester.pumpWidget(
        TriWorkApp(
          authService: h.auth,
          settingsService: settings,
          localProfileService: profiles,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeDashboard), findsOneWidget);
      await profiles.save(
        userId: 'A',
        fullName: 'Personal A',
        phone: '',
        address: '',
      );
      await settings.update(
        const AppSettings(
          accent: AppAccent.green,
          textSize: AppTextSize.extraLarge,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal A'), findsOneWidget);
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      final login = tester.element(find.byType(LoginScreen));
      expect(Theme.of(login).brightness, Brightness.light);
      expect(Theme.of(login).colorScheme.primary, AppAccent.navy.color);
      expect(MediaQuery.textScalerOf(login).scale(10), 10);
      account = 'B';
      h.storage.value = testToken;
      await tester.runAsync(h.auth.restoreSession);
      await tester.pumpAndSettle();
      expect(settings.value.toJson(), const AppSettings().toJson());
      expect(profiles.forUser('B'), isNull);
      expect(find.text('Personal A'), findsNothing);
      await h.auth.logout();
      await tester.pumpAndSettle();
      account = 'A';
      h.storage.value = testToken;
      await tester.runAsync(h.auth.restoreSession);
      await tester.pumpAndSettle();
      expect(settings.value.accent, AppAccent.green);
      expect(settings.value.textSize, AppTextSize.extraLarge);
      expect(settings.value.themeMode, ThemeMode.dark);
      expect(find.text('Personal A'), findsOneWidget);
      expect(h.auth.user!.roleName, 'Employee');
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      profiles.dispose();
      h.auth.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  test('A/B settings isolated; logout is navy/light; reset only affects current account', () async {
    final store = _MemoryStore();
    store.data['triwork.appearance.v1'] = jsonEncode(
      const AppSettings(accent: AppAccent.purple).toJson(),
    );
    final service = AppSettingsService(store: store);
    await service.bindUser('A');
    expect(service.value.accent, AppAccent.navy);
    await service.update(
      const AppSettings(
        accent: AppAccent.green,
        textSize: AppTextSize.extraLarge,
        themeMode: ThemeMode.dark,
      ),
    );
    await service.bindUser(null);
    expect(service.value.toJson(), const AppSettings().toJson());
    expect(service.effectiveThemeMode, ThemeMode.light);
    await service.reset(); // Signed-out reset must not modify any account.
    await service.bindUser('B');
    expect(service.value.accent, AppAccent.navy);
    await service.update(const AppSettings(accent: AppAccent.blue));
    await service.bindUser(null);
    await service.bindUser('A');
    expect(service.value.accent, AppAccent.green);
    expect(service.value.textSize, AppTextSize.extraLarge);
    await service.reset();
    await service.bindUser('B');
    expect(service.value.accent, AppAccent.blue);
    expect(store.data.containsKey('triwork.appearance.v1'), isTrue);
    expect(
      store.data.keys.where((k) => k.startsWith('triwork.settings.user.')),
      hasLength(2),
    );
    service.dispose();
  });

  test('Late account read cannot overwrite the active account or signed-out appearance', () async {
    final pending = Completer<String?>();
    final store = _MemoryStore();
    store.readOverride = (key) async =>
        key == AppSettingsService.keyFor('A') ? pending.future : null;
    final service = AppSettingsService(store: store);
    final first = service.bindUser('A');
    await service.bindUser('B');
    await service.bindUser(null);
    pending.complete(
      jsonEncode(
        const AppSettings(
          accent: AppAccent.purple,
          themeMode: ThemeMode.dark,
        ).toJson(),
      ),
    );
    await first;
    expect(service.value.accent, AppAccent.navy);
    expect(service.effectiveThemeMode, ThemeMode.light);
    expect(service.userId, isNull);
    service.dispose();
  });

  test('Save started for A writes only A after logout/login B', () async {
    final store = _MemoryStore();
    final pending = Completer<void>();
    store.writeOverride = (key, value) async {
      await pending.future;
      store.data[key] = value;
    };
    final service = AppSettingsService(store: store);
    await service.bindUser('A');
    final save = service.update(const AppSettings(accent: AppAccent.green));
    await service.bindUser(null);
    await service.bindUser('B');
    pending.complete();
    await save;
    expect(store.data.keys, [AppSettingsService.keyFor('A')]);
    expect(service.value.accent, AppAccent.navy);
    expect(service.saving, isFalse);
    await service.bindUser('A');
    expect(service.value.accent, AppAccent.green);
    service.dispose();
  });
  test('Latest appearance persists across service recreation; reset persists defaults', () async {
    final store = _MemoryStore();
    final service = AppSettingsService(store: store);
    await service.bindUser('A');
    final first = service.update(const AppSettings(accent: AppAccent.green));
    final last = service.update(
      const AppSettings(
        accent: AppAccent.purple,
        textSize: AppTextSize.extraLarge,
        themeMode: ThemeMode.dark,
      ),
    );
    await Future.wait([first, last]);
    final restored = AppSettingsService(store: store);
    await restored.bindUser('A');
    expect(restored.value.accent, AppAccent.purple);
    expect(restored.value.textSize, AppTextSize.extraLarge);
    expect(restored.value.themeMode, ThemeMode.dark);
    await restored.reset();
    final reset = AppSettingsService(store: store);
    await reset.bindUser('A');
    expect(reset.value.toJson(), const AppSettings().toJson());
    service.dispose();
    restored.dispose();
    reset.dispose();
  });

  test('Corrupt preferences and write failure show errors without losing selected appearance', () async {
    final store = _MemoryStore()
      ..data[AppSettingsService.keyFor('A')] = 'invalid json';
    final service = AppSettingsService(store: store);
    await service.bindUser('A');
    expect(service.error, isNotNull);
    expect(service.value.accent, AppAccent.navy);
    store.fail = true;
    await service.update(const AppSettings(accent: AppAccent.blue));
    expect(service.value.accent, AppAccent.blue);
    expect(service.error, isNotNull);
    expect(service.saving, isFalse);
    service.dispose();
  });

  testWidgets(
    'Settings adapt to 320px, largest font and all theme colors/modes',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = AppSettingsService(store: _MemoryStore());
      await service.bindUser('A');
      await tester.pumpWidget(
        AppSettingsScope(
          service: service,
          child: AnimatedBuilder(
            animation: service,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.create(service.value.accent, Brightness.light),
              darkTheme: AppTheme.create(service.value.accent, Brightness.dark),
              themeMode: service.value.themeMode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(service.value.textSize.scale),
                ),
                child: child!,
              ),
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      for (final accent in AppAccent.values) {
        for (final mode in ThemeMode.values) {
          await service.update(
            AppSettings(
              accent: accent,
              themeMode: mode,
              textSize: AppTextSize.extraLarge,
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(SettingsScreen));
          expect(MediaQuery.textScalerOf(context).scale(10), 13);
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            mode,
          );
          if (mode == ThemeMode.dark) {
            expect(Theme.of(context).brightness, Brightness.dark);
          }
          expect(tester.takeException(), isNull);
        }
      }
      await tester.scrollUntilVisible(
        find.text('Khôi phục cài đặt mặc định'),
        250,
      );
      await tester.tap(find.text('Khôi phục cài đặt mặc định'));
      await tester.pumpAndSettle();
      expect(service.value.toJson(), const AppSettings().toJson());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/app/app_theme.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/core/validation/profile_validators.dart';
import 'package:huynh_nguyen_trong_tri/models/app_settings_model.dart';
import 'package:huynh_nguyen_trong_tri/services/local_profile_service.dart';
import 'package:huynh_nguyen_trong_tri/screens/profile/profile_screen.dart';
import 'package:huynh_nguyen_trong_tri/screens/profile/edit_profile_screen.dart';

import 'support/auth_fakes.dart';

class _Store implements LocalProfileStore {
  final values = <String, String>{};
  bool fail = false;
  bool readFail = false;
  Completer<String?>? pending;
  @override
  Future<String?> read(String key) async {
    if (readFail) throw StateError('Storage read unavailable');
    final first = pending;
    if (first != null) {
      pending = null;
      return first.future;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (fail) throw StateError('Storage unavailable');
    values.remove(key);
  }
}

void main() {
  for (final role in ['Admin', 'Manager', 'Employee']) {
    testWidgets(
      '$role can open local editor with verified session while fresh me is pending or fails',
      (tester) async {
        var refreshing = false;
        final pending = Completer<ResponseBody>();
        final h = AuthHarness(
          (request) =>
              refreshing ? pending.future : jsonResponse(userJson(role)),
          token: testToken,
        );
        await tester.runAsync(h.auth.restoreSession);
        refreshing = true;
        h.client.clearCache();
        final profiles = LocalProfileService(
          store: _Store(),
        ); // Deliberately unbound, as after hot reload.
        await tester.pumpWidget(
          LocalProfileScope(
            service: profiles,
            child: MaterialApp(home: ProfileScreen(auth: h.auth)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final edit = find.widgetWithText(OutlinedButton, 'Chỉnh sửa thông tin');
        expect(tester.widget<OutlinedButton>(edit).onPressed, isNotNull);
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('profile-name')))
              .controller!
              .text,
          'Test User',
        );
        pending.complete(
          jsonResponse({'message': 'Temporary refresh error'}, status: 500),
        );
        await tester.pumpAndSettle();
        expect(h.auth.user!.roleName, role);
        expect(h.storage.value, testToken);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        profiles.dispose();
        h.auth.dispose();
      },
    );
  }

  testWidgets(
    'Storage read failure does not disable opening editor; explicit retry repairs loading',
    (tester) async {
      final h = AuthHarness((_) => jsonResponse(userJson()), token: testToken);
      await tester.runAsync(h.auth.restoreSession);
      final store = _Store()..readFail = true;
      final profiles = LocalProfileService(store: store);
      await profiles.bindUser(h.auth.user!.id);
      await tester.pumpWidget(
        LocalProfileScope(
          service: profiles,
          child: MaterialApp(home: ProfileScreen(auth: h.auth)),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.widgetWithText(OutlinedButton, 'Chỉnh sửa thông tin');
      expect(tester.widget<OutlinedButton>(edit).onPressed, isNotNull);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      store.readFail = false;
      await tester.tap(find.text('Thử đọc lại'));
      await tester.pumpAndSettle();
      expect(profiles.readyFor(h.auth.user!.id), isTrue);
      expect(h.storage.value, testToken);
      await tester.pumpWidget(const SizedBox.shrink());
      profiles.dispose();
      h.auth.dispose();
    },
  );
  test('Avatar copied to app directory, survives temp removal/restart, accounts isolated', () async {
    final root = await Directory('.dart_tool')
        .createTemp('local_profile_test_');
    addTearDown(() async {
      expect(
        root.absolute.path.startsWith(Directory('.dart_tool').absolute.path),
        isTrue,
      );
      await root.delete(recursive: true);
    });
    final source = File('${root.path}/picked.png');
    await source.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==',
      ),
    );
    final store = _Store();
    final service = LocalProfileService(
      store: store,
      directory: () async => root,
    );
    await service.bindUser('account-a');
    await service.save(
      userId: 'account-a',
      fullName: 'Local Name',
      phone: '+84 912 345 678',
      address: 'Local address',
      selectedImagePath: source.path,
    );
    final avatar = service.avatarFor('account-a')!;
    expect(avatar, isNot(source.path));
    expect(avatar, contains('triwork_profiles'));
    await source.delete();
    service.dispose();
    final restored = LocalProfileService(
      store: store,
      directory: () async => root,
    );
    await restored.bindUser('account-a');
    expect(restored.forUser('account-a')!.phone, '+84 912 345 678');
    expect(await File(restored.avatarFor('account-a')!).exists(), isTrue);
    await restored.bindUser('account-b');
    expect(restored.forUser('account-b'), isNull);
    expect(restored.avatarFor('account-b'), isNull);
    expect(restored.forUser('account-a'), isNull);
    await restored.bindUser('account-a');
    expect(restored.displayName('account-a', 'Server'), 'Local Name');
    expect(
      (jsonDecode(store.values.values.single) as Map).keys,
      unorderedEquals(['fullName', 'phone', 'address', 'avatarFileName']),
    );
    await restored.restore('account-a', serverName: 'Server');
    expect(restored.displayName('account-a', 'Old server'), 'Server');
    expect(await File(avatar).exists(), isFalse);
    expect(store.values, isEmpty);
    restored.dispose();
  });

  test(
    'Failed write/reset preserve previous profile and never delete token keys',
    () async {
      final store = _Store()
        ..values['triwork.auth.jwt'] = 'fake-token-test-only';
      final service = LocalProfileService(store: store);
      await service.bindUser('a');
      await service.save(
        userId: 'a',
        fullName: 'Original Name',
        phone: '',
        address: '',
      );
      store.fail = true;
      await expectLater(
        service.save(
          userId: 'a',
          fullName: 'Other Name',
          phone: '',
          address: '',
        ),
        throwsA(isA<LocalProfileException>()),
      );
      await expectLater(
        service.restore('a', serverName: 'Server'),
        throwsA(isA<LocalProfileException>()),
      );
      expect(service.forUser('a')!.fullName, 'Original Name');
      store.fail = false;
      await service.restore('a', serverName: 'Server');
      expect(store.values['triwork.auth.jwt'], 'fake-token-test-only');
      service.dispose();
    },
  );

  test('Stale account read cannot populate another account', () async {
    final pending = Completer<String?>();
    final store = _Store()..pending = pending;
    final service = LocalProfileService(store: store);
    final first = service.bindUser('a');
    await service.bindUser('b');
    pending.complete(
      jsonEncode({
        'fullName': 'Account A',
        'phone': '',
        'address': '',
        'avatarFileName': null,
      }),
    );
    await first;
    expect(service.forUser('b'), isNull);
    expect(service.forUser('a'), isNull);
    expect(service.displayName('b', 'Server B'), 'Server B');
    service.dispose();
  });

  test('Profile validation accepts names/optional fields and rejects invalid phone/lengths', () {
    expect(ProfileValidators.fullName('Huỳnh Nguyễn Trọng Trí'), isNull);
    expect(ProfileValidators.fullName(' '), isNotNull);
    expect(ProfileValidators.fullName('a' * 101), isNotNull);
    expect(ProfileValidators.phone(''), isNull);
    expect(ProfileValidators.phone('+84 912 345 678'), isNull);
    expect(ProfileValidators.phone('123'), isNotNull);
    expect(ProfileValidators.phone('12345678abc'), isNotNull);
    expect(ProfileValidators.address('a' * 301), isNotNull);
  });

  testWidgets(
    'Edit saves locally, Cancel discards draft, restore uses GET only and preserves JWT/role',
    (tester) async {
      final h = AuthHarness((request) {
        expect(request.method, 'GET');
        expect(request.path, ApiConfig.me);
        return jsonResponse(userJson());
      }, token: testToken);
      await tester.runAsync(h.auth.restoreSession);
      final profiles = LocalProfileService(store: _Store());
      await profiles.bindUser(h.auth.user!.id);
      await tester.pumpWidget(
        LocalProfileScope(
          service: profiles,
          child: MaterialApp(
            theme: AppTheme.create(AppAccent.navy, Brightness.light),
            home: ProfileScreen(auth: h.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openEditor() async {
        await tester.ensureVisible(find.text('Chỉnh sửa thông tin'));
        await tester.tap(find.text('Chỉnh sửa thông tin'));
        await tester.pumpAndSettle();
      }

      Future<void> tapEditor(String label) async {
        await tester.scrollUntilVisible(
          find.text(label),
          220,
          scrollable: find
              .descendant(
                of: find.byType(EditProfileScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await openEditor();
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Personal Name',
      );
      await tester.enterText(
        find.byKey(const Key('profile-phone')),
        '0912345678',
      );
      await tester.enterText(
        find.byKey(const Key('profile-address')),
        'My address',
      );
      await tapEditor('Lưu thay đổi');
      expect(find.text('Personal Name'), findsOneWidget);
      expect(find.text('Đã lưu thông tin trên thiết bị'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(h.auth.user!.fullName, 'Test User');
      expect(h.storage.value, testToken);
      expect(h.auth.user!.roleName, 'Employee');
      await openEditor();
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Unsaved draft',
      );
      await tapEditor('Hủy');
      expect(profiles.forUser(h.auth.user!.id)!.fullName, 'Personal Name');
      await openEditor();
      await tapEditor('Khôi phục thông tin từ máy chủ');
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();
      expect(profiles.forUser(h.auth.user!.id), isNull);
      expect(find.text('Test User'), findsOneWidget);
      expect(h.storage.value, testToken);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      profiles.dispose();
      h.auth.dispose();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/app/app.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/screens/admin/admin_dashboard.dart';
import 'package:huynh_nguyen_trong_tri/screens/auth/login_screen.dart';
import 'package:huynh_nguyen_trong_tri/screens/auth/otp_screen.dart';
import 'package:huynh_nguyen_trong_tri/screens/auth/register_screen.dart';
import 'package:huynh_nguyen_trong_tri/screens/employee/employee_dashboard.dart';
import 'package:huynh_nguyen_trong_tri/screens/manager/manager_dashboard.dart';

import 'support/auth_fakes.dart';

void main() {
  Future<void> mount(WidgetTester tester, AuthHarness h) async {
    addTearDown(h.auth.dispose);
    await tester.pumpWidget(TriWorkApp(authService: h.auth));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Login requires email and password without HTTP', (tester) async {
    final h = AuthHarness((_) => throw StateError('Unexpected HTTP'));
    await mount(tester, h);
    await tapText(tester, 'Đăng nhập');
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    expect(h.adapter.requests, isEmpty);
  });

  testWidgets('Invalid email does not submit credentials', (tester) async {
    final h = AuthHarness((_) => throw StateError('Unexpected HTTP'));
    await mount(tester, h);
    await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
    await tester.enterText(find.byType(TextFormField).last, 'test-password');
    await tapText(tester, 'Đăng nhập');
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(h.adapter.requests, isEmpty);
  });

  testWidgets('Password visibility preserves entered text', (tester) async {
    final h = AuthHarness((_) => throw StateError('Unexpected HTTP'));
    await mount(tester, h);
    await tester.enterText(find.byType(TextFormField).last, 'test-password');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    expect(find.text('test-password'), findsOneWidget);
  });

  testWidgets(
    'Mock login requires OTP then me before Admin dashboard; logout returns to login',
    (tester) async {
      final h = AuthHarness(
        (request) => switch (request.path) {
          ApiConfig.login => jsonResponse({'requiresOtp': true}),
          ApiConfig.verifyOtp => jsonResponse({'token': testToken}),
          ApiConfig.me => jsonResponse(userJson('Admin')),
          _ => throw StateError('Unexpected HTTP'),
        },
      );
      await mount(tester, h);
      await tester.enterText(find.byType(TextFormField).first, testEmail);
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tapText(tester, 'Đăng nhập');
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(h.auth.user, isNull);
      expect(h.storage.value, isNull);
      expect(find.byType(AdminDashboard), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Gửi lại mã sau 60s'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), '123456');
      await tapText(tester, 'Xác nhận');
      expect(find.byType(AdminDashboard), findsOneWidget);
      expect(find.text('Vai trò: Admin'), findsOneWidget);
      await tapText(tester, 'Đăng xuất');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.storage.value, isNull);
      expect(find.byType(OtpScreen), findsNothing);
    },
  );

  testWidgets('Wrong OTP displays error and stays on OTP', (tester) async {
    final h = AuthHarness(
      (request) => request.path == ApiConfig.login
          ? jsonResponse({'requiresOtp': true})
          : jsonResponse({'message': 'OTP sai hoặc hết hạn'}, status: 401),
    );
    await mount(tester, h);
    await tester.enterText(find.byType(TextFormField).first, testEmail);
    await tester.enterText(find.byType(TextFormField).last, 'test-password');
    await tapText(tester, 'Đăng nhập');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tapText(tester, 'Xác nhận');
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.textContaining('Mã OTP sai'), findsOneWidget);
    expect(h.auth.user, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Small screen with keyboard supports register and email verification',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final h = AuthHarness((request) {
        expect(request.path, ApiConfig.register);
        return jsonResponse({'requiresEmailVerification': true});
      });
      await mount(tester, h);
      await tapText(tester, 'Chưa có tài khoản? Đăng ký');
      expect(find.byType(RegisterScreen), findsOneWidget);
      final fields = find.byType(TextFormField);
      for (final entry in [
        'Test User',
        testEmail,
        'test123',
        'test123',
      ].asMap().entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tapText(tester, 'Đăng ký và nhận mã');
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(find.text('Xác minh email'), findsOneWidget);
      expect(h.auth.user, isNull);
      expect(h.storage.value, isNull);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Xác nhận');
      expect(find.text('Vui lòng nhập đủ 6 chữ số.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final role in ['Employee', 'Manager', 'Admin']) {
    testWidgets('Startup routes $role solely from mock me', (tester) async {
      final h = AuthHarness(
        (_) => jsonResponse(userJson(role)),
        token: testToken,
      );
      await mount(tester, h);
      final dashboard = switch (role) {
        'Admin' => find.byType(AdminDashboard),
        'Manager' => find.byType(ManagerDashboard),
        _ => find.byType(EmployeeDashboard),
      };
      expect(dashboard, findsOneWidget);
      expect(find.text('Vai trò: $role'), findsOneWidget);
    });
  }

  testWidgets('Expired token returns to login and clears storage', (
    tester,
  ) async {
    final h = AuthHarness(
      (_) => jsonResponse({}, status: 401),
      token: testToken,
    );
    await mount(tester, h);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('Phiên đã hết hạn'), findsOneWidget);
    expect(h.storage.value, isNull);
  });

  testWidgets('Unavailable me shows retry with no dashboard', (tester) async {
    final h = AuthHarness(
      (_) => jsonResponse({}, status: 503),
      token: testToken,
    );
    await mount(tester, h);
    expect(find.text('Chưa thể xác minh phiên'), findsOneWidget);
    expect(find.byType(EmployeeDashboard), findsNothing);
    await tapText(tester, 'Xóa phiên và về đăng nhập');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(h.storage.value, isNull);
  });
}

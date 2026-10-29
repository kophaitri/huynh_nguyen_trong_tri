import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/app/app.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/screens/auth/login_screen.dart';
import 'package:huynh_nguyen_trong_tri/screens/employees/employee_screen.dart';
import 'package:huynh_nguyen_trong_tri/widgets/crud_widgets.dart';

import 'support/auth_fakes.dart';
import 'support/crud_fixtures.dart';

void main() {
  Future<AuthHarness> mount(
    WidgetTester tester,
    String role,
    MockResponder responder,
  ) async {
    final h = AuthHarness(
      (r) =>
          r.path == ApiConfig.me ? jsonResponse(userJson(role)) : responder(r),
      token: testToken,
    );
    addTearDown(h.auth.dispose);
    await tester.pumpWidget(TriWorkApp(authService: h.auth));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final role in ['Admin', 'Manager', 'Employee']) {
    testWidgets(
      '$role dashboard exposes only permitted menus and catalog controls',
      (tester) async {
        final h = await mount(
          tester,
          role,
          (_) => jsonResponse(pageJson([departmentJson()])),
        );
        expect(
          find.text('Nhân viên'),
          role == 'Employee' ? findsNothing : findsOneWidget,
        );
        for (final label in [
          'Phòng ban',
          'Ca làm',
          'Địa điểm',
          'Đơn nghỉ phép',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tap(tester, 'Phòng ban');
        expect(
          find.text('Thêm'),
          role == 'Admin' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Sửa'),
          role == 'Admin' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Xóa / hủy'),
          role == 'Admin' ? findsOneWidget : findsNothing,
        );
        expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
      },
    );
  }

  testWidgets(
    'Admin department form validates, creates, edits and confirms delete with mock HTTP',
    (tester) async {
      Map<String, dynamic>? stored;
      final h = await mount(tester, 'Admin', (r) {
        if (r.method == 'GET') {
          return jsonResponse(pageJson([if (stored != null) stored!]));
        }
        if (r.method == 'POST' || r.method == 'PUT') {
          stored = {'id': 11, ...r.data as Map<String, dynamic>};
          return jsonResponse(stored!, status: r.method == 'POST' ? 201 : 200);
        }
        stored = null;
        return ResponseBody.fromString('', 204);
      });
      await tap(tester, 'Phòng ban');
      expect(find.byType(CrudEmptyState), findsOneWidget);
      await tap(tester, 'Thêm');
      expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
      await tap(tester, 'Lưu');
      expect(find.text('Vui lòng nhập thông tin.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Tri Test Department',
      );
      await tester.enterText(find.byType(TextFormField).last, 'Only mock data');
      await tap(tester, 'Lưu');
      expect(find.text('Tri Test Department'), findsOneWidget);
      await tap(tester, 'Sửa');
      await tester.enterText(
        find.byType(TextFormField).first,
        'Tri Updated Department',
      );
      await tap(tester, 'Lưu');
      expect(find.text('Tri Updated Department'), findsOneWidget);
      await tap(tester, 'Xóa / hủy');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(h.adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tap(tester, 'Quay lại');
      expect(h.adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tap(tester, 'Xóa / hủy');
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa / hủy'));
      await tester.pumpAndSettle();
      expect(h.adapter.requests.where((r) => r.method == 'DELETE').length, 1);
      expect(find.byType(CrudEmptyState), findsOneWidget);
    },
  );

  testWidgets('Manager employee list is read-only and uses real detail GET', (
    tester,
  ) async {
    final h = await mount(
      tester,
      'Manager',
      (r) => jsonResponse(
        r.path == ApiConfig.employees
            ? pageJson([employeeJson()])
            : employeeJson(detail: true),
      ),
    );
    await tap(tester, 'Nhân viên');
    expect(find.text('Thêm'), findsNothing);
    expect(find.text('Sửa'), findsNothing);
    expect(find.text('Xóa / hủy'), findsNothing);
    await tap(tester, 'Chi tiết');
    expect(find.text('Vai trò: Manager'), findsOneWidget);
    expect(find.text('Sửa nhân viên'), findsNothing);
    expect(h.adapter.requests.last.path, '/api/employees/other-user');
  });

  testWidgets('Employee pagination and debounced search send page and q', (
    tester,
  ) async {
    final h = await mount(tester, 'Manager', (r) {
      final page = r.queryParameters['page'] as int;
      return jsonResponse(
        pageJson(
          [employeeJson(name: page == 1 ? 'Page One' : 'Page Two')],
          total: 21,
          page: page,
        ),
      );
    });
    await tap(tester, 'Nhân viên');
    await tester.ensureVisible(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Page Two'), findsOneWidget);
    expect(h.adapter.requests.last.queryParameters['page'], 2);
    await tester.enterText(find.byType(TextField), 'Test');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(h.adapter.requests.last.queryParameters, {
      'page': 1,
      'pageSize': 20,
      'q': 'Test',
    });
  });

  testWidgets(
    'Employee edit loads role from detail and never submits email/password',
    (tester) async {
      Map<String, dynamic>? update;
      final h = await mount(tester, 'Admin', (r) {
        if (r.method == 'PUT') {
          update = r.data as Map<String, dynamic>;
          return ResponseBody.fromString('', 204);
        }
        if (r.path == ApiConfig.departments) {
          return jsonResponse(pageJson([departmentJson()]));
        }
        if (r.path == ApiConfig.employees) {
          return jsonResponse(pageJson([employeeJson()]));
        }
        return jsonResponse(employeeJson(detail: true));
      });
      await tap(tester, 'Nhân viên');
      await tap(tester, 'Sửa');
      expect(find.text('Sửa nhân viên'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'Manager',
      );
      expect(
        h.adapter.requests
            .where(
              (r) => r.path == '/api/employees/other-user' && r.method == 'GET',
            )
            .length,
        1,
      );
      await tap(tester, 'Lưu');
      expect(update?['role'], 'Manager');
      expect(update?.containsKey('email'), isFalse);
      expect(update?.containsKey('password'), isFalse);
    },
  );

  testWidgets('Read failure supports retry; CRUD 403 keeps session', (
    tester,
  ) async {
    var failed = true;
    final h = await mount(
      tester,
      'Manager',
      (_) => failed
          ? jsonResponse({}, status: 403)
          : jsonResponse(pageJson([departmentJson()])),
    );
    await tap(tester, 'Phòng ban');
    expect(find.byType(CrudErrorState), findsOneWidget);
    expect(h.auth.user, isNotNull);
    expect(h.storage.value, testToken);
    failed = false;
    await tap(tester, 'Thử lại');
    expect(find.text('Test Department'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('CRUD 401 removes protected route and returns to login', (
    tester,
  ) async {
    final h = await mount(
      tester,
      'Manager',
      (_) => jsonResponse({}, status: 401),
    );
    await tap(tester, 'Nhân viên');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(EmployeeScreen), findsNothing);
    expect(h.storage.value, isNull);
  });

  testWidgets(
    'Small phone and keyboard allow location validation without POST',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final h = await mount(
        tester,
        'Admin',
        (r) => jsonResponse(
          pageJson(r.path == ApiConfig.shifts ? [shiftJson()] : []),
        ),
      );
      await tap(tester, 'Địa điểm');
      await tap(tester, 'Thêm');
      final fields = find.byType(TextFormField);
      for (final entry in {0: 'Test', 2: '91', 3: '181', 4: '0'}.entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.pumpAndSettle();
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tap(tester, 'Lưu');
      expect(find.text('Nhập tọa độ từ -90 đến 90.'), findsOneWidget);
      expect(find.text('Nhập tọa độ từ -180 đến 180.'), findsOneWidget);
      expect(find.text('Nhập số nguyên lớn hơn 0.'), findsOneWidget);
      expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Employee only edits/cancels own Pending leave, no review controls',
    (tester) async {
      await mount(
        tester,
        'Employee',
        (_) => jsonResponse([
          leaveJson(),
          leaveJson(id: 42, status: 'Approved'),
          leaveJson(id: 43, userId: 'other'),
        ]),
      );
      await tap(tester, 'Đơn nghỉ phép');
      expect(find.text('Test User · #43'), findsNothing);
      expect(find.text('Sửa'), findsOneWidget);
      expect(find.text('Xóa / hủy'), findsOneWidget);
      expect(find.text('Duyệt'), findsNothing);
      expect(find.text('Từ chối'), findsNothing);
      expect(find.byTooltip('Trang sau'), findsNothing);
    },
  );

  testWidgets('A slow old search never replaces a newer search result', (
    tester,
  ) async {
    final old = Completer<ResponseBody>();
    await mount(tester, 'Manager', (r) {
      if (r.queryParameters['q'] == 'old') return old.future;
      return jsonResponse(
        pageJson([
          employeeJson(
            name: r.queryParameters['q'] == 'new'
                ? 'Newest Result'
                : 'Initial Result',
          ),
        ]),
      );
    });
    await tap(tester, 'Nhân viên');
    final search = find.byType(TextField);
    await tester.enterText(search, 'old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(search, 'new');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Newest Result'), findsOneWidget);
    old.complete(jsonResponse(pageJson([employeeJson(name: 'Stale Result')])));
    await tester.pumpAndSettle();
    expect(find.text('Newest Result'), findsOneWidget);
    expect(find.text('Stale Result'), findsNothing);
  });

  testWidgets('Manager review requires confirmation and reloads server state', (
    tester,
  ) async {
    var status = 'Pending';
    final h = await mount(tester, 'Manager', (r) {
      if (r.method == 'POST') {
        expect(r.path, '/api/leaves/41/review');
        expect(r.data, {'approve': true});
        status = 'Approved';
        return ResponseBody.fromString('', 204);
      }
      return jsonResponse([leaveJson(userId: 'other', status: status)]);
    });
    await tap(tester, 'Đơn nghỉ phép');
    expect(find.text('Sửa'), findsNothing);
    expect(find.text('Xóa / hủy'), findsNothing);
    await tap(tester, 'Duyệt');
    expect(h.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
    await tester.pumpAndSettle();
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Duyệt'), findsNothing);
    expect(h.adapter.requests.where((r) => r.method == 'POST').length, 1);
  });
}

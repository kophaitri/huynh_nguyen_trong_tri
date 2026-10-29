import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/core/network/api_failure.dart';
import 'package:huynh_nguyen_trong_tri/core/validation/crud_validators.dart';
import 'package:huynh_nguyen_trong_tri/models/department_model.dart';
import 'package:huynh_nguyen_trong_tri/models/employee_model.dart';
import 'package:huynh_nguyen_trong_tri/models/leave_request_model.dart';
import 'package:huynh_nguyen_trong_tri/models/paged_response.dart';
import 'package:huynh_nguyen_trong_tri/models/shift_model.dart';
import 'package:huynh_nguyen_trong_tri/models/work_location_model.dart';
import 'package:huynh_nguyen_trong_tri/services/department_service.dart';
import 'package:huynh_nguyen_trong_tri/services/employee_service.dart';
import 'package:huynh_nguyen_trong_tri/services/leave_service.dart';
import 'package:huynh_nguyen_trong_tri/services/location_service.dart';
import 'package:huynh_nguyen_trong_tri/services/shift_service.dart';

import 'support/auth_fakes.dart';
import 'support/crud_fixtures.dart';

const deptInput = DepartmentInput(
  name: 'Test Department',
  description: 'Test description',
);
const shiftInput = ShiftInput(
  name: 'Test Shift',
  startTime: '08:00:00',
  endTime: '17:00:00',
  lateToleranceMinutes: 10,
);
const locationInput = WorkLocationInput(
  name: 'Test Location',
  address: 'Test address',
  latitude: 10.8,
  longitude: 106.7,
  radiusMeters: 100,
  shiftId: 21,
);
const leaveInput = LeaveInput(
  fromDate: '2026-11-02',
  toDate: '2026-11-03',
  reason: 'Test reason',
);

void main() {
  Future<AuthHarness> setup(String role, MockResponder respond) async {
    final h = AuthHarness((request) {
      expect(request.uri.origin, ApiConfig.baseUrl);
      expect(request.headers['Authorization'], 'Bearer $testToken');
      return request.path == ApiConfig.me
          ? jsonResponse(userJson(role))
          : respond(request);
    }, token: testToken);
    addTearDown(h.auth.dispose);
    await h.auth.restoreSession();
    return h;
  }

  test(
    'Department CRUD uses entity fields, page envelope and handles 204',
    () async {
      final h = await setup('Admin', (r) {
        if (r.method == 'DELETE') return ResponseBody.fromString('', 204);
        if (r.method == 'GET' && r.path == ApiConfig.departments) {
          expect(r.queryParameters, {'page': 2, 'pageSize': 20});
          return jsonResponse(pageJson([departmentJson()], total: 21, page: 2));
        }
        if (r.method != 'GET') expect(r.data, deptInput.toJson());
        return jsonResponse(
          departmentJson(),
          status: r.method == 'POST' ? 201 : 200,
        );
      });
      final service = DepartmentService(h.auth);
      final page = await service.list(page: 2);
      expect(page.page, 2);
      expect(page.total, 21);
      expect(page.hasNext, isFalse);
      expect((await service.get(11)).name, 'Test Department');
      expect((await service.create(deptInput)).id, 11);
      await service.update(11, deptInput);
      await service.delete(11);
      expect(h.adapter.requests.skip(1).map((r) => '${r.method} ${r.path}'), [
        'GET /api/departments',
        'GET /api/departments/11',
        'POST /api/departments',
        'PUT /api/departments/11',
        'DELETE /api/departments/11',
      ]);
    },
  );

  test('Shift CRUD sends HH:mm:ss strings and integer tolerance', () async {
    final h = await setup('Admin', (r) {
      if (r.method == 'DELETE') return ResponseBody.fromString('', 204);
      if (r.method == 'GET' && r.path == ApiConfig.shifts) {
        return jsonResponse(pageJson([shiftJson()]));
      }
      if (r.method != 'GET') {
        expect(r.data, shiftInput.toJson());
        expect((r.data as Map)['lateToleranceMinutes'], isA<int>());
      }
      return jsonResponse(shiftJson(), status: r.method == 'POST' ? 201 : 200);
    });
    final service = ShiftService(h.auth);
    expect((await service.list()).items.single.startTime, '08:00:00');
    expect((await service.get(21)).endTime, '17:00:00');
    await service.create(shiftInput);
    await service.update(21, shiftInput);
    await service.delete(21);
    expect(h.adapter.requests.last.path, '/api/shifts/21');
  });

  test(
    'Location CRUD uses numeric coordinates and integer radius/shiftId',
    () async {
      final h = await setup('Admin', (r) {
        if (r.method == 'DELETE') return ResponseBody.fromString('', 204);
        if (r.method == 'GET' && r.path == ApiConfig.locations) {
          return jsonResponse(pageJson([locationJson()]));
        }
        if (r.method != 'GET') expect(r.data, locationInput.toJson());
        return jsonResponse(
          locationJson(),
          status: r.method == 'POST' ? 201 : 200,
        );
      });
      final service = LocationService(h.auth);
      expect((await service.list()).items.single.shiftId, 21);
      expect((await service.get(31)).radiusMeters, 100);
      await service.create(locationInput);
      await service.update(31, locationInput);
      await service.delete(31);
      expect(h.adapter.requests.last.path, '/api/locations/31');
    },
  );

  test(
    'Employee search/pagination and detail distinguish list fields from role',
    () async {
      final h = await setup('Manager', (r) {
        if (r.path == ApiConfig.employees) {
          expect(r.queryParameters, {
            'page': 2,
            'pageSize': 20,
            'q': 'Test',
            'departmentId': 11,
          });
          return jsonResponse(pageJson([employeeJson()], total: 22, page: 2));
        }
        return jsonResponse(employeeJson(detail: true));
      });
      final service = EmployeeService(h.auth);
      final page = await service.list(
        page: 2,
        query: ' Test ',
        departmentId: 11,
      );
      expect(page.items.single.role, isNull);
      expect(page.items.single.department, 'Test Department');
      expect((await service.get('other-user')).role, 'Manager');
    },
  );

  test(
    'Employee create returns partial DTO; update excludes email/password',
    () async {
      final h = await setup('Admin', (r) {
        if (r.method == 'POST') {
          expect(r.data, {
            'email': 'employee@example.test',
            'password': 'test123',
            'fullName': 'Test Employee',
            'employeeCode': null,
            'departmentId': 11,
            'role': 'Employee',
          });
          return jsonResponse({
            'id': 'new-test-user',
            'fullName': 'Test Employee',
            'email': 'employee@example.test',
          }, status: 201);
        }
        if (r.method == 'PUT') {
          expect(r.data, {
            'fullName': 'Updated',
            'employeeCode': 'TEST-02',
            'departmentId': null,
            'role': 'Manager',
            'isActive': false,
          });
        }
        return ResponseBody.fromString('', 204);
      });
      final service = EmployeeService(h.auth);
      expect(
        await service.create(
          const EmployeeCreateInput(
            email: 'employee@example.test',
            password: 'test123',
            fullName: 'Test Employee',
            departmentId: 11,
            role: 'Employee',
          ),
        ),
        'new-test-user',
      );
      await service.update(
        'new-test-user',
        const EmployeeUpdateInput(
          fullName: 'Updated',
          employeeCode: 'TEST-02',
          role: 'Manager',
          isActive: false,
        ),
      );
      await service.delete('new-test-user');
      expect(h.adapter.requests.last.path, '/api/employees/new-test-user');
    },
  );

  for (final role in ['Manager', 'Employee']) {
    test(
      '$role cannot write catalogs or employees even through services',
      () async {
        final h = await setup(
          role,
          (_) => throw StateError('No CRUD HTTP allowed'),
        );
        final d = DepartmentService(h.auth);
        final s = ShiftService(h.auth);
        final l = LocationService(h.auth);
        final e = EmployeeService(h.auth);
        for (final action in <Future<dynamic> Function()>[
          () => d.create(deptInput),
          () => d.update(11, deptInput),
          () => d.delete(11),
          () => s.create(shiftInput),
          () => s.update(21, shiftInput),
          () => s.delete(21),
          () => l.create(locationInput),
          () => l.update(31, locationInput),
          () => l.delete(31),
          () => e.create(
            const EmployeeCreateInput(
              email: 'test@example.test',
              password: 'test123',
              fullName: 'Test',
              role: 'Employee',
            ),
          ),
          () => e.update(
            'other',
            const EmployeeUpdateInput(fullName: 'Test', isActive: true),
          ),
          () => e.delete('other'),
        ]) {
          await expectLater(
            action,
            throwsA(
              isA<ApiFailure>().having((e) => e.statusCode, 'status', 403),
            ),
          );
        }
        expect(h.adapter.requests.length, 1);
      },
    );
  }

  test(
    'Employee cannot read employees, but may read reference catalogs',
    () async {
      final h = await setup(
        'Employee',
        (_) => jsonResponse(pageJson([departmentJson()])),
      );
      final employees = EmployeeService(h.auth);
      await expectLater(employees.list, throwsA(isA<ApiFailure>()));
      await expectLater(
        () => employees.get('other'),
        throwsA(isA<ApiFailure>()),
      );
      expect((await DepartmentService(h.auth).list()).items.length, 1);
    },
  );

  test(
    'Lookup fetches subsequent pages instead of truncating at first 200',
    () async {
      final h = await setup('Admin', (r) {
        final p = r.queryParameters['page'] as int;
        expect(r.queryParameters['pageSize'], 200);
        return jsonResponse(
          pageJson([departmentJson(id: p)], total: 201, page: p, pageSize: 200),
        );
      });
      final all = await DepartmentService(h.auth).all();
      expect(all.map((d) => d.id), [1, 2]);
      expect(h.adapter.requests.length, 3);
    },
  );

  test(
    'Malformed page metadata and item fields become safe parse errors',
    () async {
      for (final data in [
        {'total': 1, 'page': 0, 'pageSize': 20, 'items': []},
        {'total': '1', 'page': 1, 'pageSize': 20, 'items': []},
        pageJson([
          {'id': 'wrong-type', 'name': 'Test'},
        ]),
        pageJson([
          {'id': 1},
        ]),
      ]) {
        expect(
          () => PagedResponse<DepartmentModel>.fromJson(
            data,
            DepartmentModel.fromJson,
          ),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );

  test(
    'Leaves uses an unpaged array and enum status; Employee only sees own data',
    () async {
      final h = await setup('Employee', (r) {
        expect(r.method, 'GET');
        expect(r.path, ApiConfig.leaves);
        expect(r.queryParameters, {'status': 'Pending'});
        return jsonResponse([
          leaveJson(),
          leaveJson(id: 42, userId: 'another-user'),
        ]);
      });
      final leaves = await LeaveService(h.auth)
          .list(status: LeaveStatus.pending);
      expect(leaves.length, 1);
      expect(leaves.single.userId, 'test-user-id');
    },
  );

  test('Own Pending leave create/update/cancel sends DateOnly JSON and no status/userId', () async {
    final h = await setup('Employee', (r) {
      if (r.method == 'POST' || r.method == 'PUT') {
        expect(r.data, leaveInput.toJson());
      }
      return r.method == 'POST'
          ? jsonResponse({'id': 41}, status: 201)
          : ResponseBody.fromString('', 204);
    });
    final service = LeaveService(h.auth);
    final leave = LeaveRequestModel.fromJson(leaveJson());
    expect(await service.create(leaveInput), 41);
    await service.update(leave, leaveInput);
    await service.delete(leave);
    expect(h.adapter.requests.skip(1).map((r) => '${r.method} ${r.path}'), [
      'POST /api/leaves',
      'PUT /api/leaves/41',
      'DELETE /api/leaves/41',
    ]);
  });

  test(
    'Employee cannot edit/cancel another user or processed leave, or review',
    () async {
      final h = await setup(
        'Employee',
        (_) => throw StateError('No HTTP expected'),
      );
      final service = LeaveService(h.auth);
      for (final leave in [
        LeaveRequestModel.fromJson(leaveJson(userId: 'other')),
        LeaveRequestModel.fromJson(leaveJson(status: 'Approved')),
      ]) {
        await expectLater(
          () => service.update(leave, leaveInput),
          throwsA(isA<ApiFailure>()),
        );
        await expectLater(
          () => service.delete(leave),
          throwsA(isA<ApiFailure>()),
        );
      }
      await expectLater(
        () => service.review(
          LeaveRequestModel.fromJson(leaveJson()),
          approve: true,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.adapter.requests.length, 1);
    },
  );

  for (final role in ['Admin', 'Manager']) {
    test(
      '$role can approve/reject using review endpoint and boolean approve',
      () async {
        final h = await setup(role, (r) {
          expect(r.path, '/api/leaves/41/review');
          expect(r.method, 'POST');
          expect((r.data as Map)['approve'], isA<bool>());
          return ResponseBody.fromString('', 204);
        });
        final service = LeaveService(h.auth);
        final leave = LeaveRequestModel.fromJson(leaveJson(userId: 'other'));
        await service.review(leave, approve: true);
        await service.review(leave, approve: false);
        expect(h.adapter.requests[1].data, {'approve': true});
        expect(h.adapter.requests[2].data, {'approve': false});
      },
    );
  }

  test(
    'Admin deletion matches backend special permission for processed leaves',
    () async {
      final h = await setup('Admin', (_) => ResponseBody.fromString('', 204));
      await LeaveService(h.auth).delete(
        LeaveRequestModel.fromJson(
          leaveJson(userId: 'other', status: 'Approved'),
        ),
      );
      expect(h.adapter.requests.last.method, 'DELETE');
    },
  );

  for (final status in [401, 403, 404, 409, 422, 500]) {
    test(
      'CRUD HTTP $status is handled, only 401 invalidates the session',
      () async {
        final h = await setup('Admin', (_) => jsonResponse({}, status: status));
        await expectLater(
          () => DepartmentService(h.auth).list(),
          throwsA(
            isA<ApiFailure>().having((e) => e.statusCode, 'status', status),
          ),
        );
        expect(h.auth.user == null, status == 401);
        expect(h.storage.value == null, status == 401);
      },
    );
  }

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.receiveTimeout,
  ]) {
    test(
      'CRUD handles $type and never retries mutations automatically',
      () async {
        final h = await setup(
          'Admin',
          (r) => throw DioException(requestOptions: r, type: type),
        );
        await expectLater(
          () => DepartmentService(h.auth).create(deptInput),
          throwsA(isA<ApiFailure>()),
        );
        expect(h.adapter.requests.where((r) => r.method == 'POST').length, 1);
        expect(h.auth.user, isNotNull);
      },
    );
  }

  test(
    'Invalid location, shift and leave inputs do not issue write requests',
    () async {
      final h = await setup(
        'Admin',
        (_) => throw StateError('No writes expected'),
      );
      await expectLater(
        () => LocationService(h.auth).create(
          const WorkLocationInput(
            name: 'Test',
            latitude: 91,
            longitude: 0,
            radiusMeters: 100,
            shiftId: 21,
          ),
        ),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        () => ShiftService(h.auth).create(
          const ShiftInput(
            name: 'Test',
            startTime: '8:00',
            endTime: '17:00:00',
            lateToleranceMinutes: 0,
          ),
        ),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        () => LeaveService(h.auth).create(
          const LeaveInput(
            fromDate: '2026-11-03',
            toDate: '2026-11-02',
            reason: 'Test',
          ),
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.adapter.requests.length, 1);
    },
  );

  test('Validation rejects non-finite coordinates, bad dates and bad time', () {
    for (final value in ['NaN', 'Infinity', '-91', '91', '']) {
      expect(CrudValidators.coordinate(value, latitude: true), isNotNull);
    }
    expect(CrudValidators.coordinate('-180', latitude: false), isNull);
    expect(CrudValidators.coordinate('90', latitude: true), isNull);
    expect(CrudValidators.positiveInt('0'), isNotNull);
    expect(CrudValidators.positiveInt('2147483648'), isNotNull);
    expect(CrudValidators.nonNegativeInt('-1'), isNotNull);
    expect(CrudValidators.date('2026-02-30'), isNotNull);
    expect(CrudValidators.date('2028-02-29'), isNull);
    expect(CrudValidators.date('0000-01-01'), isNotNull);
    expect(CrudValidators.time('24:00:00'), isNotNull);
    expect(CrudValidators.time('23:59:59'), isNull);
  });

  test('A late 401 from an old token cannot clear a newer session', () async {
    final response = Completer<ResponseBody>();
    final h = await setup('Admin', (_) => response.future);
    final pending = DepartmentService(h.auth).list();
    await Future<void>.delayed(Duration.zero);
    h.client.token = 'new-mock-token';
    response.complete(jsonResponse({}, status: 401));
    await expectLater(pending, throwsA(isA<ApiFailure>()));
    expect(h.auth.user, isNotNull);
    expect(h.storage.value, testToken);
  });
}

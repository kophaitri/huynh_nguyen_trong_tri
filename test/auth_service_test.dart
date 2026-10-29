import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/core/network/api_failure.dart';
import 'package:huynh_nguyen_trong_tri/models/otp_challenge.dart';
import 'package:huynh_nguyen_trong_tri/models/user_model.dart';

import 'support/auth_fakes.dart';

const challenge = OtpChallenge(identity: testEmail, purpose: OtpPurpose.login);

void main() {
  AuthHarness harness(
    MockResponder responder, {
    String? token,
    DateTime Function()? now,
  }) {
    final h = AuthHarness(responder, token: token, now: now);
    addTearDown(h.auth.dispose);
    return h;
  }

  test(
    'Login sends verified DTO to public HTTPS and does not create a session',
    () async {
      final h = harness((request) {
        expect(request.uri.origin, ApiConfig.baseUrl);
        expect(request.path, ApiConfig.login);
        expect(request.method, 'POST');
        expect(request.data, {
          'userNameOrEmail': testEmail,
          'password': 'test-password',
        });
        expect(request.headers.containsKey('Authorization'), isFalse);
        return jsonResponse({'requiresOtp': true, 'message': 'OTP requested'});
      });
      final result = await h.auth.login(' $testEmail ', 'test-password');
      expect(result.purpose, OtpPurpose.login);
      expect(h.auth.user, isNull);
      expect(h.storage.writes, 0);
    },
  );

  test(
    'Registration requires email verification and never submits a role',
    () async {
      final h = harness((request) {
        expect(request.path, ApiConfig.register);
        expect(request.data, {
          'email': testEmail,
          'password': 'test123',
          'fullName': 'Test User',
        });
        return jsonResponse({'requiresEmailVerification': true});
      });
      final result = await h.auth.register(' Test User ', testEmail, 'test123');
      expect(result.purpose, OtpPurpose.registration);
      expect(h.storage.writes, 0);
      expect(h.auth.user, isNull);
    },
  );

  test(
    'A successful status without the expected challenge flag fails closed',
    () async {
      final h = harness((_) => jsonResponse({'token': testToken}));
      await expectLater(
        h.auth.login(testEmail, 'test-password'),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.storage.value, isNull);
      expect(h.auth.user, isNull);
    },
  );

  test(
    'OTP success stores token, checks me with Bearer and trusts only me role',
    () async {
      final h = harness((request) {
        if (request.path == ApiConfig.verifyOtp) {
          expect(request.data, {
            'userNameOrEmail': testEmail,
            'code': '123456',
          });
          expect(request.headers.containsKey('Authorization'), isFalse);
          return jsonResponse({
            'token': testToken,
            'role': 'Admin',
            'userId': 'test-user-id',
            'fullName': 'Test User',
            'email': testEmail,
          });
        }
        expect(request.path, ApiConfig.me);
        expect(request.headers['Authorization'], 'Bearer $testToken');
        return jsonResponse(userJson('Employee'));
      });
      await h.auth.verifyOtp(challenge, '123456');
      expect(h.auth.user?.role, UserRole.employee);
      expect(h.storage.value, testToken);
      expect(h.adapter.requests.length, 2);
    },
  );

  test('Wrong or expired OTP never writes token or requests me', () async {
    final h = harness(
      (_) => jsonResponse({'message': 'OTP sai hoặc hết hạn'}, status: 401),
    );
    await expectLater(
      h.auth.verifyOtp(challenge, '123456'),
      throwsA(
        isA<ApiFailure>().having((e) => e.message, 'message', contains('OTP')),
      ),
    );
    expect(h.storage.writes, 0);
    expect(h.adapter.requests.length, 1);
    expect(h.auth.user, isNull);
  });

  test('Incomplete OTP is rejected before HTTP', () async {
    final h = harness((_) => throw StateError('Unexpected request'));
    await expectLater(
      h.auth.verifyOtp(challenge, '123'),
      throwsA(isA<ApiFailure>()),
    );
    expect(h.adapter.requests, isEmpty);
  });

  test('Missing token in OTP response cannot authenticate', () async {
    final h = harness((_) => jsonResponse({'role': 'Admin'}));
    await expectLater(
      h.auth.verifyOtp(challenge, '123456'),
      throwsA(isA<ApiFailure>()),
    );
    expect(h.storage.writes, 0);
    expect(h.auth.user, isNull);
  });

  test(
    'Resend cooldown and pending OTP prevent duplicate code requests',
    () async {
      var now = DateTime.utc(2026, 10, 29);
      final h = harness(
        (request) => jsonResponse(
          request.path == ApiConfig.login
              ? {'requiresOtp': true}
              : {'message': 'OTP requested'},
        ),
        now: () => now,
      );
      await h.auth.login(testEmail, 'test-password');
      await expectLater(
        h.auth.resendOtp(challenge),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        h.auth.login(testEmail.toUpperCase(), 'test-password'),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.adapter.requests.length, 1);
      now = now.add(const Duration(seconds: 60));
      await h.auth.resendOtp(challenge);
      expect(h.adapter.requests.last.path, ApiConfig.resendOtp);
      expect(h.adapter.requests.last.data, {'userNameOrEmail': testEmail});
      expect(h.auth.resendSeconds(testEmail), 60);
    },
  );

  test('429 respects a longer Retry-After from server', () async {
    var now = DateTime.utc(2026, 10, 29);
    final h = harness(
      (_) => jsonResponse(
        {},
        status: 429,
        headers: {
          'retry-after': ['120'],
        },
      ),
      now: () => now,
    );
    await expectLater(h.auth.resendOtp(challenge), throwsA(isA<ApiFailure>()));
    now = now.add(const Duration(seconds: 61));
    expect(h.auth.resendSeconds(testEmail), 59);
    await expectLater(
      h.auth.login(testEmail, 'test-password'),
      throwsA(isA<ApiFailure>().having((e) => e.statusCode, 'status', 429)),
    );
    await expectLater(h.auth.resendOtp(challenge), throwsA(isA<ApiFailure>()));
    expect(h.adapter.requests.length, 1);
  });

  test(
    'Pending OTP can be resumed; concurrent login/register cannot send twice',
    () async {
      final response = Completer<ResponseBody>();
      final h = harness((_) => response.future);
      final login = h.auth.login(testEmail, 'test-password');
      await expectLater(
        h.auth.register('Test User', testEmail.toUpperCase(), 'test123'),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'OTP_IN_FLIGHT'),
        ),
      );
      response.complete(jsonResponse({'requiresOtp': true}));
      final pending = await login;
      expect(h.auth.pendingChallengeFor(' $testEmail '), same(pending));
      expect(h.auth.resendSeconds(testEmail), greaterThan(0));
      await expectLater(h.auth.resendOtp(pending), throwsA(isA<ApiFailure>()));
      expect(h.adapter.requests.length, 1);
      expect(h.auth.user, isNull);
      expect(h.storage.writes, 0);
    },
  );

  for (final entry in {
    'Admin': UserRole.admin,
    'Manager': UserRole.manager,
    'Employee': UserRole.employee,
  }.entries) {
    test('Restores ${entry.key} from authenticated me', () async {
      final h = harness((request) {
        expect(request.path, ApiConfig.me);
        expect(request.headers['Authorization'], 'Bearer $testToken');
        return jsonResponse(userJson(entry.key));
      }, token: testToken);
      await h.auth.restoreSession();
      expect(h.auth.user?.role, entry.value);
      expect(h.auth.restoring, isFalse);
      expect(h.auth.sessionError, isNull);
    });
  }

  for (final status in [401, 403]) {
    test('Me $status clears persistent session and returns to login', () async {
      final h = harness(
        (_) => jsonResponse({}, status: status),
        token: testToken,
      );
      await h.auth.restoreSession();
      expect(h.auth.user, isNull);
      expect(h.storage.value, isNull);
      expect(h.auth.restoring, isFalse);
      expect(h.auth.sessionError, isNull);
      expect(h.auth.notice, isNotNull);
    });
  }

  test(
    'Offline restore grants no access, retains token and supports retry',
    () async {
      var offline = true;
      final h = harness((request) {
        if (offline) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(userJson());
      }, token: testToken);
      await h.auth.restoreSession();
      expect(h.auth.user, isNull);
      expect(h.auth.sessionError, contains('kết nối'));
      expect(h.storage.value, testToken);
      offline = false;
      await h.auth.retrySession();
      expect(h.auth.user?.role, UserRole.employee);
      expect(h.auth.sessionError, isNull);
    },
  );

  test('Unknown server role never falls back to Employee', () async {
    final h = harness((_) => jsonResponse(userJson('Owner')), token: testToken);
    await h.auth.restoreSession();
    expect(h.auth.user, isNull);
    expect(h.auth.sessionError, contains('quyền'));
  });

  test('Invalid me user data cannot open a dashboard', () async {
    final h = harness(
      (_) => jsonResponse({'role': 'Admin', 'id': 99}),
      token: testToken,
    );
    await h.auth.restoreSession();
    expect(h.auth.user, isNull);
    expect(h.auth.sessionError, isNotNull);
  });

  test('OTP accepted but me unavailable does not open a dashboard', () async {
    final h = harness(
      (request) => request.path == ApiConfig.verifyOtp
          ? jsonResponse({'token': testToken})
          : jsonResponse({}, status: 503),
    );
    await h.auth.verifyOtp(challenge, '123456');
    expect(h.auth.user, isNull);
    expect(h.auth.sessionError, isNotNull);
    expect(h.storage.value, testToken);
  });

  test(
    'Logout deletes stored token and removes authorization header',
    () async {
      final h = harness((_) => jsonResponse(userJson()), token: testToken);
      await h.auth.restoreSession();
      await h.auth.logout();
      expect(h.auth.user, isNull);
      expect(h.storage.value, isNull);
      await h.client.get(ApiConfig.me);
      expect(
        h.adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  test(
    'Logout during an in-flight OTP response prevents late authentication',
    () async {
      final pending = Completer<ResponseBody>();
      final h = harness((_) => pending.future);
      final verifying = h.auth.verifyOtp(challenge, '123456');
      await Future<void>.delayed(Duration.zero);
      await h.auth.logout();
      pending.complete(jsonResponse({'token': testToken}));
      await verifying;
      expect(h.auth.user, isNull);
      expect(h.storage.writes, 0);
    },
  );

  test(
    'Secure storage write failure cleans up a partially written token',
    () async {
      final h = harness((_) => jsonResponse({'token': testToken}));
      h.storage.failWrite = true;
      await expectLater(
        h.auth.verifyOtp(challenge, '123456'),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.auth.user, isNull);
      expect(h.storage.value, isNull);
    },
  );

  test(
    'Failed token deletion blocks restore until deletion succeeds',
    () async {
      final h = harness((_) => jsonResponse(userJson()), token: testToken);
      await h.auth.restoreSession();
      h.storage.failDelete = true;
      await h.auth.logout();
      await h.auth.restoreSession();
      expect(h.auth.user, isNull);
      expect(h.auth.sessionError, contains('xóa phiên'));
      expect(h.adapter.requests.length, 1);
      h.storage.failDelete = false;
      await h.auth.retrySession();
      expect(h.auth.sessionError, isNull);
      expect(h.storage.value, isNull);
    },
  );

  test(
    'A failed storage read shows recovery without an HTTP request',
    () async {
      final h = harness((_) => throw StateError('Unexpected request'));
      h.storage.failRead = true;
      await h.auth.restoreSession();
      expect(h.auth.user, isNull);
      expect(h.auth.sessionError, contains('đọc phiên'));
      expect(h.adapter.requests, isEmpty);
    },
  );

  test('Wrong password shows safe error without creating a session', () async {
    final h = harness(
      (_) =>
          jsonResponse({'message': 'Sai tài khoản hoặc mật khẩu'}, status: 401),
    );
    await expectLater(
      h.auth.login(testEmail, 'test-password'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          'Email hoặc mật khẩu không đúng.',
        ),
      ),
    );
    expect(h.storage.writes, 0);
    expect(h.auth.user, isNull);
    expect(h.auth.resendSeconds(testEmail), 0);
  });

  test(
    'Timeout keeps resend cooldown because mail delivery is uncertain',
    () async {
      final h = harness(
        (request) => throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        h.auth.login(testEmail, 'test-password'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('thời gian chờ'),
          ),
        ),
      );
      expect(h.auth.resendSeconds(testEmail), greaterThan(0));
      expect(h.auth.user, isNull);
    },
  );

  test(
    'Unexpected HTML is rejected without exposing response contents',
    () async {
      final h = harness(
        (_) => ResponseBody.fromString(
          '<html>internal server page</html>',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );
      await expectLater(
        h.auth.login(testEmail, 'test-password'),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.auth.user, isNull);
    },
  );

  test('Unknown error bodies are not displayed to the user', () {
    final error = DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: 400,
        data: {'message': 'arbitrary-sensitive-value'},
      ),
    );
    expect(
      ApiFailure.fromDio(error).message,
      isNot(contains('arbitrary-sensitive-value')),
    );
  });
}

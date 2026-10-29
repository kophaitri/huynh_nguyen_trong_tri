import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huynh_nguyen_trong_tri/core/config/api_config.dart';
import 'package:huynh_nguyen_trong_tri/core/network/api_client.dart';
import 'package:huynh_nguyen_trong_tri/core/network/api_failure.dart';
import 'package:huynh_nguyen_trong_tri/widgets/cached_load_view.dart';

import 'support/auth_fakes.dart';

void main() {
  testWidgets(
    'Switching to cached data ends loading and ignores a late disposed load',
    (tester) async {
      final old = Completer<int>();
      late StateSetter update;
      var dataset = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CachedLoadView<int>(
                dataKey: dataset,
                cached: () => dataset == 1 ? 7 : null,
                load: (_) => old.future,
                builder: (_, snapshot) =>
                    Text('${snapshot.data}:${snapshot.loading}'),
              );
            },
          ),
        ),
      );
      update(() => dataset = 1);
      await tester.pump();
      expect(find.text('7:false'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      old.complete(9);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  ApiClient client(MockResponder respond) {
    final api = ApiClient(
      dio: Dio()..httpClientAdapter = MockHttpAdapter(respond),
    );
    api.token = testToken;
    addTearDown(api.close);
    return api;
  }

  test(
    'GET deduplicates in-flight requests; manual refresh bypasses cache',
    () async {
      var calls = 0;
      final pending = Completer<ResponseBody>();
      final entered = Completer<void>();
      final api = client((_) {
        calls++;
        if (!entered.isCompleted) entered.complete();
        return calls == 1 ? pending.future : jsonResponse(userJson());
      });
      final first = api.get(ApiConfig.me);
      final second = api.get(ApiConfig.me);
      await entered.future;
      expect(calls, 1);
      pending.complete(jsonResponse(userJson()));
      await Future.wait([first, second]);
      await api.get(ApiConfig.me);
      expect(calls, 1);
      await api.get(ApiConfig.me, forceRefresh: true);
      expect(calls, 2);
    },
  );

  test(
    'Successful write invalidates reads and is never cached or retried',
    () async {
      var reads = 0;
      var writes = 0;
      final api = client((r) {
        if (r.method == 'GET') {
          reads++;
          return jsonResponse({
            'total': 0,
            'page': 1,
            'pageSize': 20,
            'items': [],
          });
        }
        writes++;
        return ResponseBody.fromString('', 204);
      });
      await api.get(ApiConfig.departments);
      await api.get(ApiConfig.departments);
      expect(reads, 1);
      await api.request(
        'PUT',
        '${ApiConfig.departments}/11',
        data: {'name': 'Test'},
      );
      await api.get(ApiConfig.departments);
      expect(reads, 2);
      expect(writes, 1);
      api.token = 'another-test-token';
      expect(api.cached(ApiConfig.departments), isNull);
    },
  );

  test(
    'Session restore must contact server and honor 401 despite warm me cache',
    () async {
      var reject = false;
      final h = AuthHarness(
        (_) =>
            reject ? jsonResponse({}, status: 401) : jsonResponse(userJson()),
        token: testToken,
      );
      addTearDown(h.auth.dispose);
      h.client.token = testToken;
      await h.client.get(ApiConfig.me);
      expect(h.client.cached(ApiConfig.me), isNotNull);
      reject = true;
      await h.auth.restoreSession();
      expect(h.auth.user, isNull);
      expect(h.storage.value, isNull);
      expect(h.client.cached(ApiConfig.me), isNull);
    },
  );

  testWidgets('GET has a total deadline even if the adapter never replies', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<ResponseBody>();
    final api = client((_) {
      calls++;
      return pending.future;
    });
    final assertion = expectLater(
      api.get(ApiConfig.me),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'API_TIMEOUT')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await assertion;
    expect(calls, 1);
    pending.complete(jsonResponse(userJson()));
    await tester.pump();
    expect(api.cached(ApiConfig.me), isNull);
  });

  test(
    'Debug timings redact IDs, query, email, headers and request bodies',
    () async {
      final messages = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousPrint);
      final api = client((_) => jsonResponse({'id': 1}));
      await api.request(
        'PUT',
        '${ApiConfig.employees}/private-user-id',
        data: {'email': 'private@example.test', 'password': 'private-password'},
      );
      final log = messages.join('\n');
      expect(log, contains('PUT /api/employees/:id'));
      expect(log, contains('status=200'));
      for (final secret in [
        'private-user-id',
        'private@example.test',
        'private-password',
        testToken,
      ]) {
        expect(log, isNot(contains(secret)));
      }
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:huynh_nguyen_trong_tri/core/network/api_client.dart';
import 'package:huynh_nguyen_trong_tri/core/storage/token_storage.dart';
import 'package:huynh_nguyen_trong_tri/services/auth_service.dart';

const testToken = 'mock-token-not-a-real-jwt';
const testEmail = 'user@example.test';

Map<String, dynamic> userJson([String role = 'Employee']) => {
  'id': 'test-user-id',
  'fullName': 'Test User',
  'email': testEmail,
  'role': role,
  'employeeCode': null,
  'departmentId': null,
  'hasFace': false,
  'deviceBound': false,
};

ResponseBody jsonResponse(
  Object data, {
  int status = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

typedef MockResponder = FutureOr<ResponseBody> Function(RequestOptions request);

/// Never delegates to a network adapter, including unexpected requests.
class MockHttpAdapter implements HttpClientAdapter {
  MockHttpAdapter(this.respond);
  final MockResponder respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.value]);
  String? value;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  int writes = 0;
  int deletes = 0;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('mock read failure');
    return value;
  }

  @override
  Future<void> write(String token) async {
    writes++;
    value = token;
    if (failWrite) throw StateError('mock write failure');
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (failDelete) throw StateError('mock delete failure');
    value = null;
  }
}

class AuthHarness {
  AuthHarness(
    MockResponder respond, {
    String? token,
    DateTime Function()? now,
  }) {
    adapter = MockHttpAdapter(respond);
    storage = MemoryTokenStorage(token);
    client = ApiClient(dio: Dio()..httpClientAdapter = adapter);
    auth = AuthService(client: client, storage: storage, now: now);
  }

  late final MockHttpAdapter adapter;
  late final MemoryTokenStorage storage;
  late final ApiClient client;
  late final AuthService auth;
}

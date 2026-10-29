import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'api_failure.dart';

class _ReadCache {
  _ReadCache(this.data) : savedAt = DateTime.now();
  final dynamic data;
  final DateTime savedAt;
  final Stopwatch age = Stopwatch()..start();
  bool get fresh => age.elapsed < ApiConfig.cacheLifetime;
}

class _ApiTiming {
  _ApiTiming(this.method, this.path);
  final String method;
  final String path;
  final Stopwatch watch = Stopwatch()..start();
  bool logged = false;
  void finish({int? status, String? error}) {
    if (logged) return;
    logged = true;
    if (kDebugMode) {
      // No query strings, resource IDs, payloads, headers or error.toString().
      debugPrint(
        '[TriWork API] $method ${_safePath(path)} ${watch.elapsedMilliseconds}ms status=${status ?? '-'}${error == null ? '' : ' error=$error'}',
      );
    }
  }

  static String _safePath(String path) {
    const known = [
      ApiConfig.me,
      ApiConfig.login,
      ApiConfig.register,
      ApiConfig.verifyOtp,
      ApiConfig.resendOtp,
      ApiConfig.employees,
      ApiConfig.departments,
      ApiConfig.shifts,
      ApiConfig.locations,
      ApiConfig.leaves,
      ApiConfig.myAttendance,
      ApiConfig.checkIn,
      ApiConfig.checkOut,
      ApiConfig.currentQr,
    ];
    if (known.contains(path)) return path;
    for (final root in [
      ApiConfig.employees,
      ApiConfig.departments,
      ApiConfig.shifts,
      ApiConfig.locations,
      ApiConfig.leaves,
    ]) {
      if (path.startsWith('$root/')) {
        final suffix = path.substring(root.length + 1).split('/');
        final action =
            suffix.length == 2 &&
                const ['review', 'face', 'reset-device'].contains(suffix.last)
            ? '/${suffix.last}'
            : '';
        return '$root/:id$action';
      }
    }
    return '/other';
  }
}

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      sendTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          (response.requestOptions.extra['timing'] as _ApiTiming?)?.finish(
            status: response.statusCode,
          );
          handler.next(response);
        },
        onError: (error, handler) async {
          (error.requestOptions.extra['timing'] as _ApiTiming?)?.finish(
            status: error.response?.statusCode,
            error: error.type.name,
          );
          if (error.requestOptions.extra['authenticated'] == true &&
              _token != null &&
              error.requestOptions.headers['Authorization'] ==
                  'Bearer $_token' &&
              (error.response?.statusCode == 401 ||
                  (error.response?.statusCode == 403 &&
                      error.requestOptions.path == ApiConfig.me))) {
            clearCache();
            await onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final _cache = <String, _ReadCache>{};
  final _inflight = <String, Future<dynamic>>{};
  String? _token;
  bool _closed = false;
  int _epoch = 0;
  int get cacheRevision => _epoch;
  set token(String? value) {
    if (_token == value) return;
    _token = value;
    clearCache();
  }

  Future<void> Function()? onUnauthorized;
  static final _freshZone = Object();
  static final _readObserverZone = Object();

  /// Explicit refresh propagates through services/lookups without a global flag.
  static Future<T> freshReads<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_freshZone: true});
  static Future<T> observeReads<T>(
    Future<T> Function() action,
    void Function(DateTime) onCacheHit,
  ) => runZoned(action, zoneValues: {_readObserverZone: onCacheHit});

  bool _cacheable(String path, bool authenticated) =>
      authenticated &&
      _token != null &&
      const [
        ApiConfig.me,
        ApiConfig.employees,
        ApiConfig.departments,
        ApiConfig.shifts,
        ApiConfig.locations,
        ApiConfig.leaves,
        ApiConfig.myAttendance,
      ].contains(path);
  String _key(String path, Map<String, dynamic>? query) {
    final keys = query?.keys.toList() ?? <String>[];
    keys.sort();
    return '$_epoch:$path:${jsonEncode({for (final k in keys) k: query![k]})}';
  }

  dynamic cached(String path, {Map<String, dynamic>? queryParameters}) {
    if (!_cacheable(path, true)) return null;
    final key = _key(path, queryParameters);
    final entry = _cache[key];
    if (entry == null) return null;
    if (!entry.fresh) {
      _cache.remove(key);
      return null;
    }
    return entry.data;
  }

  void clearCache() {
    _epoch++;
    _cache.clear();
    _inflight.clear();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) =>
      _map(request('POST', path, data: data, authenticated: false));
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
    bool forceRefresh = false,
  }) => _map(
    request(
      'GET',
      path,
      authenticated: authenticated,
      forceRefresh: forceRefresh,
    ),
  );
  Future<Map<String, dynamic>> _map(Future<dynamic> result) async {
    final data = await result;
    if (data is! Map<String, dynamic>) {
      throw const ApiFailure('Phản hồi máy chủ không đúng định dạng.');
    }
    return data;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
    bool forceRefresh = false,
  }) {
    if (_closed) {
      return Future.error(
        const ApiFailure('Kết nối đã đóng. Vui lòng đăng nhập lại.'),
      );
    }
    method = method.toUpperCase();
    final isGet = method == 'GET';
    final key = _key(path, queryParameters);
    final inflightKey = '$key:$authenticated';
    final epoch = _epoch;
    if (isGet) {
      if (!forceRefresh && Zone.current[_freshZone] != true) {
        final hit = cached(path, queryParameters: queryParameters);
        if (hit != null && authenticated) {
          (Zone.current[_readObserverZone] as void Function(DateTime)?)?.call(
            _cache[key]!.savedAt,
          );
          return Future.value(hit);
        }
      }
      final pending = _inflight[inflightKey];
      if (pending != null) return pending;
    }
    final future =
        _send(
          method,
          path,
          data: data,
          queryParameters: queryParameters,
          authenticated: authenticated,
          epoch: epoch,
        ).then((result) {
          if (isGet && epoch == _epoch && _cacheable(path, authenticated)) {
            _cache.removeWhere((_, entry) => !entry.fresh);
            if (_cache.length >= 64) _cache.remove(_cache.keys.first);
            _cache[key] = _ReadCache(result);
          }
          return result;
        });
    if (!isGet) return future;
    late final Future<dynamic> tracked;
    tracked = future.whenComplete(() {
      if (identical(_inflight[inflightKey], tracked)) {
        _inflight.remove(inflightKey);
      }
    });
    _inflight[inflightKey] = tracked;
    return tracked;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    required bool authenticated,
    required int epoch,
  }) async {
    final isGet = method == 'GET';
    final requestToken = _token;
    final timing = _ApiTiming(method, path);
    final cancel = CancelToken();
    try {
      final response = await _dio
          .request<dynamic>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancel,
            options: Options(
              method: method,
              receiveTimeout: isGet
                  ? ApiConfig.getReceiveTimeout
                  : ApiConfig.receiveTimeout,
              headers: {
                if (authenticated && requestToken != null)
                  'Authorization': 'Bearer $requestToken',
              },
              extra: {'authenticated': authenticated, 'timing': timing},
            ),
          )
          .timeout(
            isGet ? ApiConfig.getDeadline : ApiConfig.writeDeadline,
            onTimeout: () {
              timing.finish(error: 'deadlineExceeded');
              cancel.cancel('deadlineExceeded');
              throw const ApiFailure(
                'Kết nối quá thời gian chờ. Vui lòng bấm Thử lại.',
                code: 'API_TIMEOUT',
              );
            },
          );
      if (authenticated &&
          (requestToken != _token || (isGet && epoch != _epoch))) {
        throw const ApiFailure(
          'Phiên hoặc dữ liệu đã thay đổi. Vui lòng tải lại.',
          code: 'STALE_READ',
        );
      }
      // Conservative invalidation also prevents list/lookup dependencies going stale.
      if (!isGet) clearCache();
      if (response.statusCode == 204) return null;
      if (response.data is! Map<String, dynamic> && response.data is! List) {
        throw const ApiFailure('Phản hồi máy chủ không đúng định dạng.');
      }
      return response.data;
    } on DioException catch (error) {
      timing.finish(status: error.response?.statusCode, error: error.type.name);
      if (!isGet) clearCache();
      throw ApiFailure.fromDio(error);
    } on FormatException {
      timing.finish(error: 'invalidJson');
      throw const ApiFailure('Phản hồi máy chủ không đúng định dạng.');
    } on ApiFailure {
      if (!isGet) clearCache();
      rethrow;
    } finally {
      timing.finish(error: 'unexpectedFailure');
    }
  }

  void close() {
    _closed = true;
    _token = null;
    clearCache();
    onUnauthorized = null;
    _dio.close(force: true);
  }
}

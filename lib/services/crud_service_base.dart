import '../core/network/api_failure.dart';
import '../core/network/api_client.dart';
import '../core/network/json_reader.dart';
import '../models/paged_response.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

abstract class CrudServiceBase {
  CrudServiceBase(this.auth);
  final AuthService auth;
  UserModel get currentUser =>
      auth.user ??
      (throw const ApiFailure('Vui lòng đăng nhập lại.', statusCode: 401));
  void ensureAdmin() {
    if (currentUser.role != UserRole.admin) {
      throw const ApiFailure(
        'Chỉ Admin được thực hiện thao tác này.',
        statusCode: 403,
      );
    }
  }

  void ensureReviewer() {
    if (currentUser.role == UserRole.employee) {
      throw const ApiFailure(
        'Bạn không có quyền truy cập mục này.',
        statusCode: 403,
      );
    }
  }

  void ensureSignedIn() {
    currentUser;
  }
}

abstract class PagedCrudService<T> extends CrudServiceBase {
  PagedCrudService(super.auth, this.path, this.decode);
  final String path;
  final T Function(Map<String, dynamic>) decode;

  Future<PagedResponse<T>> list({int page = 1, int pageSize = 20}) async {
    ensureSignedIn();
    final result = await auth.client.request(
      'GET',
      path,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponse.fromJson(result, decode);
  }

  Future<T> get(int id) async {
    ensureSignedIn();
    return decode(
      JsonReader.map(await auth.client.request('GET', '$path/$id')),
    );
  }

  /// Lookup selectors must not silently omit records after the first page.
  Future<List<T>> all({bool forceRefresh = false}) =>
      (forceRefresh ? ApiClient.freshReads(_all) : _all()).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const ApiFailure(
          'Tải danh mục quá thời gian chờ. Vui lòng thử lại.',
        ),
      );

  Future<List<T>> _all() async {
    final watch = Stopwatch()..start();
    final items = <T>[];
    var page = 1;
    while (true) {
      final result = await list(page: page, pageSize: 200);
      if (watch.elapsed >= const Duration(seconds: 20)) {
        throw const ApiFailure(
          'Tải danh mục quá thời gian chờ. Vui lòng thử lại.',
        );
      }
      if (result.page != page) JsonReader.invalid();
      items.addAll(result.items);
      if (!result.hasNext) return items;
      if (result.items.isEmpty) JsonReader.invalid();
      page++;
    }
  }

  Future<T> createJson(Map<String, dynamic> input) async {
    ensureAdmin();
    return decode(
      JsonReader.map(await auth.client.request('POST', path, data: input)),
    );
  }

  Future<void> updateJson(int id, Map<String, dynamic> input) async {
    ensureAdmin();
    await auth.client.request('PUT', '$path/$id', data: input);
  }

  Future<void> delete(int id) async {
    ensureAdmin();
    await auth.client.request('DELETE', '$path/$id');
  }
}

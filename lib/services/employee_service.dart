import '../core/config/api_config.dart';
import '../core/network/api_failure.dart';
import '../core/network/json_reader.dart';
import '../core/validation/auth_validators.dart';
import '../core/validation/crud_validators.dart';
import '../models/employee_model.dart';
import '../models/paged_response.dart';
import 'crud_service_base.dart';

class EmployeeService extends CrudServiceBase {
  EmployeeService(super.auth);
  String _path(String id) =>
      '${ApiConfig.employees}/${Uri.encodeComponent(id)}';

  Future<PagedResponse<EmployeeModel>> list({
    String query = '',
    int? departmentId,
    int page = 1,
    int pageSize = 20,
  }) async {
    ensureReviewer();
    final data = await auth.client.request(
      'GET',
      ApiConfig.employees,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'departmentId': ?departmentId,
      },
    );
    return PagedResponse.fromJson(data, EmployeeModel.fromJson);
  }

  Future<EmployeeModel> get(String id) async {
    ensureReviewer();
    return EmployeeModel.fromJson(
      JsonReader.map(await auth.client.request('GET', _path(id))),
    );
  }

  void _validateRole(String? role) {
    if (role != null &&
        !const ['Admin', 'Manager', 'Employee'].contains(role)) {
      throw const ApiFailure('Vai trò nhân viên không hợp lệ.');
    }
  }

  Future<String> create(EmployeeCreateInput input) async {
    ensureAdmin();
    CrudValidators.check([
      AuthValidators.email(input.email),
      AuthValidators.newPassword(input.password),
      CrudValidators.requiredText(input.fullName),
    ]);
    _validateRole(input.role);
    final result = JsonReader.map(
      await auth.client.request(
        'POST',
        ApiConfig.employees,
        data: input.toJson(),
      ),
    );
    return JsonReader.string(result['id']);
  }

  Future<void> update(String id, EmployeeUpdateInput input) async {
    ensureAdmin();
    CrudValidators.check([CrudValidators.requiredText(input.fullName)]);
    _validateRole(input.role);
    await auth.client.request('PUT', _path(id), data: input.toJson());
    if (id == auth.user?.id) await auth.restoreSession();
  }

  Future<void> delete(String id) async {
    ensureAdmin();
    await auth.client.request('DELETE', _path(id));
    if (id == auth.user?.id) await auth.logout();
  }
}

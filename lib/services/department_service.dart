import '../core/config/api_config.dart';
import '../core/validation/crud_validators.dart';
import '../models/department_model.dart';
import 'auth_service.dart';
import 'crud_service_base.dart';

class DepartmentService extends PagedCrudService<DepartmentModel> {
  DepartmentService(AuthService auth)
    : super(auth, ApiConfig.departments, DepartmentModel.fromJson);
  Future<DepartmentModel> create(DepartmentInput input) {
    CrudValidators.check([CrudValidators.requiredText(input.name)]);
    return createJson(input.toJson());
  }

  Future<void> update(int id, DepartmentInput input) {
    CrudValidators.check([CrudValidators.requiredText(input.name)]);
    return updateJson(id, input.toJson());
  }
}

import '../core/config/api_config.dart';
import '../core/validation/crud_validators.dart';
import '../models/shift_model.dart';
import 'auth_service.dart';
import 'crud_service_base.dart';

class ShiftService extends PagedCrudService<ShiftModel> {
  ShiftService(AuthService auth)
    : super(auth, ApiConfig.shifts, ShiftModel.fromJson);
  void _validate(ShiftInput input) => CrudValidators.check([
    CrudValidators.requiredText(input.name),
    CrudValidators.time(input.startTime),
    CrudValidators.time(input.endTime),
    CrudValidators.nonNegativeInt('${input.lateToleranceMinutes}'),
  ]);
  Future<ShiftModel> create(ShiftInput input) {
    _validate(input);
    return createJson(input.toJson());
  }

  Future<void> update(int id, ShiftInput input) {
    _validate(input);
    return updateJson(id, input.toJson());
  }
}

import '../core/config/api_config.dart';
import '../core/validation/crud_validators.dart';
import '../models/work_location_model.dart';
import 'auth_service.dart';
import 'crud_service_base.dart';

class LocationService extends PagedCrudService<WorkLocationModel> {
  LocationService(AuthService auth)
    : super(auth, ApiConfig.locations, WorkLocationModel.fromJson);
  void _validate(WorkLocationInput input) => CrudValidators.check([
    CrudValidators.requiredText(input.name),
    CrudValidators.coordinate('${input.latitude}', latitude: true),
    CrudValidators.coordinate('${input.longitude}', latitude: false),
    CrudValidators.positiveInt('${input.radiusMeters}'),
    CrudValidators.positiveInt('${input.shiftId}'),
  ]);
  Future<WorkLocationModel> create(WorkLocationInput input) {
    _validate(input);
    return createJson(input.toJson());
  }

  Future<void> update(int id, WorkLocationInput input) {
    _validate(input);
    return updateJson(id, input.toJson());
  }
}

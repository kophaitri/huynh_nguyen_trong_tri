import '../core/config/api_config.dart';
import '../core/network/api_failure.dart';
import '../core/network/json_reader.dart';
import '../core/validation/crud_validators.dart';
import '../models/leave_request_model.dart';
import '../models/user_model.dart';
import 'crud_service_base.dart';

class LeaveService extends CrudServiceBase {
  LeaveService(super.auth);
  bool canEdit(LeaveRequestModel leave) =>
      auth.user?.id == leave.userId && leave.status == LeaveStatus.pending;
  bool canDelete(LeaveRequestModel leave) =>
      auth.user?.role == UserRole.admin || canEdit(leave);
  bool canReview(LeaveRequestModel leave) =>
      auth.user != null &&
      auth.user!.role != UserRole.employee &&
      leave.status == LeaveStatus.pending;

  Future<List<LeaveRequestModel>> list({LeaveStatus? status}) async {
    ensureSignedIn();
    final data = await auth.client.request(
      'GET',
      ApiConfig.leaves,
      queryParameters: {if (status != null) 'status': status.apiValue},
    );
    final items = JsonReader.list(data, LeaveRequestModel.fromJson);
    return currentUser.role == UserRole.employee
        ? items.where((l) => l.userId == currentUser.id).toList()
        : items;
  }

  void _validate(LeaveInput input) {
    CrudValidators.check([
      CrudValidators.date(input.fromDate),
      CrudValidators.date(input.toDate),
      CrudValidators.requiredText(input.reason),
    ]);
    if (input.toDate.compareTo(input.fromDate) < 0) {
      throw const ApiFailure('Ngày kết thúc không được trước ngày bắt đầu.');
    }
  }

  Future<int> create(LeaveInput input) async {
    ensureSignedIn();
    _validate(input);
    final result = JsonReader.map(
      await auth.client.request('POST', ApiConfig.leaves, data: input.toJson()),
    );
    return JsonReader.integer(result['id']);
  }

  Future<void> update(LeaveRequestModel leave, LeaveInput input) async {
    ensureSignedIn();
    if (!canEdit(leave)) {
      throw const ApiFailure(
        'Chỉ được sửa đơn của mình khi đang chờ duyệt.',
        statusCode: 403,
      );
    }
    _validate(input);
    await auth.client.request(
      'PUT',
      '${ApiConfig.leaves}/${leave.id}',
      data: input.toJson(),
    );
  }

  Future<void> delete(LeaveRequestModel leave) async {
    ensureSignedIn();
    if (!canDelete(leave)) {
      throw const ApiFailure('Bạn không được hủy đơn này.', statusCode: 403);
    }
    await auth.client.request('DELETE', '${ApiConfig.leaves}/${leave.id}');
  }

  Future<void> review(LeaveRequestModel leave, {required bool approve}) async {
    ensureReviewer();
    if (!canReview(leave)) {
      throw const ApiFailure('Đơn không còn chờ duyệt. Vui lòng làm mới.');
    }
    await auth.client.request(
      'POST',
      '${ApiConfig.leaves}/${leave.id}/review',
      data: {'approve': approve},
    );
  }
}

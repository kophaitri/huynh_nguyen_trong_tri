import '../core/config/api_config.dart';
import '../core/network/api_failure.dart';
import '../core/network/api_client.dart';
import '../core/network/json_reader.dart';
import '../models/shift_model.dart';
import '../models/smart_insights_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'shift_service.dart';

class SmartInsightsData {
  const SmartInsightsData({
    required this.insights,
    required this.shifts,
    this.shiftError,
  });
  final SmartInsightsModel insights;
  final List<ShiftModel> shifts;
  final String? shiftError;
}

class SmartInsightsService {
  SmartInsightsService(this.auth);
  final AuthService auth;
  Future<SmartInsightsData> load({int days = 30, bool forceRefresh = false}) =>
      forceRefresh ? ApiClient.freshReads(() => _load(days)) : _load(days);

  Future<SmartInsightsData> _load(int days) async {
    if (auth.user?.role != UserRole.employee) {
      throw const ApiFailure(
        'Smart Insights chỉ dành cho tài khoản Employee.',
        statusCode: 403,
      );
    }
    List<ShiftModel> shifts = [];
    String? shiftError;
    final shiftFuture = () async {
      try {
        shifts = await ShiftService(auth).all();
      } on ApiFailure catch (error) {
        shiftError = error.message;
      }
    }();
    final historyFuture = auth.client.request(
      'GET',
      ApiConfig.myAttendance,
      queryParameters: {'days': days},
    );
    // Keep both futures observed, even if history fails before shifts return.
    final results = await Future.wait<dynamic>([historyFuture, shiftFuture]);
    final rows = JsonReader.list<Map<String, dynamic>>(
      results.first,
      (row) => row,
    );
    return SmartInsightsData(
      insights: SmartInsightsModel.fromRows(rows),
      shifts: shifts,
      shiftError: shiftError,
    );
  }
}

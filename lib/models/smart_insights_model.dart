import 'shift_model.dart';

/// A CheckIn is one session. CheckOut is never another worked session.
/// Missing status/type stays unknown instead of silently becoming on-time.
class SmartInsightsModel {
  SmartInsightsModel.fromRows(List<Map<String, dynamic>> rows) {
    final seenIds = <int>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is! int || id <= 0) {
        unknownTypeCount++;
        continue;
      }
      if (!seenIds.add(id)) continue;
      final type = row['type'];
      if (type == 'CheckOut') continue;
      if (type != 'CheckIn') {
        unknownTypeCount++;
        continue;
      }
      checkInCount++;
      final late = row['isLate'];
      if (late == true) {
        knownLateCount++;
      } else if (late == false) {
        knownOnTimeCount++;
      } else {
        unknownStatusCount++;
      }
    }
  }

  int checkInCount = 0;
  int knownOnTimeCount = 0;
  int knownLateCount = 0;
  int unknownStatusCount = 0;
  int unknownTypeCount = 0;
  bool get hasCompleteClassification =>
      unknownStatusCount == 0 && unknownTypeCount == 0;
  int? get sessionCount => unknownTypeCount == 0 ? checkInCount : null;
  int? get onTimeCount => hasCompleteClassification ? knownOnTimeCount : null;
  int? get lateCount => hasCompleteClassification ? knownLateCount : null;
  double? get onTimeRate => hasCompleteClassification && checkInCount > 0
      ? knownOnTimeCount / checkInCount
      : null;

  // /attendance/my has no lateMinutes or historical scheduled start/shift id.
  // Joining location names to today's shifts would fabricate historical timing.
  double? get averageLateMinutes => null;

  PreparationSuggestion? preparationFor(ShiftModel shift) {
    final match = RegExp(r'^(\d{2}):([0-5]\d):([0-5]\d)$')
        .firstMatch(shift.startTime);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    if (hour > 23) return null;
    final startSeconds =
        hour * 3600 + int.parse(match[2]!) * 60 + int.parse(match[3]!);
    final adjustment = averageLateMinutes;
    final seconds = startSeconds - 15 * 60 - ((adjustment ?? 0) * 60).ceil();
    final wrapped = seconds % (24 * 3600);
    final time =
        '${(wrapped ~/ 3600).toString().padLeft(2, '0')}:${(wrapped % 3600 ~/ 60).toString().padLeft(2, '0')}';
    return PreparationSuggestion(
      time: time,
      previousDay: seconds < 0,
      personalized: adjustment != null,
      shiftName: shift.name,
      startTime: shift.startTime,
    );
  }
}

class PreparationSuggestion {
  const PreparationSuggestion({
    required this.time,
    required this.previousDay,
    required this.personalized,
    required this.shiftName,
    required this.startTime,
  });
  final String time;
  final bool previousDay;
  final bool personalized;
  final String shiftName;
  final String startTime;
}

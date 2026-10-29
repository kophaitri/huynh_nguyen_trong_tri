import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Evidence of a local movement challenge, never an identity match or robust PAD.
class LivenessEvidence {
  const LivenessEvidence._(this.userId, this.completedAt);
  final String userId;
  final DateTime completedAt;
  bool get fresh => DateTime.now().difference(completedAt).inSeconds < 90;
}

class FaceLivenessService {
  FaceLivenessService({required this.userId, required this.turnRight});
  final String userId;
  final bool turnRight;
  int _stage = 0;
  int _frames = 0;
  int? _trackingId;
  DateTime _started = DateTime.now();
  String get instruction => switch (_stage) {
    0 => 'Nhìn thẳng, mở cả hai mắt',
    1 => 'Chớp mắt: nhắm cả hai mắt',
    2 => 'Mở lại cả hai mắt',
    _ =>
      turnRight ? 'Quay đầu sang phải của bạn' : 'Quay đầu sang trái của bạn',
  };
  void reset() {
    _stage = 0;
    _frames = 0;
    _trackingId = null;
    _started = DateTime.now();
  }

  LivenessEvidence? process(List<Face> faces) {
    if (DateTime.now().difference(_started).inSeconds > 45) reset();
    if (faces.length != 1 || faces.single.trackingId == null) {
      reset();
      return null;
    }
    final face = faces.single;
    if (_trackingId != null && _trackingId != face.trackingId) {
      reset();
      return null;
    }
    _trackingId = face.trackingId;
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    final yaw = face.headEulerAngleY;
    if (left == null || right == null || yaw == null) {
      _frames = 0;
      return null;
    }
    final valid = switch (_stage) {
      0 => left > .7 && right > .7 && yaw.abs() < 12,
      1 => left < .25 && right < .25 && yaw.abs() < 15,
      2 => left > .7 && right > .7 && yaw.abs() < 15,
      _ => turnRight ? yaw < -20 : yaw > 20,
    };
    _frames = valid ? _frames + 1 : 0;
    if (_frames < 2) return null;
    _frames = 0;
    if (_stage < 3) {
      _stage++;
      return null;
    }
    return LivenessEvidence._(userId, DateTime.now());
  }
}

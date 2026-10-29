enum MotionLevel {
  warmingUp,
  steady,
  moving,
  strong;

  String get label => switch (this) {
    warmingUp => 'Đang thu thập mẫu',
    steady => 'Tương đối ổn định',
    moving => 'Có chuyển động',
    strong => 'Rung / lắc mạnh',
  };
}

class MotionSample {
  const MotionSample({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.variation,
    required this.elapsed,
    required this.level,
  });
  final double x;
  final double y;
  final double z;
  final double magnitude;
  // Null until two real samples exist; never fill missing data with zero.
  final double? variation;
  final Duration elapsed;
  final MotionLevel level;
}

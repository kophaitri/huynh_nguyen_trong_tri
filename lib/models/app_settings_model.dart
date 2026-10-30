import 'package:flutter/material.dart';

enum AppTextSize {
  small('Nhỏ', .9),
  normal('Mặc định', 1),
  large('Lớn', 1.15),
  extraLarge('Rất lớn', 1.3);

  const AppTextSize(this.label, this.scale);
  final String label;
  final double scale;
}

enum AppAccent {
  navy('Navy mặc định', Color(0xFF132D50)),
  blue('Xanh dương', Color(0xFF185ABC)),
  green('Xanh lá', Color(0xFF16704A)),
  purple('Tím', Color(0xFF7344A7));

  const AppAccent(this.label, this.color);
  final String label;
  final Color color;
}

class AppSettings {
  const AppSettings({
    this.textSize = AppTextSize.normal,
    this.accent = AppAccent.navy,
    this.themeMode = ThemeMode.system,
  });
  final AppTextSize textSize;
  final AppAccent accent;
  final ThemeMode themeMode;
  AppSettings copyWith({
    AppTextSize? textSize,
    AppAccent? accent,
    ThemeMode? themeMode,
  }) => AppSettings(
    textSize: textSize ?? this.textSize,
    accent: accent ?? this.accent,
    themeMode: themeMode ?? this.themeMode,
  );
  Map<String, dynamic> toJson() => {
    'textSize': textSize.name,
    'accent': accent.name,
    'themeMode': themeMode.name,
  };
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    textSize:
        AppTextSize.values
            .where((v) => v.name == json['textSize'])
            .firstOrNull ??
        AppTextSize.normal,
    accent:
        AppAccent.values.where((v) => v.name == json['accent']).firstOrNull ??
        AppAccent.navy,
    themeMode:
        ThemeMode.values
            .where((v) => v.name == json['themeMode'])
            .firstOrNull ??
        ThemeMode.system,
  );
}

import 'package:flutter/material.dart';
import 'game_models.dart';

enum DistanceUnit { miles, km }
enum AppThemeMode { light, dark }
enum ShareFormat { emojiGrid, textSummary }
enum CountryNameStyle { common, official }
enum FontSize { small, medium, large }

class AppSettings {
  final AppThemeMode themeMode;
  final DistanceUnit distanceUnit;
  final bool showContinentHint;
  final bool hardMode;
  final bool streakSaverAlert;
  final TimeOfDay streakSaverTime;
  final FontSize fontSize;
  final ShareFormat shareFormat;
  final CountryNameStyle countryNameStyle;
  final bool countryModeActive;
  final bool capitalModeActive;
  final bool flagModeActive;
  final bool neighboursModeActive;
  final bool populationModeActive;
  final bool outlineModeActive;
  final bool locationRevealEnabled;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.distanceUnit = DistanceUnit.miles,
    this.showContinentHint = true,
    this.hardMode = false,
    this.streakSaverAlert = true,
    this.streakSaverTime = const TimeOfDay(hour: 21, minute: 0),
    this.fontSize = FontSize.medium,
    this.shareFormat = ShareFormat.emojiGrid,
    this.countryNameStyle = CountryNameStyle.common,
    this.countryModeActive = true,
    this.capitalModeActive = true,
    this.flagModeActive = true,
    this.neighboursModeActive = true,
    this.populationModeActive = true,
    this.outlineModeActive = true,
    this.locationRevealEnabled = true,
  });

  List<GameMode> get activeModes => [
        if (countryModeActive) GameMode.guessCountry,
        if (capitalModeActive) GameMode.guessCapital,
        if (flagModeActive) GameMode.guessFlag,
        if (neighboursModeActive) GameMode.guessNeighbours,
        if (populationModeActive) GameMode.guessPopulation,
        if (outlineModeActive) GameMode.guessOutline,
      ];

  ThemeMode get flutterThemeMode => switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  double get fontScale => switch (fontSize) {
        FontSize.small => 0.85,
        FontSize.medium => 1.0,
        FontSize.large => 1.18,
      };

  String formatDistance(int miles) {
    if (distanceUnit == DistanceUnit.miles) return '${_fmt(miles)} mi';
    return '${_fmt((miles * 1.60934).round())} km';
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final rem = s.length % 3;
      final parts = <String>[];
      if (rem > 0) parts.add(s.substring(0, rem));
      for (int i = rem; i < s.length; i += 3) parts.add(s.substring(i, i + 3));
      return parts.join(',');
    }
    return n.toString();
  }

  AppSettings copyWith({
    AppThemeMode? themeMode, DistanceUnit? distanceUnit,
    bool? showContinentHint, bool? hardMode,
    bool? streakSaverAlert, TimeOfDay? streakSaverTime,
    FontSize? fontSize, ShareFormat? shareFormat,
    CountryNameStyle? countryNameStyle,
    bool? countryModeActive, bool? capitalModeActive, bool? flagModeActive,
    bool? neighboursModeActive, bool? populationModeActive, bool? outlineModeActive,
    bool? locationRevealEnabled,
  }) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        showContinentHint: showContinentHint ?? this.showContinentHint,
        hardMode: hardMode ?? this.hardMode,
        streakSaverAlert: streakSaverAlert ?? this.streakSaverAlert,
        streakSaverTime: streakSaverTime ?? this.streakSaverTime,
        fontSize: fontSize ?? this.fontSize,
        shareFormat: shareFormat ?? this.shareFormat,
        countryNameStyle: countryNameStyle ?? this.countryNameStyle,
        countryModeActive: countryModeActive ?? this.countryModeActive,
        capitalModeActive: capitalModeActive ?? this.capitalModeActive,
        flagModeActive: flagModeActive ?? this.flagModeActive,
        neighboursModeActive: neighboursModeActive ?? this.neighboursModeActive,
        populationModeActive: populationModeActive ?? this.populationModeActive,
        outlineModeActive: outlineModeActive ?? this.outlineModeActive,
        locationRevealEnabled: locationRevealEnabled ?? this.locationRevealEnabled,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'distanceUnit': distanceUnit.index,
        'showContinentHint': showContinentHint,
        'hardMode': hardMode,
        'streakSaverAlert': streakSaverAlert,
        'streakSaverHour': streakSaverTime.hour,
        'streakSaverMinute': streakSaverTime.minute,
        'fontSize': fontSize.index,
        'shareFormat': shareFormat.index,
        'countryNameStyle': countryNameStyle.index,
        'countryModeActive': countryModeActive,
        'capitalModeActive': capitalModeActive,
        'flagModeActive': flagModeActive,
        'neighboursModeActive': neighboursModeActive,
        'populationModeActive': populationModeActive,
        'outlineModeActive': outlineModeActive,
        'locationRevealEnabled': locationRevealEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: AppThemeMode.values[json['themeMode'] as int? ?? 1],
        distanceUnit: DistanceUnit.values[json['distanceUnit'] as int? ?? 0],
        showContinentHint: json['showContinentHint'] as bool? ?? true,
        hardMode: json['hardMode'] as bool? ?? false,
        streakSaverAlert: json['streakSaverAlert'] as bool? ?? true,
        streakSaverTime: TimeOfDay(
          hour: json['streakSaverHour'] as int? ?? 21,
          minute: json['streakSaverMinute'] as int? ?? 0,
        ),
        fontSize: FontSize.values[json['fontSize'] as int? ?? 1],
        shareFormat: ShareFormat.values[json['shareFormat'] as int? ?? 0],
        countryNameStyle: CountryNameStyle.values[json['countryNameStyle'] as int? ?? 0],
        countryModeActive: json['countryModeActive'] as bool? ?? true,
        capitalModeActive: json['capitalModeActive'] as bool? ?? true,
        flagModeActive: json['flagModeActive'] as bool? ?? true,
        neighboursModeActive: json['neighboursModeActive'] as bool? ?? true,
        populationModeActive: json['populationModeActive'] as bool? ?? true,
        outlineModeActive: json['outlineModeActive'] as bool? ?? true,
        locationRevealEnabled: json['locationRevealEnabled'] as bool? ?? true,
      );
}

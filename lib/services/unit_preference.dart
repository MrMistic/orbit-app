import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages imperial vs metric preference. DB always stores metric (kg, cm).
/// This service handles display conversion.
class UnitPreference extends GetxController {
  static const _kPrefsKey = 'unit_system_v1';

  final RxBool isImperial = false.obs;

  late final SharedPreferences _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    isImperial.value = _prefs.getBool(_kPrefsKey) ?? false;
  }

  Future<void> toggle() async {
    isImperial.value = !isImperial.value;
    await _prefs.setBool(_kPrefsKey, isImperial.value);
  }

  Future<void> setImperial(bool value) async {
    isImperial.value = value;
    await _prefs.setBool(_kPrefsKey, value);
  }

  // ─── Weight conversions ───

  String get weightUnit => isImperial.value ? 'lbs' : 'kg';

  /// Convert from DB (kg) to display unit.
  double weightForDisplay(double kg) =>
      isImperial.value ? kg * 2.20462 : kg;

  /// Convert from user input to DB (kg).
  double weightToKg(double input) =>
      isImperial.value ? input / 2.20462 : input;

  String formatWeight(double kg) =>
      '${weightForDisplay(kg).toStringAsFixed(1)} $weightUnit';

  // ─── Height conversions ───

  String get heightUnit => isImperial.value ? 'in' : 'cm';

  /// Convert from DB (cm) to display unit.
  double heightForDisplay(double cm) =>
      isImperial.value ? cm / 2.54 : cm;

  /// Convert from user input to DB (cm).
  double heightToCm(double input) =>
      isImperial.value ? input * 2.54 : input;

  String formatHeight(double cm) {
    if (isImperial.value) {
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      return '$feet\'$inches"';
    }
    return '${cm.toStringAsFixed(0)} cm';
  }
}

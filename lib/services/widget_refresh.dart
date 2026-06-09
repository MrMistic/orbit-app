import 'package:flutter/services.dart';

import 'widget_data_service.dart';

/// Convenience helper: updates SharedPreferences data and then tells the
/// native side to refresh all home screen widgets.
class WidgetRefresh {
  static const _channel = MethodChannel('com.life.orbit/intent');

  /// Call this after any data mutation that affects widget display.
  static Future<void> refresh() async {
    await WidgetDataService.updateAll();
    try {
      await _channel.invokeMethod('refreshWidgets');
    } catch (_) {
      // Channel may not be available in tests or background isolates.
    }
  }
}

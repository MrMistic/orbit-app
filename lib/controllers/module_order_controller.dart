import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/modules.dart';

/// Persists the user's module ordering. The first 3 ids appear in the bottom
/// nav (home tabs); the rest live under the More tab.
class ModuleOrderController extends GetxController {
  static const _kPrefsKey = 'module_order_v1';
  static const int homeCount = 3;

  /// Ordered list of module ids. Reactive: any [Obx] using
  /// [homeModules] / [moreModules] / [orderedModules] rebuilds on change.
  final RxList<String> _order = <String>[].obs;

  late final SharedPreferences _prefs;

  /// Modules that show up as bottom-nav tabs (first [homeCount]).
  List<AppModule> get homeModules => orderedModules.take(homeCount).toList();

  /// Modules that show up under the More tab.
  List<AppModule> get moreModules => orderedModules.skip(homeCount).toList();

  /// Full ordered list, with any unknown ids dropped and any new modules
  /// from the registry appended at the end (so newly-added features show up
  /// in More by default and don't displace the user's home tabs).
  List<AppModule> get orderedModules {
    final known = ModuleRegistry.all.map((m) => m.id).toSet();
    final result = <AppModule>[];
    final seen = <String>{};
    for (final id in _order) {
      if (!known.contains(id) || seen.contains(id)) continue;
      final mod = ModuleRegistry.byId(id);
      if (mod != null) {
        result.add(mod);
        seen.add(id);
      }
    }
    // Append any registry modules not yet in the saved order.
    for (final m in ModuleRegistry.all) {
      if (!seen.contains(m.id)) result.add(m);
    }
    return result;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getStringList(_kPrefsKey);
    if (saved != null && saved.isNotEmpty) {
      _order.assignAll(saved);
    } else {
      _order.assignAll(ModuleRegistry.defaultOrder);
    }
  }

  /// Replaces the entire ordering. Caller is responsible for passing a list
  /// of valid ids; the [orderedModules] getter sanitizes anyway.
  Future<void> setOrder(List<String> ids) async {
    _order.assignAll(ids);
    await _prefs.setStringList(_kPrefsKey, ids);
  }

  Future<void> resetToDefault() async {
    await setOrder(ModuleRegistry.defaultOrder);
  }
}

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/tabs/relationship/relationship_modules.dart';

/// Persists the user's order of relationship submodules.
class RelationshipOrderController extends GetxController {
  static const _kPrefsKey = 'relationship_submodule_order_v1';

  final RxList<String> _order = <String>[].obs;
  late final SharedPreferences _prefs;

  /// Submodules in user-specified order. Unknown ids are filtered out and any
  /// new submodules from the registry are appended at the end.
  List<RelationshipSubmodule> get submodules {
    final known = RelationshipRegistry.all.map((s) => s.id).toSet();
    final result = <RelationshipSubmodule>[];
    final seen = <String>{};
    for (final id in _order) {
      if (!known.contains(id) || seen.contains(id)) continue;
      final s = RelationshipRegistry.byId(id);
      if (s != null) {
        result.add(s);
        seen.add(id);
      }
    }
    for (final s in RelationshipRegistry.all) {
      if (!seen.contains(s.id)) result.add(s);
    }
    return result;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getStringList(_kPrefsKey);
    if (saved != null && saved.isNotEmpty) {
      _order.assignAll(saved);
    } else {
      _order.assignAll(RelationshipRegistry.defaultOrder);
    }
  }

  Future<void> setOrder(List<String> ids) async {
    _order.assignAll(ids);
    await _prefs.setStringList(_kPrefsKey, ids);
  }

  Future<void> resetToDefault() async {
    await setOrder(RelationshipRegistry.defaultOrder);
  }
}

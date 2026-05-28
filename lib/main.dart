import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/shell.dart';
import 'controllers/module_order_controller.dart';
import 'controllers/relationship_order_controller.dart';
import 'database/object_box.dart';
import 'services/notification_service.dart';
import 'services/unit_preference.dart';
import 'services/widget_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ObjectBox.create();
  await NotificationService.init();
  // Load module ordering before runApp so the shell renders with the correct
  // home tabs on first frame.
  final moduleOrder = Get.put(ModuleOrderController(), permanent: true);
  await moduleOrder.load();
  final relOrder = Get.put(RelationshipOrderController(), permanent: true);
  await relOrder.load();
  final units = Get.put(UnitPreference(), permanent: true);
  await units.load();
  // Populate widget data for home screen widgets.
  await WidgetDataService.updateAll();
  final savedMode = await AdaptiveTheme.getThemeMode();
  runApp(LifeApp(savedMode: savedMode ?? AdaptiveThemeMode.system));
}

class LifeApp extends StatelessWidget {
  const LifeApp({super.key, required this.savedMode});
  final AdaptiveThemeMode savedMode;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = lightDynamic ??
            ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
        final darkScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: Brightness.dark,
            );
        return AdaptiveTheme(
          light: ThemeData(useMaterial3: true, colorScheme: lightScheme),
          dark: ThemeData(useMaterial3: true, colorScheme: darkScheme),
          initial: savedMode,
          builder: (light, dark) => GetMaterialApp(
            title: 'Orbit',
            theme: light,
            darkTheme: dark,
            home: const AppShell(),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

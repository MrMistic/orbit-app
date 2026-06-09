import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/module_order_controller.dart';
import '../shell.dart';
import 'rearrange_modules_page.dart';
import 'search/global_search_page.dart';
import 'settings/backup_page.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ModuleOrderController>();

    return TabScaffold(
      title: 'More',
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => Get.to(() => const GlobalSearchPage()),
        ),
      ],
      child: Obx(() {
        final more = c.moreModules;
        return ListView(
          children: [
            // Modules pushed to "More" by the user.
            for (final mod in more)
              ListTile(
                leading: Icon(mod.icon),
                title: Text(mod.label),
                subtitle: Text(mod.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => mod.pageBuilder(context)),
              ),
            if (more.isNotEmpty) const Divider(),

            // Theme.
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(AdaptiveTheme.of(context).mode)),
              onTap: () => AdaptiveTheme.of(context).toggleThemeMode(),
            ),

            // Rearrange modules.
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Rearrange modules'),
              subtitle: const Text(
                  'Choose which modules show up on the home screen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => const RearrangeModulesPage()),
            ),

            // Backup & Restore.
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Backup & Restore'),
              subtitle: const Text('Export or import all your data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => const BackupPage()),
            ),

            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About'),
              subtitle: Text('Orbit — local-first life app. All data stays on this device.'),
            ),
          ],
        );
      }),
    );
  }

  String _themeLabel(AdaptiveThemeMode mode) {
    switch (mode) {
      case AdaptiveThemeMode.light:
        return 'Light';
      case AdaptiveThemeMode.dark:
        return 'Dark';
      case AdaptiveThemeMode.system:
        return 'System';
    }
  }
}

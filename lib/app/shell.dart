import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/module_order_controller.dart';
import 'modules.dart';
import 'tabs/more_tab.dart';
import 'tabs/relationship/important_dates/important_dates_page.dart';

/// Root navigation shell. Bottom nav has 4 slots: the user's first three
/// modules + the always-present More tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _intentHandled = false;

  static const _channel = MethodChannel('com.life.orbit/intent');

  @override
  void initState() {
    super.initState();
    _handleWidgetIntent();
    // Listen for route pushes when app is already running.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRoute' && call.arguments is String) {
        _navigateToModule(call.arguments as String);
      }
    });
  }

  Future<void> _handleWidgetIntent() async {
    // Small delay to let the widget tree settle before navigating.
    await Future.delayed(const Duration(milliseconds: 500));
    if (_intentHandled) return;
    _intentHandled = true;

    try {
      final route = await _channel.invokeMethod<String>('getRoute');
      if (route != null && route.isNotEmpty && mounted) {
        _navigateToModule(route);
      }
    } catch (_) {
      // Channel not set up or no intent — ignore.
    }
  }

  void _navigateToModule(String moduleId) {
    final c = Get.find<ModuleOrderController>();
    final home = c.homeModules;

    // Check if the module is in the home tabs.
    for (var i = 0; i < home.length; i++) {
      if (home[i].id == moduleId) {
        setState(() => _index = i);
        return;
      }
    }

    // Otherwise, find it in the full registry and push its page.
    final mod = ModuleRegistry.byId(moduleId);
    if (mod != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: mod.pageBuilder),
      );
      return;
    }

    // Handle submodule routes (e.g. "important_dates" lives inside relationship).
    if (moduleId == 'important_dates') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ImportantDatesPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ModuleOrderController>();
    return Obx(() {
      final home = c.homeModules;
      // Clamp index in case the user reordered and the previous index is now invalid.
      final maxIndex = home.length; // last slot is the More tab at index `home.length`
      final safeIndex = _index > maxIndex ? 0 : _index;

      final tabs = <Widget>[
        ...home.map((m) => m.pageBuilder(context)),
        const MoreTab(),
      ];

      final destinations = <NavigationDestination>[
        ...home.map(
          (m) => NavigationDestination(
            icon: Icon(m.icon),
            selectedIcon: Icon(m.selectedIcon),
            label: m.label,
          ),
        ),
        const NavigationDestination(
          icon: Icon(Icons.apps_outlined),
          selectedIcon: Icon(Icons.apps),
          label: 'More',
        ),
      ];

      return Scaffold(
        body: SafeArea(child: tabs[safeIndex]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: destinations,
        ),
      );
    });
  }
}

/// Shared scaffold for tabs that just need a title + body.
class TabScaffold extends StatelessWidget {
  const TabScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Placeholder for tabs that aren't built out yet.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.feature, this.note});

  final String feature;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(feature, style: theme.textTheme.headlineSmall),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

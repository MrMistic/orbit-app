import 'package:flutter/material.dart';

import 'tabs/bucket_list/bucket_list_page.dart';
import 'tabs/contacts/contacts_page.dart';
import 'tabs/finance/finance_tab.dart';
import 'tabs/fitness/fitness_tab.dart';
import 'tabs/maintenance/maintenance_page.dart';
import 'tabs/media/media_list_page.dart';
import 'tabs/projects/projects_page.dart';
import 'tabs/recipes/recipe_list_page.dart';
import 'tabs/relationship_tab.dart';
import 'tabs/shopping/shopping_list_page.dart';
import 'tabs/skills/skills_page.dart';
import 'tabs/sleep/sleep_page.dart';
import 'tabs/todos_tab.dart';

/// A primary feature module. Each module can either live as one of the three
/// home-screen tabs (bottom nav) or as a row in the More tab.
class AppModule {
  const AppModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.subtitle,
    required this.pageBuilder,
  });

  /// Stable identifier, used for persistence. Never change once shipped.
  final String id;

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// One-line description shown in More and the rearrange screen.
  final String subtitle;

  /// Builds the page widget for this module.
  final WidgetBuilder pageBuilder;
}

/// All modules the user can rearrange. Adding a new module is a matter of
/// appending to this list — order here is just the default for first launch.
class ModuleRegistry {
  static final List<AppModule> all = [
    AppModule(
      id: 'todos',
      label: 'Todos',
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
      subtitle: 'Tasks and reminders',
      pageBuilder: (_) => const TodosTab(),
    ),
    AppModule(
      id: 'recipes',
      label: 'Recipes',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
      subtitle: 'Meal-prep recipe book',
      pageBuilder: (_) => const RecipeListPage(),
    ),
    AppModule(
      id: 'relationship',
      label: 'Relationship',
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite,
      subtitle: 'Cycle tracker, mood, and metrics',
      pageBuilder: (_) => const RelationshipTab(),
    ),
    AppModule(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      subtitle: 'Build a list from your recipes',
      pageBuilder: (_) => const ShoppingListPage(),
    ),
    AppModule(
      id: 'fitness',
      label: 'Fitness',
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
      subtitle: 'Workouts, goals, and programming',
      pageBuilder: (_) => const FitnessTab(),
    ),
    AppModule(
      id: 'finance',
      label: 'Finance',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      subtitle: 'Subscriptions, savings, arbitrage',
      pageBuilder: (_) => const FinanceTab(),
    ),
    AppModule(
      id: 'media',
      label: 'Media',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      subtitle: 'Books, movies, shows, podcasts, games',
      pageBuilder: (_) => const MediaListPage(),
    ),
    AppModule(
      id: 'contacts',
      label: 'Contacts',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      subtitle: 'Personal CRM — stay in touch',
      pageBuilder: (_) => const ContactsPage(),
    ),
    AppModule(
      id: 'skills',
      label: 'Skills',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      subtitle: 'Track learning and practice hours',
      pageBuilder: (_) => const SkillsPage(),
    ),
    AppModule(
      id: 'projects',
      label: 'Projects',
      icon: Icons.rocket_launch_outlined,
      selectedIcon: Icons.rocket_launch,
      subtitle: 'Personal projects with task lists',
      pageBuilder: (_) => const ProjectsPage(),
    ),
    AppModule(
      id: 'maintenance',
      label: 'Maintenance',
      icon: Icons.build_outlined,
      selectedIcon: Icons.build,
      subtitle: 'Car, home, and appliance upkeep',
      pageBuilder: (_) => const MaintenancePage(),
    ),
    AppModule(
      id: 'sleep',
      label: 'Sleep',
      icon: Icons.bedtime_outlined,
      selectedIcon: Icons.bedtime,
      subtitle: 'Track sleep and quality',
      pageBuilder: (_) => const SleepPage(),
    ),
    AppModule(
      id: 'bucket_list',
      label: 'Bucket list',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      subtitle: 'Life goals big and small',
      pageBuilder: (_) => const BucketListPage(),
    ),
  ];

  /// Default ordering: same as declared above.
  static List<String> get defaultOrder => all.map((m) => m.id).toList();

  static AppModule? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}

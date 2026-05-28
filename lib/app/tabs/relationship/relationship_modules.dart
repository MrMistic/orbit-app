import 'package:flutter/material.dart';

import 'cycle/cycle_tracker_page.dart';
import 'cycle_reminders/cycle_reminders_page.dart';
import 'date_ideas/date_ideas_page.dart';
import 'gifts/gift_log_page.dart';
import 'important_dates/important_dates_page.dart';
import 'love_language/love_language_page.dart';
import 'preferences/preferences_page.dart';
import 'prompts/conversation_prompts_page.dart';
import 'trips/trip_list_page.dart';

/// A relationship submodule — surfaced as a row on the relationship hub.
class RelationshipSubmodule {
  const RelationshipSubmodule({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.pageBuilder,
  });

  /// Stable id used for persistence. Never change once shipped.
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder pageBuilder;
}

/// All relationship submodules. Adding a new one is a matter of appending here
/// (and creating its page widget). Order is the default for first launch.
class RelationshipRegistry {
  static final List<RelationshipSubmodule> all = [
    RelationshipSubmodule(
      id: 'cycle',
      label: 'Cycle tracker',
      subtitle: 'Period log with predictions',
      icon: Icons.calendar_month_outlined,
      pageBuilder: (_) => const CycleTrackerPage(),
    ),
    RelationshipSubmodule(
      id: 'date_ideas',
      label: 'Date ideas',
      subtitle: 'Things to try together',
      icon: Icons.lightbulb_outline,
      pageBuilder: (_) => const DateIdeasPage(),
    ),
    RelationshipSubmodule(
      id: 'gifts',
      label: 'Gifts',
      subtitle: 'Gift ideas and history',
      icon: Icons.card_giftcard_outlined,
      pageBuilder: (_) => const GiftLogPage(),
    ),
    RelationshipSubmodule(
      id: 'important_dates',
      label: 'Important dates',
      subtitle: 'Anniversaries and milestones',
      icon: Icons.event_outlined,
      pageBuilder: (_) => const ImportantDatesPage(),
    ),
    RelationshipSubmodule(
      id: 'trips',
      label: 'Trip planner',
      subtitle: 'Places to go together',
      icon: Icons.flight_takeoff_outlined,
      pageBuilder: (_) => const TripListPage(),
    ),
    RelationshipSubmodule(
      id: 'conversation_prompts',
      label: 'Conversation prompts',
      subtitle: 'Questions to ask each other',
      icon: Icons.chat_bubble_outline,
      pageBuilder: (_) => const ConversationPromptsPage(),
    ),
    RelationshipSubmodule(
      id: 'preferences',
      label: 'Preferences journal',
      subtitle: 'Likes, dislikes, sizes, allergies',
      icon: Icons.bookmark_outline,
      pageBuilder: (_) => const PreferencesPage(),
    ),
    RelationshipSubmodule(
      id: 'cycle_reminders',
      label: 'Cycle-aware reminders',
      subtitle: 'Gentle nudges based on cycle phase',
      icon: Icons.notifications_outlined,
      pageBuilder: (_) => const CycleRemindersPage(),
    ),
    RelationshipSubmodule(
      id: 'love_languages',
      label: 'Love languages',
      subtitle: 'Periodic reminders to show love',
      icon: Icons.favorite_border,
      pageBuilder: (_) => const LoveLanguagePage(),
    ),
  ];

  static List<String> get defaultOrder => all.map((s) => s.id).toList();

  static RelationshipSubmodule? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}

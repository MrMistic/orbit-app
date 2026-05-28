import 'package:objectbox/objectbox.dart';

/// A credit card with cashback / rewards categories.
@Entity()
class RewardsCard {
  @Id()
  int id;

  String name;
  String? notes;

  /// Newline-separated lines of "category|percent" pairs.
  /// e.g. "Groceries|5\nGas|3\nDining|2\nEverything else|1"
  String categoriesRaw;

  /// Optional active quarterly category for rotating-reward cards (Discover/Chase Freedom).
  String? activeRotatingCategory;

  /// Annual fee in dollars. 0 = no fee.
  double annualFee;

  /// APR (annual percentage rate) as a percentage. Used for payoff math.
  double? apr;

  /// True if this is the user's "default" / baseline no-fee card. Only one
  /// card should be flagged as default; the worth-it analyzer compares
  /// other cards against this one.
  bool isDefault;

  bool active;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  RewardsCard({
    this.id = 0,
    required this.name,
    this.notes,
    this.categoriesRaw = '',
    this.activeRotatingCategory,
    this.annualFee = 0,
    this.apr,
    this.isDefault = false,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Parsed categories as a list of (category, percent).
  List<(String, double)> get categories {
    final result = <(String, double)>[];
    for (final line in categoriesRaw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('|');
      if (parts.length != 2) continue;
      final pct = double.tryParse(parts[1].trim());
      if (pct == null) continue;
      result.add((parts[0].trim(), pct));
    }
    return result;
  }

  /// Find the cashback percent for a given category. Falls back to "Everything else"
  /// if no match. Returns 0 if no fallback exists.
  double percentForCategory(String category) {
    final query = category.toLowerCase();
    double? matched;
    double? fallback;
    for (final (cat, pct) in categories) {
      final catLower = cat.toLowerCase();
      if (catLower.contains(query) || query.contains(catLower)) {
        if (matched == null || pct > matched) matched = pct;
      }
      if (catLower.contains('else') ||
          catLower.contains('other') ||
          catLower.contains('all') ||
          catLower == 'default') {
        if (fallback == null || pct > fallback) fallback = pct;
      }
    }
    return matched ?? fallback ?? 0;
  }
}

/// User's monthly spending profile by category. There is exactly one row per
/// category — the row is upserted by category name.
@Entity()
class SpendingProfileEntry {
  @Id()
  int id;

  String category;
  double monthlySpend;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  SpendingProfileEntry({
    this.id = 0,
    required this.category,
    required this.monthlySpend,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

/// A logged bet for the bankroll tracker.
@Entity()
class BetRecord {
  @Id()
  int id;

  String description;
  String? sport;
  String? sportsbook;

  double stake;

  /// Decimal odds (e.g. 1.91 for -110).
  double decimalOdds;

  /// "open", "won", "lost", "push", "void".
  String status;

  @Property(type: PropertyType.date)
  DateTime placedAt;

  @Property(type: PropertyType.date)
  DateTime? settledAt;

  String? notes;

  BetRecord({
    this.id = 0,
    required this.description,
    this.sport,
    this.sportsbook,
    required this.stake,
    required this.decimalOdds,
    this.status = 'open',
    DateTime? placedAt,
    this.settledAt,
    this.notes,
  }) : placedAt = placedAt ?? DateTime.now();

  /// Potential payout if the bet wins (stake × odds).
  double get potentialPayout => stake * decimalOdds;

  /// Potential profit if the bet wins (stake × (odds - 1)).
  double get potentialProfit => stake * (decimalOdds - 1);

  /// Net result based on status. Open bets return 0.
  double get result {
    switch (status) {
      case 'won':
        return potentialProfit;
      case 'lost':
        return -stake;
      case 'push':
      case 'void':
        return 0;
      default:
        return 0;
    }
  }
}

/// A recurring subscription or bill (Netflix, Spotify, gym, electric bill, etc.)
@Entity()
class Subscription {
  @Id()
  int id;

  String name;
  double amount;

  /// "monthly", "yearly", "weekly", "quarterly".
  String billingCycle;

  /// "subscription" or "bill". Bills tend to be utilities, rent, insurance.
  String kind;

  /// Optional category (Entertainment, Software, Fitness, Utilities, etc.)
  String? category;

  String? notes;

  /// The date of the next renewal/charge.
  @Property(type: PropertyType.date)
  DateTime? nextRenewal;

  bool active;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  Subscription({
    this.id = 0,
    required this.name,
    required this.amount,
    this.billingCycle = 'monthly',
    this.kind = 'subscription',
    this.category,
    this.notes,
    this.nextRenewal,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Cost normalized to monthly for total burn calculations.
  double get monthlyCost {
    switch (billingCycle) {
      case 'weekly':
        return amount * 4.345; // avg weeks per month
      case 'monthly':
        return amount;
      case 'quarterly':
        return amount / 3;
      case 'yearly':
        return amount / 12;
      default:
        return amount;
    }
  }

  /// Days until next renewal (negative = overdue).
  int? get daysUntilRenewal {
    if (nextRenewal == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final due = DateTime(nextRenewal!.year, nextRenewal!.month, nextRenewal!.day);
    return due.difference(today).inDays;
  }
}

/// A savings goal or wishlist item.
@Entity()
class SavingsGoal {
  @Id()
  int id;

  String name;
  String? notes;

  /// Target amount.
  double targetAmount;

  /// Currently saved amount.
  double savedAmount;

  /// Optional URL for wishlist items linking to a product page.
  String? linkUrl;

  /// "savings" or "wishlist". Wishlist items don't necessarily track progress.
  String type;

  /// Optional category for organization.
  String? category;

  @Property(type: PropertyType.date)
  DateTime? targetDate;

  bool achieved;

  @Property(type: PropertyType.date)
  DateTime? achievedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  SavingsGoal({
    this.id = 0,
    required this.name,
    this.notes,
    required this.targetAmount,
    this.savedAmount = 0,
    this.linkUrl,
    this.type = 'savings',
    this.category,
    this.targetDate,
    this.achieved = false,
    this.achievedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 0.0-1.0 progress.
  double get progress {
    if (targetAmount <= 0) return 0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0);
  }

  /// Days until target date (negative = overdue).
  int? get daysUntilTarget {
    if (targetDate == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final target = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return target.difference(today).inDays;
  }
}

/// A single todo item.
@Entity()
class Todo {
  @Id()
  int id;

  String title;
  String? notes;
  bool done;

  @Property(type: PropertyType.date)
  DateTime? dueDate;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? completedAt;

  Todo({
    this.id = 0,
    required this.title,
    this.notes,
    this.done = false,
    this.dueDate,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A single ingredient line for a recipe.
@Entity()
class Ingredient {
  @Id()
  int id;

  /// Quantity. Stored as a double to allow fractional amounts (e.g. 1.5 cups).
  /// Null means "no specific quantity" (e.g. "salt to taste").
  double? quantity;

  /// Free-form unit ("cup", "tbsp", "g", "oz"). Null = unitless ("2 eggs").
  String? unit;

  /// The ingredient name itself ("flour", "olive oil").
  String name;

  /// Optional preparation note ("diced", "room temperature").
  String? note;

  /// Stable ordering within a recipe. Lower comes first.
  int order;

  Ingredient({
    this.id = 0,
    this.quantity,
    this.unit,
    required this.name,
    this.note,
    this.order = 0,
  });

  /// Pretty form for display: "1.5 cups flour, sifted".
  String get display {
    final parts = <String>[];
    if (quantity != null) parts.add(_formatQty(quantity!));
    if (unit != null && unit!.isNotEmpty) parts.add(unit!);
    parts.add(name);
    final base = parts.join(' ');
    if (note != null && note!.isNotEmpty) return '$base, $note';
    return base;
  }

  static String _formatQty(double q) {
    if (q == q.truncateToDouble()) return q.toInt().toString();
    return q.toString();
  }
}

/// A recipe in the meal-prep book.
@Entity()
class Recipe {
  @Id()
  int id;

  String name;
  String? description;

  /// LEGACY: pre-migration newline-separated ingredient string. Kept for
  /// backwards data compatibility; new recipes use [ingredientList].
  /// Migrated to [ingredientList] on first access in [RecipeController].
  String ingredients;

  /// Newline-separated steps.
  String steps;

  int servings;

  /// Minutes.
  int? prepTimeMinutes;
  int? cookTimeMinutes;

  bool favorite;

  /// Absolute path to a photo file in app-private storage. Null means no photo.
  String? photoPath;

  /// Comma-separated tag list. Simple storage; surfaces as [tagList] getter.
  String tagsRaw;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// Structured ingredient list. Use this in new code.
  final ingredientList = ToMany<Ingredient>();

  Recipe({
    this.id = 0,
    required this.name,
    this.description,
    this.ingredients = '',
    this.steps = '',
    this.servings = 1,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.favorite = false,
    this.photoPath,
    this.tagsRaw = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  List<String> get tagList => tagsRaw
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  set tagList(List<String> tags) {
    tagsRaw = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .join(',');
  }
}

/// Cycle / period log entry.
@Entity()
class CycleEntry {
  @Id()
  int id;

  @Property(type: PropertyType.date)
  DateTime date;

  /// 0 = none, 1 = light, 2 = medium, 3 = heavy.
  int flow;

  /// Free-form note (mood, observations, etc.).
  String? note;

  /// Comma-separated symptoms (cramps, headache, bloating, mood-swings, etc.).
  String symptomsRaw;

  CycleEntry({
    this.id = 0,
    required this.date,
    this.flow = 0,
    this.note,
    this.symptomsRaw = '',
  });

  List<String> get symptoms => symptomsRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  set symptoms(List<String> list) {
    symptomsRaw = list
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .join(',');
  }
}

/// Generic daily-data tracker entry. Use this for weight, water, sleep,
/// or any other numeric metric.
@Entity()
class DataPoint {
  @Id()
  int id;

  /// Metric name e.g. "weight", "sleep_hours", "water_oz".
  String metric;

  double value;
  String? unit;

  @Property(type: PropertyType.date)
  DateTime recordedAt;

  String? note;

  DataPoint({
    this.id = 0,
    required this.metric,
    required this.value,
    this.unit,
    DateTime? recordedAt,
    this.note,
  }) : recordedAt = recordedAt ?? DateTime.now();
}

/// An important date / anniversary for the relationship module.
@Entity()
class ImportantDate {
  @Id()
  int id;

  String title;
  String? notes;

  /// The actual date of the event.
  @Property(type: PropertyType.date)
  DateTime date;

  /// Whether this recurs annually (true = anniversary/birthday, false = one-time milestone).
  bool recurring;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  ImportantDate({
    this.id = 0,
    required this.title,
    this.notes,
    required this.date,
    this.recurring = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Next occurrence of this date. For recurring dates, finds the next
  /// anniversary (this year or next). For one-time dates, returns the date itself.
  DateTime get nextOccurrence {
    if (!recurring) return date;
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next;
  }

  /// Days until next occurrence. Negative means it was today or in the past (for non-recurring).
  int get daysUntil {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final target = DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);
    return target.difference(today).inDays;
  }

  /// For milestones: how long ago this happened.
  int get daysSince {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final d = DateTime(date.year, date.month, date.day);
    return today.difference(d).inDays;
  }

  /// Years since the original date (useful for "3rd anniversary").
  int get yearsSince {
    final now = DateTime.now();
    return now.year - date.year;
  }
}

/// A media item (book, movie, show, podcast, game, article) for the reading/media list.
@Entity()
class MediaItem {
  @Id()
  int id;

  String title;
  String? author;

  /// "book", "movie", "show", "podcast", "game", "article".
  String mediaType;

  /// "want", "in_progress", "finished".
  String status;

  /// 1-5 rating after finishing.
  int? rating;

  String? notes;

  @Property(type: PropertyType.date)
  DateTime? startedAt;

  @Property(type: PropertyType.date)
  DateTime? finishedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  MediaItem({
    this.id = 0,
    required this.title,
    this.author,
    this.mediaType = 'book',
    this.status = 'want',
    this.rating,
    this.notes,
    this.startedAt,
    this.finishedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A contact in the personal CRM.
@Entity()
class CrmContact {
  @Id()
  int id;

  String name;
  String? relationship;
  String? notes;
  String? phone;
  String? email;

  /// How often to reach out (days). Null = no reminder.
  int? reachOutDays;

  @Property(type: PropertyType.date)
  DateTime? lastContactedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  CrmContact({
    this.id = 0,
    required this.name,
    this.relationship,
    this.notes,
    this.phone,
    this.email,
    this.reachOutDays,
    this.lastContactedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Days since last contact. Null if never contacted.
  int? get daysSinceContact {
    if (lastContactedAt == null) return null;
    return DateTime.now().difference(lastContactedAt!).inDays;
  }

  /// Whether this contact is overdue for a reach-out.
  bool get isOverdue {
    if (reachOutDays == null || lastContactedAt == null) return false;
    return daysSinceContact! >= reachOutDays!;
  }
}

/// A skill being tracked/learned.
@Entity()
class Skill {
  @Id()
  int id;

  String name;
  String? category;
  String? notes;

  /// Total minutes practiced (accumulated from sessions).
  int totalMinutes;

  @Property(type: PropertyType.date)
  DateTime? lastPracticedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  Skill({
    this.id = 0,
    required this.name,
    this.category,
    this.notes,
    this.totalMinutes = 0,
    this.lastPracticedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalHours => totalMinutes / 60.0;
}

/// A practice session for a skill.
@Entity()
class PracticeSession {
  @Id()
  int id;

  String skillName;
  int durationMinutes;
  String? notes;

  @Property(type: PropertyType.date)
  DateTime date;

  PracticeSession({
    this.id = 0,
    required this.skillName,
    required this.durationMinutes,
    this.notes,
    DateTime? date,
  }) : date = date ?? DateTime.now();
}

/// A personal project.
@Entity()
class Project {
  @Id()
  int id;

  String name;
  String? description;

  /// "active", "paused", "completed", "abandoned".
  String status;

  /// Newline-separated task list. Items prefixed with "[x] " are done.
  String tasks;

  @Property(type: PropertyType.date)
  DateTime? deadline;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  Project({
    this.id = 0,
    required this.name,
    this.description,
    this.status = 'active',
    this.tasks = '',
    this.deadline,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A maintenance item (car, home, appliance).
@Entity()
class MaintenanceItem {
  @Id()
  int id;

  String title;
  String? category;
  String? notes;

  /// Recurrence in days. Null = one-time.
  int? intervalDays;

  @Property(type: PropertyType.date)
  DateTime? lastDoneAt;

  @Property(type: PropertyType.date)
  DateTime? nextDueAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  MaintenanceItem({
    this.id = 0,
    required this.title,
    this.category,
    this.notes,
    this.intervalDays,
    this.lastDoneAt,
    this.nextDueAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOverdue =>
      nextDueAt != null && nextDueAt!.isBefore(DateTime.now());

  int? get daysUntilDue {
    if (nextDueAt == null) return null;
    return nextDueAt!.difference(DateTime.now()).inDays;
  }
}

/// A sleep log entry.
@Entity()
class SleepEntry {
  @Id()
  int id;

  @Property(type: PropertyType.date)
  DateTime bedtime;

  @Property(type: PropertyType.date)
  DateTime wakeTime;

  /// 1-5 quality rating.
  int? quality;

  String? notes;

  SleepEntry({
    this.id = 0,
    required this.bedtime,
    required this.wakeTime,
    this.quality,
    this.notes,
  });

  double get hoursSlept =>
      wakeTime.difference(bedtime).inMinutes / 60.0;
}

/// A bucket list item.
@Entity()
class BucketListItem {
  @Id()
  int id;

  String title;
  String? notes;
  String? category;
  bool done;

  @Property(type: PropertyType.date)
  DateTime? completedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  BucketListItem({
    this.id = 0,
    required this.title,
    this.notes,
    this.category,
    this.done = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A fitness workout session.
@Entity()
class Workout {
  @Id()
  int id;

  @Property(type: PropertyType.date)
  DateTime date;

  /// Total duration in minutes.
  int? durationMinutes;

  String? notes;

  /// "strength", "cardio", "flexibility", "plyometric", "mixed".
  String type;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  final sets = ToMany<ExerciseSet>();

  Workout({
    this.id = 0,
    required this.date,
    this.durationMinutes,
    this.notes,
    this.type = 'strength',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A single set within a workout.
@Entity()
class ExerciseSet {
  @Id()
  int id;

  /// Exercise name (e.g. "Bench Press", "Running", "Box Jump").
  String exerciseName;

  /// "strength", "cardio", "plyometric", "flexibility".
  String category;

  /// Strength: weight lifted.
  double? weight;

  /// Strength/plyo: number of reps.
  int? reps;

  /// Cardio: duration in minutes.
  double? durationMinutes;

  /// Cardio: distance in km.
  double? distanceKm;

  /// Order within the workout.
  int order;

  ExerciseSet({
    this.id = 0,
    required this.exerciseName,
    this.category = 'strength',
    this.weight,
    this.reps,
    this.durationMinutes,
    this.distanceKm,
    this.order = 0,
  });
}

/// A fitness goal.
@Entity()
class FitnessGoal {
  @Id()
  int id;

  /// "strength", "weight_loss", "weight_gain", "cardio", "plyometric".
  String goalType;

  /// Human-readable title (e.g. "Bench 225 lbs", "Lose 10 lbs").
  String title;

  /// The exercise this goal targets (for strength/cardio goals).
  String? exerciseName;

  /// Target value (e.g. target 1RM weight, target body weight, target 5K time).
  double? targetValue;

  /// Current baseline value at goal creation.
  double? baselineValue;

  /// Unit for display ("lbs", "kg", "min", "km").
  String? unit;

  @Property(type: PropertyType.date)
  DateTime? deadline;

  bool completed;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  FitnessGoal({
    this.id = 0,
    required this.goalType,
    required this.title,
    this.exerciseName,
    this.targetValue,
    this.baselineValue,
    this.unit,
    this.deadline,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// User body metrics for TDEE calculation and weight tracking.
@Entity()
class BodyMetric {
  @Id()
  int id;

  /// "weight", "height", "age", "activity_level", "sex".
  String metric;

  double value;

  @Property(type: PropertyType.date)
  DateTime recordedAt;

  BodyMetric({
    this.id = 0,
    required this.metric,
    required this.value,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();
}

/// A love-language reminder configuration.
@Entity()
class LoveLanguageReminder {
  @Id()
  int id;

  /// One of: words, acts, gifts, quality_time, touch.
  String language;

  /// The specific action/suggestion text.
  String action;

  /// Frequency in days between reminders (1 = daily, 3 = every 3 days, 7 = weekly).
  int frequencyDays;

  bool enabled;

  /// Last time this specific action was surfaced.
  @Property(type: PropertyType.date)
  DateTime? lastShownAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  LoveLanguageReminder({
    this.id = 0,
    required this.language,
    required this.action,
    this.frequencyDays = 3,
    this.enabled = true,
    this.lastShownAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A cycle-aware reminder configuration.
@Entity()
class CycleReminder {
  @Id()
  int id;

  /// Human-readable title shown in the notification.
  String title;

  /// Body text for the notification.
  String message;

  /// Trigger type: "before_period", "period_start", "fertile_start", "ovulation".
  String triggerType;

  /// Days offset from the trigger event. Negative = before, positive = after.
  /// e.g. triggerType="before_period", daysBefore=2 means 2 days before predicted period.
  int daysBefore;

  bool enabled;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  CycleReminder({
    this.id = 0,
    required this.title,
    required this.message,
    this.triggerType = 'before_period',
    this.daysBefore = 2,
    this.enabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A preference entry for the relationship preferences journal.
@Entity()
class PreferenceEntry {
  @Id()
  int id;

  /// Category grouping (e.g. "Sizes", "Food", "Favorites", "Dislikes").
  String category;

  /// The preference key (e.g. "Shirt size", "Favorite flower").
  String label;

  /// The value (e.g. "Medium", "Sunflowers").
  String value;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  PreferenceEntry({
    this.id = 0,
    required this.category,
    required this.label,
    required this.value,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A conversation prompt for the relationship module.
@Entity()
class ConversationPrompt {
  @Id()
  int id;

  String question;
  String category;
  bool asked;

  /// True = user-created. False = from the built-in bank (stored on first ask).
  bool userCreated;

  @Property(type: PropertyType.date)
  DateTime? askedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  ConversationPrompt({
    this.id = 0,
    required this.question,
    this.category = '',
    this.asked = false,
    this.userCreated = true,
    this.askedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A trip in the relationship trip planner.
@Entity()
class Trip {
  @Id()
  int id;

  String destination;
  String? notes;

  /// Optional start/end dates for the trip.
  @Property(type: PropertyType.date)
  DateTime? startDate;

  @Property(type: PropertyType.date)
  DateTime? endDate;

  /// Newline-separated packing list. Items prefixed with "[x] " are checked.
  String packingList;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  Trip({
    this.id = 0,
    required this.destination,
    this.notes,
    this.startDate,
    this.endDate,
    this.packingList = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A gift idea or record for the relationship module.
@Entity()
class GiftEntry {
  @Id()
  int id;

  String title;
  String? notes;

  /// "idea" or "given" — tracks whether this is a future idea or past gift.
  String status;

  /// Optional occasion (birthday, anniversary, christmas, just-because, etc.).
  String? occasion;

  /// Optional price/budget.
  double? price;

  @Property(type: PropertyType.date)
  DateTime? givenAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  GiftEntry({
    this.id = 0,
    required this.title,
    this.notes,
    this.status = 'idea',
    this.occasion,
    this.price,
    this.givenAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A date idea for the relationship module.
@Entity()
class DateIdea {
  @Id()
  int id;

  String title;
  String? notes;

  /// Free-form category (e.g. "restaurant", "activity", "trip", "at-home").
  String category;

  /// Whether this idea has been done.
  bool done;

  @Property(type: PropertyType.date)
  DateTime? completedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  DateIdea({
    this.id = 0,
    required this.title,
    this.notes,
    this.category = '',
    this.done = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A persistent shopping list. There is exactly one of these (singleton);
/// items get added by selecting recipes.
@Entity()
class ShoppingItem {
  @Id()
  int id;

  String name;
  double? quantity;
  String? unit;

  /// Optional source recipe name, for context.
  String? sourceRecipe;

  bool checked;

  @Property(type: PropertyType.date)
  DateTime addedAt;

  ShoppingItem({
    this.id = 0,
    required this.name,
    this.quantity,
    this.unit,
    this.sourceRecipe,
    this.checked = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
}

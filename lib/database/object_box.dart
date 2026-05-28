import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import '../objectbox.g.dart';

/// Singleton wrapper around the ObjectBox [Store]. Initialize once at startup
/// via [ObjectBox.create] and access [instance] thereafter.
class ObjectBox {
  ObjectBox._(this.store)
      : todoBox = store.box<Todo>(),
        recipeBox = store.box<Recipe>(),
        ingredientBox = store.box<Ingredient>(),
        cycleBox = store.box<CycleEntry>(),
        dataPointBox = store.box<DataPoint>(),
        dateIdeaBox = store.box<DateIdea>(),
        giftBox = store.box<GiftEntry>(),
        importantDateBox = store.box<ImportantDate>(),
        loveLanguageBox = store.box<LoveLanguageReminder>(),
        cycleReminderBox = store.box<CycleReminder>(),
        preferenceBox = store.box<PreferenceEntry>(),
        conversationPromptBox = store.box<ConversationPrompt>(),
        tripBox = store.box<Trip>(),
        workoutBox = store.box<Workout>(),
        exerciseSetBox = store.box<ExerciseSet>(),
        fitnessGoalBox = store.box<FitnessGoal>(),
        bodyMetricBox = store.box<BodyMetric>(),
        mediaBox = store.box<MediaItem>(),
        crmContactBox = store.box<CrmContact>(),
        skillBox = store.box<Skill>(),
        practiceSessionBox = store.box<PracticeSession>(),
        projectBox = store.box<Project>(),
        maintenanceBox = store.box<MaintenanceItem>(),
        sleepBox = store.box<SleepEntry>(),
        bucketListBox = store.box<BucketListItem>(),
        subscriptionBox = store.box<Subscription>(),
        savingsGoalBox = store.box<SavingsGoal>(),
        rewardsCardBox = store.box<RewardsCard>(),
        spendingProfileBox = store.box<SpendingProfileEntry>(),
        betRecordBox = store.box<BetRecord>(),
        shoppingBox = store.box<ShoppingItem>();

  static ObjectBox? _instance;
  static ObjectBox get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('ObjectBox not initialized. Call ObjectBox.create() first.');
    }
    return i;
  }

  final Store store;
  final Box<Todo> todoBox;
  final Box<Recipe> recipeBox;
  final Box<Ingredient> ingredientBox;
  final Box<CycleEntry> cycleBox;
  final Box<DataPoint> dataPointBox;
  final Box<DateIdea> dateIdeaBox;
  final Box<GiftEntry> giftBox;
  final Box<ImportantDate> importantDateBox;
  final Box<LoveLanguageReminder> loveLanguageBox;
  final Box<CycleReminder> cycleReminderBox;
  final Box<PreferenceEntry> preferenceBox;
  final Box<ConversationPrompt> conversationPromptBox;
  final Box<Trip> tripBox;
  final Box<Workout> workoutBox;
  final Box<ExerciseSet> exerciseSetBox;
  final Box<FitnessGoal> fitnessGoalBox;
  final Box<BodyMetric> bodyMetricBox;
  final Box<MediaItem> mediaBox;
  final Box<CrmContact> crmContactBox;
  final Box<Skill> skillBox;
  final Box<PracticeSession> practiceSessionBox;
  final Box<Project> projectBox;
  final Box<MaintenanceItem> maintenanceBox;
  final Box<SleepEntry> sleepBox;
  final Box<BucketListItem> bucketListBox;
  final Box<Subscription> subscriptionBox;
  final Box<SavingsGoal> savingsGoalBox;
  final Box<RewardsCard> rewardsCardBox;
  final Box<SpendingProfileEntry> spendingProfileBox;
  final Box<BetRecord> betRecordBox;
  final Box<ShoppingItem> shoppingBox;

  static Future<ObjectBox> create() async {
    if (_instance != null) return _instance!;
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: p.join(docsDir.path, 'life_app_db'));
    _instance = ObjectBox._(store);
    return _instance!;
  }

  void close() {
    store.close();
    _instance = null;
  }
}

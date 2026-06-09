import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../database/models.dart';
import '../database/object_box.dart';

/// Exports all ObjectBox data to a JSON file and imports it back.
///
/// Backups are stored in the app's external storage directory (survives
/// uninstall on most devices) rather than internal documents.
class BackupService {
  /// Gets the backup directory. Uses external storage if available,
  /// falls back to app documents directory.
  static Future<Directory> _backupDir() async {
    // getExternalStorageDirectory() returns app-specific external storage
    // e.g. /storage/emulated/0/Android/data/com.life.orbit/files
    // This survives app updates but NOT uninstalls on Android 11+.
    // For true uninstall-safe storage we'd need MANAGE_EXTERNAL_STORAGE or SAF.
    // As a compromise, we also check the Downloads folder.
    final ext = await getExternalStorageDirectory();
    if (ext != null) return ext;
    return await getApplicationDocumentsDirectory();
  }
  /// Creates a backup JSON file in the app's documents directory.
  /// Returns the file path.
  static Future<String> export() async {
    final data = <String, dynamic>{};
    final ob = ObjectBox.instance;

    data['todos'] = ob.todoBox.getAll().map(_todoToJson).toList();
    data['recipes'] = ob.recipeBox.getAll().map(_recipeToJson).toList();
    data['ingredients'] = ob.ingredientBox.getAll().map(_ingredientToJson).toList();
    data['cycleEntries'] = ob.cycleBox.getAll().map(_cycleEntryToJson).toList();
    data['dataPoints'] = ob.dataPointBox.getAll().map(_dataPointToJson).toList();
    data['dateIdeas'] = ob.dateIdeaBox.getAll().map(_dateIdeaToJson).toList();
    data['gifts'] = ob.giftBox.getAll().map(_giftToJson).toList();
    data['importantDates'] = ob.importantDateBox.getAll().map(_importantDateToJson).toList();
    data['loveLanguageReminders'] = ob.loveLanguageBox.getAll().map(_loveLanguageToJson).toList();
    data['cycleReminders'] = ob.cycleReminderBox.getAll().map(_cycleReminderToJson).toList();
    data['preferences'] = ob.preferenceBox.getAll().map(_preferenceToJson).toList();
    data['conversationPrompts'] = ob.conversationPromptBox.getAll().map(_promptToJson).toList();
    data['trips'] = ob.tripBox.getAll().map(_tripToJson).toList();
    data['workouts'] = ob.workoutBox.getAll().map(_workoutToJson).toList();
    data['exerciseSets'] = ob.exerciseSetBox.getAll().map(_exerciseSetToJson).toList();
    data['fitnessGoals'] = ob.fitnessGoalBox.getAll().map(_fitnessGoalToJson).toList();
    data['bodyMetrics'] = ob.bodyMetricBox.getAll().map(_bodyMetricToJson).toList();
    data['mediaItems'] = ob.mediaBox.getAll().map(_mediaToJson).toList();
    data['contacts'] = ob.crmContactBox.getAll().map(_contactToJson).toList();
    data['skills'] = ob.skillBox.getAll().map(_skillToJson).toList();
    data['practiceSessions'] = ob.practiceSessionBox.getAll().map(_practiceSessionToJson).toList();
    data['projects'] = ob.projectBox.getAll().map(_projectToJson).toList();
    data['maintenance'] = ob.maintenanceBox.getAll().map(_maintenanceToJson).toList();
    data['sleepEntries'] = ob.sleepBox.getAll().map(_sleepToJson).toList();
    data['bucketList'] = ob.bucketListBox.getAll().map(_bucketListToJson).toList();
    data['subscriptions'] = ob.subscriptionBox.getAll().map(_subscriptionToJson).toList();
    data['savingsGoals'] = ob.savingsGoalBox.getAll().map(_savingsGoalToJson).toList();
    data['rewardsCards'] = ob.rewardsCardBox.getAll().map(_rewardsCardToJson).toList();
    data['spendingProfile'] = ob.spendingProfileBox.getAll().map(_spendingProfileToJson).toList();
    data['betRecords'] = ob.betRecordBox.getAll().map(_betRecordToJson).toList();
    data['shoppingItems'] = ob.shoppingBox.getAll().map(_shoppingToJson).toList();
    data['notes'] = ob.noteBox.getAll().map(_noteToJson).toList();
    data['featuredPhotos'] = ob.featuredPhotoBox.getAll().map(_featuredPhotoToJson).toList();

    data['_meta'] = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Orbit',
    };

    final dir = await _backupDir();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/orbit_backup_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  /// Imports data from a backup JSON file. Merges by replacing all data.
  /// Returns the number of records imported.
  static Future<int> import(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Backup file not found');
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final ob = ObjectBox.instance;
    var count = 0;

    // Clear all existing data first.
    ob.todoBox.removeAll();
    ob.recipeBox.removeAll();
    ob.ingredientBox.removeAll();
    ob.cycleBox.removeAll();
    ob.dataPointBox.removeAll();
    ob.dateIdeaBox.removeAll();
    ob.giftBox.removeAll();
    ob.importantDateBox.removeAll();
    ob.loveLanguageBox.removeAll();
    ob.cycleReminderBox.removeAll();
    ob.preferenceBox.removeAll();
    ob.conversationPromptBox.removeAll();
    ob.tripBox.removeAll();
    ob.exerciseSetBox.removeAll();
    ob.workoutBox.removeAll();
    ob.fitnessGoalBox.removeAll();
    ob.bodyMetricBox.removeAll();
    ob.mediaBox.removeAll();
    ob.crmContactBox.removeAll();
    ob.skillBox.removeAll();
    ob.practiceSessionBox.removeAll();
    ob.projectBox.removeAll();
    ob.maintenanceBox.removeAll();
    ob.sleepBox.removeAll();
    ob.bucketListBox.removeAll();
    ob.subscriptionBox.removeAll();
    ob.savingsGoalBox.removeAll();
    ob.rewardsCardBox.removeAll();
    ob.spendingProfileBox.removeAll();
    ob.betRecordBox.removeAll();
    ob.shoppingBox.removeAll();
    ob.noteBox.removeAll();
    ob.featuredPhotoBox.removeAll();

    // Import each entity type.
    if (data['todos'] != null) {
      for (final j in data['todos']) {
        ob.todoBox.put(_todoFromJson(j));
        count++;
      }
    }
    if (data['recipes'] != null) {
      for (final j in data['recipes']) {
        ob.recipeBox.put(_recipeFromJson(j));
        count++;
      }
    }
    if (data['ingredients'] != null) {
      for (final j in data['ingredients']) {
        ob.ingredientBox.put(_ingredientFromJson(j));
        count++;
      }
    }
    if (data['cycleEntries'] != null) {
      for (final j in data['cycleEntries']) {
        ob.cycleBox.put(_cycleEntryFromJson(j));
        count++;
      }
    }
    if (data['dataPoints'] != null) {
      for (final j in data['dataPoints']) {
        ob.dataPointBox.put(_dataPointFromJson(j));
        count++;
      }
    }
    if (data['dateIdeas'] != null) {
      for (final j in data['dateIdeas']) { ob.dateIdeaBox.put(_dateIdeaFromJson(j)); count++; }
    }
    if (data['gifts'] != null) {
      for (final j in data['gifts']) { ob.giftBox.put(_giftFromJson(j)); count++; }
    }
    if (data['importantDates'] != null) {
      for (final j in data['importantDates']) { ob.importantDateBox.put(_importantDateFromJson(j)); count++; }
    }
    if (data['loveLanguageReminders'] != null) {
      for (final j in data['loveLanguageReminders']) { ob.loveLanguageBox.put(_loveLanguageFromJson(j)); count++; }
    }
    if (data['cycleReminders'] != null) {
      for (final j in data['cycleReminders']) { ob.cycleReminderBox.put(_cycleReminderFromJson(j)); count++; }
    }
    if (data['preferences'] != null) {
      for (final j in data['preferences']) { ob.preferenceBox.put(_preferenceFromJson(j)); count++; }
    }
    if (data['conversationPrompts'] != null) {
      for (final j in data['conversationPrompts']) { ob.conversationPromptBox.put(_promptFromJson(j)); count++; }
    }
    if (data['trips'] != null) {
      for (final j in data['trips']) { ob.tripBox.put(_tripFromJson(j)); count++; }
    }
    if (data['workouts'] != null) {
      for (final j in data['workouts']) { ob.workoutBox.put(_workoutFromJson(j)); count++; }
    }
    if (data['exerciseSets'] != null) {
      for (final j in data['exerciseSets']) { ob.exerciseSetBox.put(_exerciseSetFromJson(j)); count++; }
    }
    if (data['fitnessGoals'] != null) {
      for (final j in data['fitnessGoals']) { ob.fitnessGoalBox.put(_fitnessGoalFromJson(j)); count++; }
    }
    if (data['bodyMetrics'] != null) {
      for (final j in data['bodyMetrics']) { ob.bodyMetricBox.put(_bodyMetricFromJson(j)); count++; }
    }
    if (data['mediaItems'] != null) {
      for (final j in data['mediaItems']) { ob.mediaBox.put(_mediaFromJson(j)); count++; }
    }
    if (data['contacts'] != null) {
      for (final j in data['contacts']) { ob.crmContactBox.put(_contactFromJson(j)); count++; }
    }
    if (data['skills'] != null) {
      for (final j in data['skills']) { ob.skillBox.put(_skillFromJson(j)); count++; }
    }
    if (data['practiceSessions'] != null) {
      for (final j in data['practiceSessions']) { ob.practiceSessionBox.put(_practiceSessionFromJson(j)); count++; }
    }
    if (data['projects'] != null) {
      for (final j in data['projects']) { ob.projectBox.put(_projectFromJson(j)); count++; }
    }
    if (data['maintenance'] != null) {
      for (final j in data['maintenance']) { ob.maintenanceBox.put(_maintenanceFromJson(j)); count++; }
    }
    if (data['sleepEntries'] != null) {
      for (final j in data['sleepEntries']) { ob.sleepBox.put(_sleepFromJson(j)); count++; }
    }
    if (data['bucketList'] != null) {
      for (final j in data['bucketList']) { ob.bucketListBox.put(_bucketListFromJson(j)); count++; }
    }
    if (data['subscriptions'] != null) {
      for (final j in data['subscriptions']) { ob.subscriptionBox.put(_subscriptionFromJson(j)); count++; }
    }
    if (data['savingsGoals'] != null) {
      for (final j in data['savingsGoals']) { ob.savingsGoalBox.put(_savingsGoalFromJson(j)); count++; }
    }
    if (data['rewardsCards'] != null) {
      for (final j in data['rewardsCards']) { ob.rewardsCardBox.put(_rewardsCardFromJson(j)); count++; }
    }
    if (data['spendingProfile'] != null) {
      for (final j in data['spendingProfile']) { ob.spendingProfileBox.put(_spendingProfileFromJson(j)); count++; }
    }
    if (data['betRecords'] != null) {
      for (final j in data['betRecords']) { ob.betRecordBox.put(_betRecordFromJson(j)); count++; }
    }
    if (data['shoppingItems'] != null) {
      for (final j in data['shoppingItems']) { ob.shoppingBox.put(_shoppingFromJson(j)); count++; }
    }
    if (data['notes'] != null) {
      for (final j in data['notes']) { ob.noteBox.put(_noteFromJson(j)); count++; }
    }
    if (data['featuredPhotos'] != null) {
      for (final j in data['featuredPhotos']) { ob.featuredPhotoBox.put(_featuredPhotoFromJson(j)); count++; }
    }

    return count;
  }

  /// Lists available backup files.
  static Future<List<File>> listBackups() async {
    final dirs = <Directory>[];
    // Check both external and internal directories.
    final ext = await getExternalStorageDirectory();
    if (ext != null) dirs.add(ext);
    final docs = await getApplicationDocumentsDirectory();
    dirs.add(docs);

    final files = <File>[];
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      files.addAll(
        dir.listSync().whereType<File>().where(
          (f) => f.path.contains('orbit_backup_') && f.path.endsWith('.json'),
        ),
      );
    }
    // Deduplicate by filename and sort newest first.
    final seen = <String>{};
    final unique = <File>[];
    for (final f in files) {
      final name = f.path.split('/').last;
      if (seen.add(name)) unique.add(f);
    }
    unique.sort((a, b) => b.path.compareTo(a.path));
    return unique;
  }

  // ─── SERIALIZATION HELPERS ───

  static DateTime? _dt(String? s) => s == null || s.isEmpty ? null : DateTime.parse(s);
  static String? _dts(DateTime? d) => d?.toIso8601String();

  static Map<String, dynamic> _todoToJson(Todo t) => {
    'title': t.title, 'notes': t.notes, 'done': t.done,
    'dueDate': _dts(t.dueDate), 'createdAt': _dts(t.createdAt), 'completedAt': _dts(t.completedAt),
  };
  static Todo _todoFromJson(Map<String, dynamic> j) => Todo(
    title: j['title'] ?? '', notes: j['notes'], done: j['done'] ?? false,
    dueDate: _dt(j['dueDate']), createdAt: _dt(j['createdAt']), completedAt: _dt(j['completedAt']),
  );

  static Map<String, dynamic> _recipeToJson(Recipe r) => {
    'name': r.name, 'description': r.description, 'ingredients': r.ingredients,
    'steps': r.steps, 'servings': r.servings, 'prepTimeMinutes': r.prepTimeMinutes,
    'cookTimeMinutes': r.cookTimeMinutes, 'favorite': r.favorite,
    'photoPath': r.photoPath, 'tagsRaw': r.tagsRaw, 'createdAt': _dts(r.createdAt),
  };
  static Recipe _recipeFromJson(Map<String, dynamic> j) => Recipe(
    name: j['name'] ?? '', description: j['description'], ingredients: j['ingredients'] ?? '',
    steps: j['steps'] ?? '', servings: j['servings'] ?? 1,
    prepTimeMinutes: j['prepTimeMinutes'], cookTimeMinutes: j['cookTimeMinutes'],
    favorite: j['favorite'] ?? false, photoPath: j['photoPath'],
    tagsRaw: j['tagsRaw'] ?? '', createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _ingredientToJson(Ingredient i) => {
    'quantity': i.quantity, 'unit': i.unit, 'name': i.name, 'note': i.note, 'order': i.order,
  };
  static Ingredient _ingredientFromJson(Map<String, dynamic> j) => Ingredient(
    quantity: (j['quantity'] as num?)?.toDouble(), unit: j['unit'],
    name: j['name'] ?? '', note: j['note'], order: j['order'] ?? 0,
  );

  static Map<String, dynamic> _cycleEntryToJson(CycleEntry e) => {
    'date': _dts(e.date), 'flow': e.flow, 'note': e.note, 'symptomsRaw': e.symptomsRaw,
  };
  static CycleEntry _cycleEntryFromJson(Map<String, dynamic> j) => CycleEntry(
    date: _dt(j['date']) ?? DateTime.now(), flow: j['flow'] ?? 0,
    note: j['note'], symptomsRaw: j['symptomsRaw'] ?? '',
  );

  static Map<String, dynamic> _dataPointToJson(DataPoint d) => {
    'metric': d.metric, 'value': d.value, 'unit': d.unit,
    'recordedAt': _dts(d.recordedAt), 'note': d.note,
  };
  static DataPoint _dataPointFromJson(Map<String, dynamic> j) => DataPoint(
    metric: j['metric'] ?? '', value: (j['value'] as num?)?.toDouble() ?? 0,
    unit: j['unit'], recordedAt: _dt(j['recordedAt']), note: j['note'],
  );

  static Map<String, dynamic> _dateIdeaToJson(DateIdea d) => {
    'title': d.title, 'notes': d.notes, 'category': d.category,
    'done': d.done, 'completedAt': _dts(d.completedAt), 'createdAt': _dts(d.createdAt),
  };
  static DateIdea _dateIdeaFromJson(Map<String, dynamic> j) => DateIdea(
    title: j['title'] ?? '', notes: j['notes'], category: j['category'] ?? '',
    done: j['done'] ?? false, completedAt: _dt(j['completedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _giftToJson(GiftEntry g) => {
    'title': g.title, 'notes': g.notes, 'status': g.status,
    'occasion': g.occasion, 'price': g.price,
    'givenAt': _dts(g.givenAt), 'createdAt': _dts(g.createdAt),
  };
  static GiftEntry _giftFromJson(Map<String, dynamic> j) => GiftEntry(
    title: j['title'] ?? '', notes: j['notes'], status: j['status'] ?? 'idea',
    occasion: j['occasion'], price: (j['price'] as num?)?.toDouble(),
    givenAt: _dt(j['givenAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _importantDateToJson(ImportantDate d) => {
    'title': d.title, 'notes': d.notes, 'date': _dts(d.date),
    'recurring': d.recurring, 'createdAt': _dts(d.createdAt),
  };
  static ImportantDate _importantDateFromJson(Map<String, dynamic> j) => ImportantDate(
    title: j['title'] ?? '', notes: j['notes'],
    date: _dt(j['date']) ?? DateTime.now(), recurring: j['recurring'] ?? true,
    createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _loveLanguageToJson(LoveLanguageReminder r) => {
    'language': r.language, 'action': r.action, 'frequencyDays': r.frequencyDays,
    'enabled': r.enabled, 'lastShownAt': _dts(r.lastShownAt), 'createdAt': _dts(r.createdAt),
  };
  static LoveLanguageReminder _loveLanguageFromJson(Map<String, dynamic> j) => LoveLanguageReminder(
    language: j['language'] ?? '', action: j['action'] ?? '',
    frequencyDays: j['frequencyDays'] ?? 3, enabled: j['enabled'] ?? true,
    lastShownAt: _dt(j['lastShownAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _cycleReminderToJson(CycleReminder r) => {
    'title': r.title, 'message': r.message, 'triggerType': r.triggerType,
    'daysBefore': r.daysBefore, 'enabled': r.enabled, 'createdAt': _dts(r.createdAt),
  };
  static CycleReminder _cycleReminderFromJson(Map<String, dynamic> j) => CycleReminder(
    title: j['title'] ?? '', message: j['message'] ?? '',
    triggerType: j['triggerType'] ?? 'before_period', daysBefore: j['daysBefore'] ?? 2,
    enabled: j['enabled'] ?? true, createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _preferenceToJson(PreferenceEntry p) => {
    'category': p.category, 'label': p.label, 'value': p.value, 'createdAt': _dts(p.createdAt),
  };
  static PreferenceEntry _preferenceFromJson(Map<String, dynamic> j) => PreferenceEntry(
    category: j['category'] ?? '', label: j['label'] ?? '', value: j['value'] ?? '',
    createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _promptToJson(ConversationPrompt p) => {
    'question': p.question, 'category': p.category, 'asked': p.asked,
    'userCreated': p.userCreated, 'askedAt': _dts(p.askedAt), 'createdAt': _dts(p.createdAt),
  };
  static ConversationPrompt _promptFromJson(Map<String, dynamic> j) => ConversationPrompt(
    question: j['question'] ?? '', category: j['category'] ?? '',
    asked: j['asked'] ?? false, userCreated: j['userCreated'] ?? true,
    askedAt: _dt(j['askedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _tripToJson(Trip t) => {
    'destination': t.destination, 'notes': t.notes,
    'startDate': _dts(t.startDate), 'endDate': _dts(t.endDate),
    'packingList': t.packingList, 'createdAt': _dts(t.createdAt),
  };
  static Trip _tripFromJson(Map<String, dynamic> j) => Trip(
    destination: j['destination'] ?? '', notes: j['notes'],
    startDate: _dt(j['startDate']), endDate: _dt(j['endDate']),
    packingList: j['packingList'] ?? '', createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _workoutToJson(Workout w) => {
    'date': _dts(w.date), 'durationMinutes': w.durationMinutes,
    'notes': w.notes, 'type': w.type, 'muscleGroupsRaw': w.muscleGroupsRaw,
    'createdAt': _dts(w.createdAt),
  };
  static Workout _workoutFromJson(Map<String, dynamic> j) => Workout(
    date: _dt(j['date']) ?? DateTime.now(), durationMinutes: j['durationMinutes'],
    notes: j['notes'], type: j['type'] ?? 'strength',
    muscleGroupsRaw: j['muscleGroupsRaw'] ?? '',
    createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _exerciseSetToJson(ExerciseSet s) => {
    'exerciseName': s.exerciseName, 'category': s.category,
    'weight': s.weight, 'reps': s.reps,
    'durationMinutes': s.durationMinutes, 'distanceKm': s.distanceKm, 'order': s.order,
  };
  static ExerciseSet _exerciseSetFromJson(Map<String, dynamic> j) => ExerciseSet(
    exerciseName: j['exerciseName'] ?? '', category: j['category'] ?? 'strength',
    weight: (j['weight'] as num?)?.toDouble(), reps: j['reps'],
    durationMinutes: (j['durationMinutes'] as num?)?.toDouble(),
    distanceKm: (j['distanceKm'] as num?)?.toDouble(), order: j['order'] ?? 0,
  );

  static Map<String, dynamic> _fitnessGoalToJson(FitnessGoal g) => {
    'goalType': g.goalType, 'title': g.title, 'exerciseName': g.exerciseName,
    'targetValue': g.targetValue, 'baselineValue': g.baselineValue, 'unit': g.unit,
    'deadline': _dts(g.deadline), 'completed': g.completed, 'createdAt': _dts(g.createdAt),
  };
  static FitnessGoal _fitnessGoalFromJson(Map<String, dynamic> j) => FitnessGoal(
    goalType: j['goalType'] ?? 'strength', title: j['title'] ?? '',
    exerciseName: j['exerciseName'], targetValue: (j['targetValue'] as num?)?.toDouble(),
    baselineValue: (j['baselineValue'] as num?)?.toDouble(), unit: j['unit'],
    deadline: _dt(j['deadline']), completed: j['completed'] ?? false,
    createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _bodyMetricToJson(BodyMetric m) => {
    'metric': m.metric, 'value': m.value, 'recordedAt': _dts(m.recordedAt),
  };
  static BodyMetric _bodyMetricFromJson(Map<String, dynamic> j) => BodyMetric(
    metric: j['metric'] ?? '', value: (j['value'] as num?)?.toDouble() ?? 0,
    recordedAt: _dt(j['recordedAt']),
  );

  static Map<String, dynamic> _mediaToJson(MediaItem m) => {
    'title': m.title, 'author': m.author, 'mediaType': m.mediaType,
    'status': m.status, 'rating': m.rating, 'notes': m.notes,
    'startedAt': _dts(m.startedAt), 'finishedAt': _dts(m.finishedAt), 'createdAt': _dts(m.createdAt),
  };
  static MediaItem _mediaFromJson(Map<String, dynamic> j) => MediaItem(
    title: j['title'] ?? '', author: j['author'], mediaType: j['mediaType'] ?? 'book',
    status: j['status'] ?? 'want', rating: j['rating'], notes: j['notes'],
    startedAt: _dt(j['startedAt']), finishedAt: _dt(j['finishedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _contactToJson(CrmContact c) => {
    'name': c.name, 'relationship': c.relationship, 'notes': c.notes,
    'phone': c.phone, 'email': c.email, 'reachOutDays': c.reachOutDays,
    'lastContactedAt': _dts(c.lastContactedAt), 'createdAt': _dts(c.createdAt),
  };
  static CrmContact _contactFromJson(Map<String, dynamic> j) => CrmContact(
    name: j['name'] ?? '', relationship: j['relationship'], notes: j['notes'],
    phone: j['phone'], email: j['email'], reachOutDays: j['reachOutDays'],
    lastContactedAt: _dt(j['lastContactedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _skillToJson(Skill s) => {
    'name': s.name, 'category': s.category, 'notes': s.notes,
    'totalMinutes': s.totalMinutes, 'lastPracticedAt': _dts(s.lastPracticedAt),
    'createdAt': _dts(s.createdAt),
  };
  static Skill _skillFromJson(Map<String, dynamic> j) => Skill(
    name: j['name'] ?? '', category: j['category'], notes: j['notes'],
    totalMinutes: j['totalMinutes'] ?? 0, lastPracticedAt: _dt(j['lastPracticedAt']),
    createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _practiceSessionToJson(PracticeSession p) => {
    'skillName': p.skillName, 'durationMinutes': p.durationMinutes,
    'notes': p.notes, 'date': _dts(p.date),
  };
  static PracticeSession _practiceSessionFromJson(Map<String, dynamic> j) => PracticeSession(
    skillName: j['skillName'] ?? '', durationMinutes: j['durationMinutes'] ?? 0,
    notes: j['notes'], date: _dt(j['date']),
  );

  static Map<String, dynamic> _projectToJson(Project p) => {
    'name': p.name, 'description': p.description, 'status': p.status,
    'tasks': p.tasks, 'deadline': _dts(p.deadline), 'createdAt': _dts(p.createdAt),
  };
  static Project _projectFromJson(Map<String, dynamic> j) => Project(
    name: j['name'] ?? '', description: j['description'], status: j['status'] ?? 'active',
    tasks: j['tasks'] ?? '', deadline: _dt(j['deadline']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _maintenanceToJson(MaintenanceItem m) => {
    'title': m.title, 'category': m.category, 'notes': m.notes,
    'intervalDays': m.intervalDays, 'lastDoneAt': _dts(m.lastDoneAt),
    'nextDueAt': _dts(m.nextDueAt), 'createdAt': _dts(m.createdAt),
  };
  static MaintenanceItem _maintenanceFromJson(Map<String, dynamic> j) => MaintenanceItem(
    title: j['title'] ?? '', category: j['category'], notes: j['notes'],
    intervalDays: j['intervalDays'], lastDoneAt: _dt(j['lastDoneAt']),
    nextDueAt: _dt(j['nextDueAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _sleepToJson(SleepEntry s) => {
    'bedtime': _dts(s.bedtime), 'wakeTime': _dts(s.wakeTime),
    'quality': s.quality, 'notes': s.notes,
  };
  static SleepEntry _sleepFromJson(Map<String, dynamic> j) => SleepEntry(
    bedtime: _dt(j['bedtime']) ?? DateTime.now(),
    wakeTime: _dt(j['wakeTime']) ?? DateTime.now(),
    quality: j['quality'], notes: j['notes'],
  );

  static Map<String, dynamic> _bucketListToJson(BucketListItem b) => {
    'title': b.title, 'notes': b.notes, 'category': b.category,
    'done': b.done, 'completedAt': _dts(b.completedAt), 'createdAt': _dts(b.createdAt),
  };
  static BucketListItem _bucketListFromJson(Map<String, dynamic> j) => BucketListItem(
    title: j['title'] ?? '', notes: j['notes'], category: j['category'],
    done: j['done'] ?? false, completedAt: _dt(j['completedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _subscriptionToJson(Subscription s) => {
    'name': s.name, 'amount': s.amount, 'billingCycle': s.billingCycle,
    'kind': s.kind, 'category': s.category, 'notes': s.notes,
    'nextRenewal': _dts(s.nextRenewal), 'active': s.active, 'createdAt': _dts(s.createdAt),
  };
  static Subscription _subscriptionFromJson(Map<String, dynamic> j) => Subscription(
    name: j['name'] ?? '', amount: (j['amount'] as num?)?.toDouble() ?? 0,
    billingCycle: j['billingCycle'] ?? 'monthly', kind: j['kind'] ?? 'subscription',
    category: j['category'], notes: j['notes'], nextRenewal: _dt(j['nextRenewal']),
    active: j['active'] ?? true, createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _savingsGoalToJson(SavingsGoal g) => {
    'name': g.name, 'notes': g.notes, 'targetAmount': g.targetAmount,
    'savedAmount': g.savedAmount, 'linkUrl': g.linkUrl, 'type': g.type,
    'category': g.category, 'targetDate': _dts(g.targetDate),
    'achieved': g.achieved, 'achievedAt': _dts(g.achievedAt), 'createdAt': _dts(g.createdAt),
  };
  static SavingsGoal _savingsGoalFromJson(Map<String, dynamic> j) => SavingsGoal(
    name: j['name'] ?? '', notes: j['notes'],
    targetAmount: (j['targetAmount'] as num?)?.toDouble() ?? 0,
    savedAmount: (j['savedAmount'] as num?)?.toDouble() ?? 0,
    linkUrl: j['linkUrl'], type: j['type'] ?? 'savings', category: j['category'],
    targetDate: _dt(j['targetDate']), achieved: j['achieved'] ?? false,
    achievedAt: _dt(j['achievedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _rewardsCardToJson(RewardsCard c) => {
    'name': c.name, 'notes': c.notes, 'categoriesRaw': c.categoriesRaw,
    'activeRotatingCategory': c.activeRotatingCategory, 'annualFee': c.annualFee,
    'apr': c.apr, 'isDefault': c.isDefault, 'active': c.active, 'createdAt': _dts(c.createdAt),
  };
  static RewardsCard _rewardsCardFromJson(Map<String, dynamic> j) => RewardsCard(
    name: j['name'] ?? '', notes: j['notes'], categoriesRaw: j['categoriesRaw'] ?? '',
    activeRotatingCategory: j['activeRotatingCategory'],
    annualFee: (j['annualFee'] as num?)?.toDouble() ?? 0,
    apr: (j['apr'] as num?)?.toDouble(), isDefault: j['isDefault'] ?? false,
    active: j['active'] ?? true, createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _spendingProfileToJson(SpendingProfileEntry s) => {
    'category': s.category, 'monthlySpend': s.monthlySpend, 'updatedAt': _dts(s.updatedAt),
  };
  static SpendingProfileEntry _spendingProfileFromJson(Map<String, dynamic> j) => SpendingProfileEntry(
    category: j['category'] ?? '', monthlySpend: (j['monthlySpend'] as num?)?.toDouble() ?? 0,
    updatedAt: _dt(j['updatedAt']),
  );

  static Map<String, dynamic> _betRecordToJson(BetRecord b) => {
    'description': b.description, 'sport': b.sport, 'sportsbook': b.sportsbook,
    'stake': b.stake, 'decimalOdds': b.decimalOdds, 'status': b.status,
    'placedAt': _dts(b.placedAt), 'settledAt': _dts(b.settledAt), 'notes': b.notes,
  };
  static BetRecord _betRecordFromJson(Map<String, dynamic> j) => BetRecord(
    description: j['description'] ?? '', sport: j['sport'], sportsbook: j['sportsbook'],
    stake: (j['stake'] as num?)?.toDouble() ?? 0,
    decimalOdds: (j['decimalOdds'] as num?)?.toDouble() ?? 1.0,
    status: j['status'] ?? 'open', placedAt: _dt(j['placedAt']),
    settledAt: _dt(j['settledAt']), notes: j['notes'],
  );

  static Map<String, dynamic> _shoppingToJson(ShoppingItem s) => {
    'name': s.name, 'quantity': s.quantity, 'unit': s.unit,
    'sourceRecipe': s.sourceRecipe, 'checked': s.checked, 'addedAt': _dts(s.addedAt),
  };
  static ShoppingItem _shoppingFromJson(Map<String, dynamic> j) => ShoppingItem(
    name: j['name'] ?? '', quantity: (j['quantity'] as num?)?.toDouble(),
    unit: j['unit'], sourceRecipe: j['sourceRecipe'],
    checked: j['checked'] ?? false, addedAt: _dt(j['addedAt']),
  );

  static Map<String, dynamic> _noteToJson(Note n) => {
    'title': n.title, 'body': n.body, 'category': n.category,
    'pinned': n.pinned, 'updatedAt': _dts(n.updatedAt), 'createdAt': _dts(n.createdAt),
  };
  static Note _noteFromJson(Map<String, dynamic> j) => Note(
    title: j['title'] ?? '', body: j['body'] ?? '', category: j['category'],
    pinned: j['pinned'] ?? false, updatedAt: _dt(j['updatedAt']), createdAt: _dt(j['createdAt']),
  );

  static Map<String, dynamic> _featuredPhotoToJson(FeaturedPhoto p) => {
    'path': p.path, 'cropAlignment': p.cropAlignment, 'addedAt': _dts(p.addedAt),
  };
  static FeaturedPhoto _featuredPhotoFromJson(Map<String, dynamic> j) => FeaturedPhoto(
    path: j['path'] ?? '', cropAlignment: j['cropAlignment'] ?? 'center', addedAt: _dt(j['addedAt']),
  );
}

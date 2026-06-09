import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';
import '../services/widget_refresh.dart';

/// Sort direction for incomplete todos. Completed todos always sink to the
/// bottom, ordered by completion time (most recent first).
enum TodoSort { earliestFirst, latestFirst }

class TodoController extends GetxController {
  /// Raw items from the DB (unsorted). UI reads [todos] for the sorted view.
  final RxList<Todo> _items = <Todo>[].obs;

  /// Current sort direction. UI binds to this for the toggle icon.
  final Rx<TodoSort> sort = TodoSort.earliestFirst.obs;

  /// Sorted view. Reads both observables so any [Obx] that calls this
  /// getter rebuilds when either changes.
  List<Todo> get todos {
    final direction = sort.value; // register dependency on sort
    final list = List<Todo>.from(_items);
    list.sort((a, b) => _compare(a, b, direction));
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    final box = ObjectBox.instance.todoBox;
    box.query().watch(triggerImmediately: false).listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.todoBox.getAll());
  }

  int _compare(Todo a, Todo b, TodoSort direction) {
    // Done items always go to the bottom.
    if (a.done != b.done) return a.done ? 1 : -1;

    if (a.done && b.done) {
      // Most recently completed first among done items.
      final ac = a.completedAt ?? a.createdAt;
      final bc = b.completedAt ?? b.createdAt;
      return bc.compareTo(ac);
    }

    // Both incomplete: compare by due date with "no date = infinity".
    final ad = a.dueDate;
    final bd = b.dueDate;

    if (ad == null && bd == null) {
      // Tie-breaker: most recently created first.
      return b.createdAt.compareTo(a.createdAt);
    }
    if (ad == null) return 1;
    if (bd == null) return -1;

    return direction == TodoSort.earliestFirst
        ? ad.compareTo(bd)
        : bd.compareTo(ad);
  }

  void toggleSort() {
    sort.value = sort.value == TodoSort.earliestFirst
        ? TodoSort.latestFirst
        : TodoSort.earliestFirst;
  }

  Future<void> add(String title, {String? notes, DateTime? dueDate}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    ObjectBox.instance.todoBox.put(
      Todo(title: trimmed, notes: notes, dueDate: dueDate),
    );
    _reload();
    WidgetRefresh.refresh();
  }

  Future<void> updateTodo(
    Todo todo, {
    required String title,
    String? notes,
    DateTime? dueDate,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    todo.title = trimmed;
    todo.notes = notes;
    todo.dueDate = dueDate;
    ObjectBox.instance.todoBox.put(todo);
    _reload();
    WidgetRefresh.refresh();
  }

  Future<void> toggle(Todo todo) async {
    todo.done = !todo.done;
    todo.completedAt = todo.done ? DateTime.now() : null;
    ObjectBox.instance.todoBox.put(todo);
    _reload();
    WidgetRefresh.refresh();
  }

  Future<void> remove(Todo todo) async {
    ObjectBox.instance.todoBox.remove(todo.id);
    _reload();
    WidgetRefresh.refresh();
  }
}

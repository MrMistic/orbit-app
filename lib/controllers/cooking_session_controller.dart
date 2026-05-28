import 'dart:async';
import 'package:get/get.dart';

import '../services/notification_service.dart';

/// Per-recipe cooking session state. Tracks which steps the user has marked
/// done and a single running cook timer. Lives in memory only — closing the
/// detail page resets the session.
class CookingSessionController extends GetxController {
  final RxSet<int> doneSteps = <int>{}.obs;

  /// Seconds remaining on the current timer. Null when no timer is running.
  final RxnInt timerSecondsLeft = RxnInt();
  Timer? _ticker;
  String _timerRecipeName = '';

  void toggleStep(int index) {
    if (doneSteps.contains(index)) {
      doneSteps.remove(index);
    } else {
      doneSteps.add(index);
    }
    doneSteps.refresh();
  }

  bool isStepDone(int index) => doneSteps.contains(index);

  /// Starts a new timer, replacing any running one.
  void startTimer({required int minutes, required String recipeName}) {
    _ticker?.cancel();
    _timerRecipeName = recipeName;
    timerSecondsLeft.value = minutes * 60;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = timerSecondsLeft.value;
      if (left == null) {
        t.cancel();
        return;
      }
      if (left <= 1) {
        t.cancel();
        timerSecondsLeft.value = null;
        NotificationService.showTimerDone(recipeName: _timerRecipeName);
      } else {
        timerSecondsLeft.value = left - 1;
      }
    });
  }

  void cancelTimer() {
    _ticker?.cancel();
    _ticker = null;
    timerSecondsLeft.value = null;
  }

  void reset() {
    cancelTimer();
    doneSteps.clear();
  }

  @override
  void onClose() {
    cancelTimer();
    super.onClose();
  }
}

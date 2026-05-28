import 'package:get/get.dart';

import '../database/models.dart';
import '../database/object_box.dart';

class TripController extends GetxController {
  final RxList<Trip> _items = <Trip>[].obs;

  /// Upcoming trips first (by start date), then undated, then past.
  List<Trip> get trips {
    final list = List<Trip>.from(_items);
    final now = DateTime.now();
    list.sort((a, b) {
      final aFuture = a.startDate != null && a.startDate!.isAfter(now);
      final bFuture = b.startDate != null && b.startDate!.isAfter(now);
      if (aFuture && !bFuture) return -1;
      if (!aFuture && bFuture) return 1;
      if (a.startDate != null && b.startDate != null) {
        return a.startDate!.compareTo(b.startDate!);
      }
      if (a.startDate != null) return -1;
      if (b.startDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.tripBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) => _reload());
  }

  void _reload() {
    _items.assignAll(ObjectBox.instance.tripBox.getAll());
  }

  Future<Trip> add({
    required String destination,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final trip = Trip(
      destination: destination.trim(),
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      startDate: startDate,
      endDate: endDate,
    );
    final id = ObjectBox.instance.tripBox.put(trip);
    trip.id = id;
    _reload();
    return trip;
  }

  Future<void> updateTrip(
    Trip trip, {
    required String destination,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    trip.destination = destination.trim();
    trip.notes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    trip.startDate = startDate;
    trip.endDate = endDate;
    ObjectBox.instance.tripBox.put(trip);
    _reload();
  }

  Future<void> updatePackingList(Trip trip, String packingList) async {
    trip.packingList = packingList;
    ObjectBox.instance.tripBox.put(trip);
    _reload();
  }

  Future<void> remove(Trip trip) async {
    ObjectBox.instance.tripBox.remove(trip.id);
    _reload();
  }

  Trip? findById(int id) => ObjectBox.instance.tripBox.get(id);
}

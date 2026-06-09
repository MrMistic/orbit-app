import 'dart:io';
import 'dart:ui';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models.dart';
import '../database/object_box.dart';
import 'widget_refresh.dart';

/// Manages the user's curated featured photo collection for the home screen widget.
class FeaturedPhotoService {
  static const _intervalKey = 'featured_photo_interval_minutes';

  /// Pick one or more photos from gallery, copy to app-private storage, persist records.
  /// Silently skips duplicates (same file size as an existing featured photo).
  /// Corrects EXIF orientation at import time so the widget displays correctly.
  static Future<List<FeaturedPhoto>> addFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(requestFullMetadata: true);
    if (picked.isEmpty) return [];

    final dir = await _photosDir();
    final existing = getAll();
    final existingSizes = <int>{};
    for (final ph in existing) {
      final f = File(ph.path);
      if (f.existsSync()) existingSizes.add(f.lengthSync());
    }

    final added = <FeaturedPhoto>[];
    for (final image in picked) {
      final sourceFile = File(image.path);
      final sourceSize = await sourceFile.length();

      // Skip duplicates by file size.
      if (existingSizes.contains(sourceSize)) continue;

      final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
      final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final dest = File('${dir.path}/$filename');

      // Copy and fix orientation: decode via Flutter (respects EXIF) and re-encode.
      try {
        final bytes = await sourceFile.readAsBytes();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final uiImage = frame.image;
        final byteData = await uiImage.toByteData(format: ImageByteFormat.png);
        if (byteData != null) {
          await dest.writeAsBytes(byteData.buffer.asUint8List());
        } else {
          await sourceFile.copy(dest.path);
        }
        uiImage.dispose();
      } catch (_) {
        // Fallback: just copy as-is.
        await sourceFile.copy(dest.path);
      }

      final photo = FeaturedPhoto(path: dest.path);
      ObjectBox.instance.featuredPhotoBox.put(photo);
      existingSizes.add(sourceSize);
      added.add(photo);
    }

    if (added.isNotEmpty) await WidgetRefresh.refresh();
    return added;
  }

  /// Remove a photo: delete file and ObjectBox record.
  static Future<void> remove(int id) async {
    final box = ObjectBox.instance.featuredPhotoBox;
    final photo = box.get(id);
    if (photo != null) {
      final file = File(photo.path);
      if (await file.exists()) await file.delete();
      box.remove(id);
    }
    await WidgetRefresh.refresh();
  }

  /// Get all featured photos ordered by addedAt.
  static List<FeaturedPhoto> getAll() {
    final all = ObjectBox.instance.featuredPhotoBox.getAll();
    all.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return all;
  }

  /// Get rotation interval in minutes (default 1440 = daily).
  static Future<int> getRotationIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_intervalKey) ?? 1440;
  }

  /// Set rotation interval in minutes.
  static Future<void> setRotationIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, minutes);
    await WidgetRefresh.refresh();
  }

  static Future<Directory> _photosDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/featured_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

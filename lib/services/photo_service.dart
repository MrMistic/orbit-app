import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Picks images and copies them into app-private storage.
/// Returns absolute paths suitable for storing in DB and rendering with
/// [Image.file]. The original picker file is in a cache that may be cleared.
class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Show the gallery picker. Returns the new app-private path or null if
  /// the user cancelled.
  static Future<String?> pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _persist(File(picked.path));
  }

  /// Take a photo with the camera. Returns the new app-private path or null
  /// if the user cancelled.
  static Future<String?> takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _persist(File(picked.path));
  }

  static Future<String> _persist(File source) async {
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'recipe_photos'));
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final ext = p.extension(source.path).toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(photosDir.path, name));
    await source.copy(dest.path);
    return dest.path;
  }

  /// Best-effort delete of a stored photo. Safe to call on missing files.
  static Future<void> tryDelete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Swallow — orphaned files are not fatal.
    }
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../database/models.dart';
import '../../../database/object_box.dart';
import '../../../services/featured_photo_service.dart';
import '../../../services/widget_refresh.dart';

class FeaturedPhotosPage extends StatefulWidget {
  const FeaturedPhotosPage({super.key});

  @override
  State<FeaturedPhotosPage> createState() => _FeaturedPhotosPageState();
}

class _FeaturedPhotosPageState extends State<FeaturedPhotosPage> {
  List<FeaturedPhoto> _photos = [];
  int _intervalHours = 24;

  static const _intervalOptions = [
    (30, 'Every 30 min'),
    (60, 'Every hour'),
    (360, 'Every 6 hours'),
    (1440, 'Every day'),
    (4320, 'Every 3 days'),
    (10080, 'Every week'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = FeaturedPhotoService.getAll();
    final interval = await FeaturedPhotoService.getRotationIntervalMinutes();
    if (mounted) setState(() { _photos = photos; _intervalHours = interval; });
  }

  Future<void> _add() async {
    await FeaturedPhotoService.addFromGallery();
    _load();
  }

  Future<void> _remove(FeaturedPhoto photo) async {
    await FeaturedPhotoService.remove(photo.id);
    _load();
  }

  void _confirmRemove(FeaturedPhoto photo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wallpaper),
              title: const Text('Show on widget now'),
              onTap: () {
                Navigator.pop(ctx);
                _forceShowPhoto(photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove from featured', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _remove(photo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceShowPhoto(FeaturedPhoto photo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('featured_photo_forced', photo.path);
    await prefs.setInt('featured_photo_forced_at', DateTime.now().millisecondsSinceEpoch);
    await WidgetRefresh.refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Widget updated!')),
      );
    }
  }

  Future<void> _setInterval(int minutes) async {
    await FeaturedPhotoService.setRotationIntervalMinutes(minutes);
    setState(() => _intervalHours = minutes);
  }

  Future<void> _forceReshuffle() async {
    if (_photos.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    // Shift the offset so the widget picks a different photo.
    final currentOffset = prefs.getInt('featured_photo_offset') ?? 0;
    await prefs.setInt('featured_photo_offset', currentOffset + 1);
    await WidgetRefresh.refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forced new photo shown!')),
      );
    }
  }

  void _showCropOptions(FeaturedPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CropPage(photo: photo, onCropped: () => _load()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: _forceReshuffle,
          child: Text('Featured Photos${_photos.isNotEmpty ? ' (${_photos.length})' : ''}'),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Rotation speed',
            onSelected: _setInterval,
            itemBuilder: (_) => _intervalOptions.map((opt) {
              return PopupMenuItem(
                value: opt.$1,
                child: Row(
                  children: [
                    if (opt.$1 == _intervalHours)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(opt.$2),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add_photo_alternate),
      ),
      body: _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('No featured photos yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Tap + to add photos for your home screen widget'),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _photos.length,
              itemBuilder: (ctx, i) {
                final photo = _photos[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(photo.path),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showCropOptions(photo),
                          onLongPress: () => _confirmRemove(photo),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}


// ---------------------------------------------------------------------------
// Crop Page
// ---------------------------------------------------------------------------

class _CropPage extends StatefulWidget {
  const _CropPage({required this.photo, required this.onCropped});
  final FeaturedPhoto photo;
  final VoidCallback onCropped;

  @override
  State<_CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<_CropPage> {
  final _cropController = CropController();
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.photo.path).readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  void _save() {
    setState(() => _saving = true);
    _cropController.crop();
  }

  Future<void> _onCropped(Uint8List croppedBytes) async {
    // Overwrite the stored file with the cropped version.
    await File(widget.photo.path).writeAsBytes(croppedBytes);
    await WidgetRefresh.refresh();
    widget.onCropped();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop for widget'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Crop(
              image: _imageBytes!,
              controller: _cropController,
              aspectRatio: 1.0,
              onCropped: _onCropped,
              withCircleUi: false,
              initialSize: 0.8,
            ),
    );
  }
}

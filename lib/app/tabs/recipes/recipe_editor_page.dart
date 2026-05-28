import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../controllers/recipe_controller.dart';
import '../../../database/models.dart';
import '../../../services/ingredient_parser.dart';
import '../../../services/photo_service.dart';

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, this.existing, this.imported});
  final Recipe? existing;

  /// Pre-filled from a URL import. Mutually exclusive with [existing].
  final ImportedRecipe? imported;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

/// Plain-data carrier so the URL importer doesn't need to depend on the
/// DB layer. Editor consumes this for "create with prefill".
class ImportedRecipe {
  ImportedRecipe({
    required this.name,
    this.description,
    this.ingredients = const [],
    this.steps = '',
    this.servings = 1,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.tags = const [],
  });

  final String name;
  final String? description;
  final List<String> ingredients; // raw lines
  final String steps;
  final int servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final List<String> tags;
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _stepsCtrl;
  late final TextEditingController _servingsCtrl;
  late final TextEditingController _prepCtrl;
  late final TextEditingController _cookCtrl;
  late final TextEditingController _ingredientsCtrl;
  late final TextEditingController _tagsCtrl;

  bool _favorite = false;
  String? _photoPath;
  String? _originalPhotoPath; // to know if we need to delete on save

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    final imp = widget.imported;

    _nameCtrl = TextEditingController(text: r?.name ?? imp?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? imp?.description ?? '');
    _stepsCtrl = TextEditingController(text: r?.steps ?? imp?.steps ?? '');
    _servingsCtrl = TextEditingController(
        text: (r?.servings ?? imp?.servings ?? 1).toString());
    _prepCtrl = TextEditingController(
        text: (r?.prepTimeMinutes ?? imp?.prepTimeMinutes)?.toString() ?? '');
    _cookCtrl = TextEditingController(
        text: (r?.cookTimeMinutes ?? imp?.cookTimeMinutes)?.toString() ?? '');

    // Ingredients render as text (one per line) for low-friction editing.
    // Parser reconstructs structure on save.
    final ingredientsText = r != null
        ? _ingredientsToText(r.ingredientList.toList())
        : (imp?.ingredients.join('\n') ?? '');
    _ingredientsCtrl = TextEditingController(text: ingredientsText);

    final tags = r?.tagList ?? imp?.tags ?? const <String>[];
    _tagsCtrl = TextEditingController(text: tags.join(', '));

    _favorite = r?.favorite ?? false;
    _photoPath = r?.photoPath;
    _originalPhotoPath = r?.photoPath;
  }

  String _ingredientsToText(List<Ingredient> list) {
    list.sort((a, b) => a.order.compareTo(b.order));
    return list.map((i) => i.display).join('\n');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _stepsCtrl.dispose();
    _servingsCtrl.dispose();
    _prepCtrl.dispose();
    _cookCtrl.dispose();
    _ingredientsCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final c = Get.find<RecipeController>();

    final servings = int.tryParse(_servingsCtrl.text.trim()) ?? 1;
    final prep = int.tryParse(_prepCtrl.text.trim());
    final cook = int.tryParse(_cookCtrl.text.trim());
    final ingredients = IngredientParser.parseLines(_ingredientsCtrl.text);
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_isEdit) {
      // If photo changed, delete the old file.
      if (_originalPhotoPath != null && _originalPhotoPath != _photoPath) {
        await PhotoService.tryDelete(_originalPhotoPath);
      }
      await c.updateRecipe(
        widget.existing!,
        name: _nameCtrl.text,
        description: _descCtrl.text,
        ingredients: ingredients,
        steps: _stepsCtrl.text,
        servings: servings,
        prepTimeMinutes: prep,
        cookTimeMinutes: cook,
        favorite: _favorite,
        photoPath: _photoPath,
        tags: tags,
      );
    } else {
      await c.create(
        name: _nameCtrl.text,
        description: _descCtrl.text,
        ingredients: ingredients,
        steps: _stepsCtrl.text,
        servings: servings,
        prepTimeMinutes: prep,
        cookTimeMinutes: cook,
        favorite: _favorite,
        photoPath: _photoPath,
        tags: tags,
      );
    }
    Get.back();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final newPath = source == ImageSource.camera
        ? await PhotoService.takePhoto()
        : await PhotoService.pickFromGallery();
    if (newPath != null && mounted) setState(() => _photoPath = newPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit recipe' : 'New recipe'),
        actions: [
          IconButton(
            tooltip: _favorite ? 'Unfavorite' : 'Favorite',
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Photo picker
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: _photoPath != null
                      ? DecorationImage(
                          image: FileImage(File(_photoPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: _photoPath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Add a photo',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _servingsCtrl,
                    label: 'Servings',
                    minValue: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    controller: _prepCtrl,
                    label: 'Prep (min)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    controller: _cookCtrl,
                    label: 'Cook (min)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags',
                helperText: 'Comma-separated, e.g. "vegetarian, quick"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ingredientsCtrl,
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                helperText: 'One per line, e.g. "1.5 cups flour, sifted"',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 12,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stepsCtrl,
              decoration: const InputDecoration(
                labelText: 'Steps',
                helperText: 'One per line, in order',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 6,
              maxLines: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.minValue,
  });

  final TextEditingController controller;
  final String label;
  final int? minValue;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final n = int.tryParse(v.trim());
        if (n == null) return 'Number';
        if (minValue != null && n < minValue!) return '≥ $minValue';
        return null;
      },
    );
  }
}

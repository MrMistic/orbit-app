import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<File> _backups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final files = await BackupService.listBackups();
    if (mounted) setState(() => _backups = files);
  }

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      final path = await BackupService.export();
      await _loadBackups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved: ${path.split('/').last}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will replace ALL current data with the backup. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final count = await BackupService.import(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored $count records.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _importFromFile() async {
    // Use platform channel to open native file picker for JSON files.
    const channel = MethodChannel('com.life.orbit/intent');
    try {
      final path = await channel.invokeMethod<String>('pickJsonFile');
      if (path == null || path.isEmpty) return;
      await _restore(File(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picker error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.backup),
                  label: const Text('Create backup'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _importFromFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Import from file'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Backups are saved to external storage and survive app updates.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Text('Saved backups', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_backups.isEmpty)
                  const Text('No backups yet.', style: TextStyle(color: Colors.grey)),
                ..._backups.map((f) {
                  final name = f.path.split('/').last;
                  final stat = f.statSync();
                  final size = (stat.size / 1024).toStringAsFixed(0);
                  final date = DateFormat.yMd().add_jm().format(stat.modified);
                  return Card(
                    child: ListTile(
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$size KB · $date'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () => _share(f),
                          ),
                          IconButton(
                            icon: const Icon(Icons.restore),
                            onPressed: () => _restore(f),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

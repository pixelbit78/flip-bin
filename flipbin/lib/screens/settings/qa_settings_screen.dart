// QA-build Settings (SPEC §12.2/§12.6/§12.9): local XLSX export/import and
// QA tools. No Google UI or code paths. Referenced only when !kIsProd.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flipbin/config/env.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/qa/qa_fixtures.dart';
import 'package:flipbin/screens/settings/lot_review_screen.dart';
import 'package:flipbin/services/backends/local_file_backend.dart';
import 'package:flipbin/services/backends/local_file_io.dart' as io;
import 'package:flipbin/services/sheet_mapping.dart';

class QaSettingsScreen extends ConsumerWidget {
  const QaSettingsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      await const LocalFileBackend().export(ref.read(databaseProvider));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded $kQaExportFileName')),
        );
      }
    } catch (e) {
      if (context.mounted) _error(context, 'Export failed: $e');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    const backend = LocalFileBackend();
    LocalImport? data;
    try {
      data = await backend.pickAndParse();
    } on SheetFormatException catch (e) {
      if (context.mounted) _error(context, e.toString());
      return;
    } catch (e) {
      if (context.mounted) _error(context, 'Not a valid FlipBin export: $e');
      return;
    }
    if (data == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite QA data?'),
        content: Text(
            'Replace all local QA data with ${data!.inventory.items.length} '
            'inventory rows and ${data.expenses.length} expenses from the file?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Overwrite & Import')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await backend.apply(ref.read(databaseProvider), data);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import report'),
        content: SingleChildScrollView(
          child: Text([
            'Imported ${data!.inventory.items.length} inventory rows and '
                '${data.expenses.length} expenses.',
            if (data.report.isNotEmpty) '',
            ...data.report,
          ].join('\n')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _error(BuildContext context, String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import failed'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Backup: Local file',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text(
                    'QA build — export/import use an .xlsx file with the same '
                    'Inventory/Expenses tabs and columns as the Google sheet. '
                    'Not connected to Google.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('qaExport'),
                    onPressed: () => _export(context, ref),
                    icon: const Icon(Icons.download),
                    label: const Text('Export (Local file)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('qaImport'),
                    onPressed: () => _import(context, ref),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import (Local file)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ReviewLotsCard(),
          const SizedBox(height: 16),
          if (kIsQa) const QaToolsSection(),
        ],
      ),
    );
  }
}

/// QA-only data tools (SPEC §12.9). Every action confirms first.
class QaToolsSection extends ConsumerWidget {
  const QaToolsSection({super.key});

  Future<bool> _confirm(BuildContext context, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('This wipes all QA data on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('QA tools',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('qaReset'),
              onPressed: () async {
                if (!await _confirm(context, 'Reset QA data')) return;
                await ref.read(databaseProvider).close();
                io.wipeQaStorage(Env.dbName);
                io.reloadPage();
              },
              child: const Text('Reset QA data'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('qaLoadLegacy'),
              onPressed: () async {
                if (!await _confirm(context, 'Load legacy v1 fixture')) return;
                final db = ref.read(databaseProvider);
                await writeLegacyV1(db, DateTime.now());
                await db.close();
                io.setDriftSchemaVersion(Env.dbName, 1);
                io.reloadPage();
              },
              child: const Text('Load legacy v1 fixture'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('qaLoadV2'),
              onPressed: () async {
                if (!await _confirm(context, 'Load v2 sample')) return;
                final db = ref.read(databaseProvider);
                await writeV2Sample(db, DateTime.now());
                await db.close();
                io.reloadPage();
              },
              child: const Text('Load v2 sample'),
            ),
          ],
        ),
      ),
    );
  }
}

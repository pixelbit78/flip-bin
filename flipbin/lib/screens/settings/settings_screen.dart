import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flipbin/providers/sync_provider.dart';
import 'package:flipbin/services/google_sheets_service.dart';

/// Settings screen for managing Google Sheets synchronization and cloud backup.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _clientIdController;
  bool _showClientIdConfig = false;

  @override
  void initState() {
    super.initState();
    _clientIdController = TextEditingController(text: GoogleSheetsService.defaultClientId);
    // PWA: check daily auto-backup when Settings opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(syncProvider.notifier).maybeRunAutoBackup();
    });
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndImport(BuildContext context, SyncNotifier syncNotifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Overwrite Local Data?'),
          ],
        ),
        content: const Text(
          'Importing from Google Sheets will completely overwrite all local inventory items and expenses with the data in "FlipBin Export".\n\nThis cannot be undone. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Overwrite & Import'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final result = await syncNotifier.import();
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              'Successfully imported ${result.itemsCount} inventory items and ${result.expensesCount} expenses!',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent Browser Storage Eviction Warning (Review Focus #2)
            Card(
              color: Colors.amber.shade900.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade700, width: 1.5),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important: Browser Storage Notice',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.amber,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'FlipBin stores data locally in your browser (IndexedDB). If your device storage runs low, the browser may evict local cache. Sync regularly with Google Sheets to keep your data permanently backed up.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Google Account Section
            Text(
              'Google Account',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: syncState.isSignedIn
                    ? Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  syncState.displayName ?? 'Google User',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  syncState.displayEmail ?? '',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => syncNotifier.signOut(),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sign in with your Google account to enable spreadsheet backup to Google Sheets.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => syncNotifier.signIn(),
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In with Google'),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => setState(() => _showClientIdConfig = !_showClientIdConfig),
                            child: Row(
                              children: [
                                Icon(
                                  _showClientIdConfig ? Icons.expand_less : Icons.expand_more,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'OAuth Client ID Configuration (Web)',
                                  style: TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          if (_showClientIdConfig) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'On Web, Google Sign-In requires an OAuth 2.0 Client ID from Google Cloud Console with http://localhost:8080 authorized as a JavaScript origin.',
                              style: TextStyle(fontSize: 11, color: Colors.white38),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _clientIdController,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter Web Client ID (.apps.googleusercontent.com)',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final id = _clientIdController.text.trim();
                                    syncNotifier.setClientId(id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Client ID saved!')),
                                    );
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                          if (syncState.error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                syncState.error!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Google Sheets Export & Import Section
            Text(
              'Google Sheets Backup (Export & Import)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Last Exported:'),
                        Text(
                          syncState.lastSyncedAt != null
                              ? dateFormat.format(syncState.lastSyncedAt!)
                              : 'Never',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: syncState.lastSyncedAt != null
                                ? Colors.greenAccent
                                : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    if (syncState.lastImportedAt != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Last Imported:'),
                          Text(
                            dateFormat.format(syncState.lastImportedAt!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlueAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (syncState.spreadsheetId != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.table_chart, color: Colors.greenAccent, size: 22),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FlipBin Export',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Saved in Google Drive • Tabs: Inventory, Expenses',
                                        style: TextStyle(fontSize: 11, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    final url = Uri.parse(
                                      'https://docs.google.com/spreadsheets/d/${syncState.spreadsheetId}/edit',
                                    );
                                    launchUrl(url, mode: LaunchMode.externalApplication);
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Open Sheet'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatic daily backup'),
                      subtitle: const Text(
                        'When On, FlipBin exports to Google Sheets if the last successful export was 24+ hours ago. Runs on app open, when you return to the app, or when Settings loads (web PWA has no reliable background job).',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      value: syncState.autoBackupEnabled,
                      onChanged: syncState.isSignedIn
                          ? (value) => syncNotifier.setAutoBackupEnabled(value)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (syncState.isSyncing || syncState.isImporting || !syncState.isSignedIn)
                                ? null
                                : () async {
                                    await syncNotifier.export();
                                    if (context.mounted && syncState.error == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Successfully exported data to Google Sheets!'),
                                        ),
                                      );
                                    }
                                  },
                            icon: syncState.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload),
                            label: Text(syncState.isSyncing ? 'Exporting...' : 'Export to Sheets'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (syncState.isSyncing || syncState.isImporting || !syncState.isSignedIn)
                                ? null
                                : () => _confirmAndImport(context, syncNotifier),
                            icon: syncState.isImporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.download),
                            label: Text(syncState.isImporting ? 'Importing...' : 'Import from Sheets'),
                          ),
                        ),
                      ],
                    ),
                    if (!syncState.isSignedIn) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in above to enable Google Sheets export and import.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                    if (syncState.error != null && syncState.isSignedIn) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          syncState.error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // About section
            const Center(
              child: Text(
                'FlipBin v1.0.0 • Reseller Inventory & Expense Tracker',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

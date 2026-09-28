import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/providers/sync_provider.dart';

/// Settings screen for managing Google Sheets synchronization and cloud backup.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: syncState.account != null
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
                                  syncState.account!.displayName ?? 'Google User',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  syncState.account!.email,
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
                            'Sign in with your Google account to enable two-way spreadsheet backup to Google Sheets.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => syncNotifier.signIn(),
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In with Google'),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Google Sheets Sync Section
            Text(
              'Google Sheets Backup',
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
                        const Text('Last Synced:'),
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
                    const SizedBox(height: 16),
                    if (syncState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          syncState.error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: syncState.isSyncing || syncState.account == null
                          ? null
                          : () => syncNotifier.sync(),
                      icon: syncState.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync Now to Sheets'),
                    ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/screens/dashboard/dashboard_screen.dart';

import 'package:flipbin/screens/expenses/expense_detail_screen.dart';
import 'package:flipbin/screens/expenses/expense_list_screen.dart';
import 'package:flipbin/screens/inventory/inventory_list_screen.dart';
import 'package:flipbin/screens/inventory/item_detail_screen.dart';

import 'package:flipbin/screens/scanner/scanner_screen.dart';
import 'package:flipbin/screens/settings/settings_screen.dart';
import 'package:flipbin/services/barcode_lookup_service.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/providers/sync_provider.dart';

/// FlipBin router configuration with bottom navigation shell.
class FlipBinRouter {
  FlipBinRouter._();

  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? 'new';
                  final extra = state.extra;
                  final prefill =
                      extra is BarcodeResult ? extra : null;
                  return ItemDetailScreen(
                    itemId: id,
                    scanPrefill: prefill,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpenseListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? 'new';
                  final extra = state.extra;
                  final prefill =
                      extra is BarcodeResult ? extra : null;
                  return ExpenseDetailScreen(
                    expenseId: id,
                    scanPrefill: prefill,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/scan',
            builder: (context, state) {
              final mode = state.uri.queryParameters['mode'];
              return ScannerScreen(returnBarcodeOnly: mode == 'filter');
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Shell widget providing bottom navigation bar.
///
/// Summary providers are Drift [StreamProvider]s and stay live; tab taps also
/// invalidate them as a thin backup (including re-tapping the current tab).
///
/// Also observes app resume so daily auto Sheets backup can run on PWA return
/// (Settings must not be the primary auto-backup trigger).
class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncProvider.notifier).maybeRunAutoBackup();
    }
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/inventory')) return 1;
    if (location.startsWith('/expenses')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _refreshSummaryProviders(WidgetRef ref) {
    for (final status in ItemStatus.values) {
      ref.invalidate(inventoryCountProvider(status));
      ref.invalidate(inventoryTotalCostProvider(status));
    }
    ref.invalidate(expenseTotalProvider);
    final now = DateTime.now();
    ref.invalidate(expenseMonthTotalProvider(DateTime(now.year, now.month, 1)));
  }

  void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    _refreshSummaryProviders(ref);
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/inventory');
        break;
      case 2:
        context.go('/expenses');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context, ref),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

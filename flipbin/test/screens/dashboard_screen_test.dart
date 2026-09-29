import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/expense_provider.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/screens/dashboard/dashboard_screen.dart';

void main() {
  testWidgets('dashboard shows inventory and expense summary cards', (tester) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryCountProvider(ItemStatus.active).overrideWith((ref) => Stream.value(47)),
          inventoryCountProvider(ItemStatus.sold).overrideWith((ref) => Stream.value(312)),
          inventoryTotalCostProvider(ItemStatus.active).overrideWith((ref) => Stream.value(1284.00)),
          expenseMonthTotalProvider(currentMonth).overrideWith((ref) => Stream.value(87.42)),
          expenseTotalProvider.overrideWith((ref) => Stream.value(450.00)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('47'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('\$1284.00'), findsOneWidget);
    expect(find.text('\$87.42'), findsOneWidget);
  });

  List<Override> _dashboardOverrides() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    return [
      inventoryCountProvider(ItemStatus.active).overrideWith((ref) => Stream.value(0)),
      inventoryCountProvider(ItemStatus.sold).overrideWith((ref) => Stream.value(0)),
      inventoryTotalCostProvider(ItemStatus.active).overrideWith((ref) => Stream.value(0.0)),
      expenseMonthTotalProvider(currentMonth).overrideWith((ref) => Stream.value(0.0)),
      expenseTotalProvider.overrideWith((ref) => Stream.value(0.0)),
    ];
  }

  testWidgets('scan barcode button navigates to /scan', (tester) async {
    String? navigatedRoute;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) {
            navigatedRoute = '/scan';
            return const Scaffold(body: Text('Scan Screen'));
          },
        ),
        GoRoute(
          path: '/inventory/new',
          builder: (context, state) {
            navigatedRoute = '/inventory/new';
            return const Scaffold(body: Text('New Item Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _dashboardOverrides(),
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scanButton = find.widgetWithText(ElevatedButton, 'Scan Barcode');
    expect(scanButton, findsOneWidget);
    await tester.tap(scanButton);
    await tester.pumpAndSettle();

    expect(navigatedRoute, equals('/scan'));
  });

  testWidgets('add item button navigates to /inventory/new', (tester) async {
    String? navigatedRoute;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/inventory/new',
          builder: (context, state) {
            navigatedRoute = '/inventory/new';
            return const Scaffold(body: Text('New Item Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _dashboardOverrides(),
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(ElevatedButton, 'Add Item');
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(navigatedRoute, equals('/inventory/new'));
  });
}

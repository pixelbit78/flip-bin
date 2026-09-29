import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/providers/dashboard_provider.dart';
import 'package:flipbin/screens/dashboard/dashboard_screen.dart';

void main() {
  List<Override> dashboardOverrides({
    double? avgDays = 18,
    AgingCapitalSummary? aging,
    double totalCost = 1600,
    AgingBuckets? buckets,
    SellThroughMetrics? sellThrough,
    List<MonthlyExpenseTotal>? months,
    List<InventoryItem>? movers,
  }) {
    final now = DateTime.now();
    aging ??= const AgingCapitalSummary(totalCostTimesQty: 840, itemCount: 23);
    buckets ??= const AgingBuckets(
      bucket30to59: AgingBucket(
        label: '30–59d',
        totalCostTimesQty: 310,
        itemCount: 11,
      ),
      bucket60to89: AgingBucket(
        label: '60–89d',
        totalCostTimesQty: 265,
        itemCount: 7,
      ),
      bucket90plus: AgingBucket(
        label: '90d+',
        totalCostTimesQty: 265,
        itemCount: 5,
      ),
    );
    sellThrough ??= const SellThroughMetrics(
      listed: 246,
      sold: 192,
      stillActive: 54,
      rate: 192 / 246,
      windowDays: 90,
    );
    months ??= [
      for (var i = 5; i >= 0; i--)
        MonthlyExpenseTotal(
          month: DateTime(now.year, now.month - i, 1),
          total: i == 0 ? 87 : 50.0 + i * 10,
        ),
    ];
    movers ??= const [];

    return [
      avgDaysToSellProvider.overrideWith((ref) => Stream.value(avgDays)),
      agingCapitalProvider.overrideWith((ref) => Stream.value(aging!)),
      activeTotalCostTimesQtyProvider
          .overrideWith((ref) => Stream.value(totalCost)),
      agingBucketsProvider.overrideWith((ref) => Stream.value(buckets!)),
      sellThroughProvider.overrideWith((ref) => Stream.value(sellThrough!)),
      monthlyExpensesProvider.overrideWith((ref) => Stream.value(months!)),
      topMoversProvider.overrideWith((ref) => Stream.value(movers!)),
    ];
  }

  testWidgets('dashboard Option C shows KPIs, sections, and quick actions',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(),
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FlipBin'), findsOneWidget);
    expect(find.text('18d'), findsOneWidget);
    expect(find.text('on Sold items'), findsOneWidget);
    expect(find.text('\$840'), findsOneWidget);
    expect(find.text('23 · 30d+'), findsOneWidget);
    expect(find.text('\$1.6k'), findsOneWidget);
    expect(find.text('Active · cost×qty'), findsOneWidget);

    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);

    expect(find.text('Aging capital'), findsWidgets);
    expect(find.text('Active stock'), findsOneWidget);
    expect(find.text('30–59d'), findsOneWidget);
    expect(find.text('60–89d'), findsOneWidget);
    expect(find.text('90d+'), findsOneWidget);

    expect(find.text('Sell-through'), findsOneWidget);
    expect(find.text('90 days'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('Listed'), findsOneWidget);
    expect(find.text('246'), findsOneWidget);
    expect(find.text('192'), findsOneWidget);
    expect(find.text('Still active'), findsOneWidget);
    expect(find.text('54'), findsOneWidget);

    expect(find.text('Monthly expenses'), findsOneWidget);
    expect(find.text('Top movers'), findsOneWidget);
    expect(find.text('Fastest sold'), findsOneWidget);
  });

  testWidgets('settings gear navigates to /settings', (tester) async {
    String? navigatedRoute;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            navigatedRoute = '/settings';
            return const Scaffold(body: Text('Settings Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(navigatedRoute, equals('/settings'));
  });

  testWidgets('scan quick action navigates to /scan', (tester) async {
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
            return const Scaffold(body: Text('New Item'));
          },
        ),
        GoRoute(
          path: '/expenses/new',
          builder: (context, state) {
            navigatedRoute = '/expenses/new';
            return const Scaffold(body: Text('New Expense'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(navigatedRoute, equals('/scan'));
  });

  testWidgets('add item quick action navigates to /inventory/new',
      (tester) async {
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
            return const Scaffold(body: Text('New Item'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(navigatedRoute, equals('/inventory/new'));
  });

  test('formatDashboardMoney compact rules', () {
    expect(formatDashboardMoney(840), '\$840');
    expect(formatDashboardMoney(1600), '\$1.6k');
    expect(formatDashboardMoney(1000), '\$1k');
    expect(formatDashboardMoney(87), '\$87');
    expect(formatAvgDays(18.4), '18d');
    expect(formatAvgDays(null), '—');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/models/enums.dart';

void main() {
  group('DrillDownQuery', () {
    test('aging factory serializes Active + age band chips', () {
      final q = DrillDownQuery.aging(minDays: 30, maxDays: 59);
      expect(q.title, 'Aging · 30–59d');
      expect(q.status, ItemStatus.active);
      expect(q.ageMinDays, 30);
      expect(q.ageMaxDays, 59);
      expect(q.chips.map((c) => c.label).toList(), ['Active', '30–59d']);

      final roundTrip =
          DrillDownQuery.fromQueryParameters(q.toQueryParameters());
      expect(roundTrip, q);
      expect(
        q.toLocation(path: '/drilldown/inventory'),
        contains('/drilldown/inventory?'),
      );
      expect(q.toLocation(path: '/drilldown/inventory'), contains('ageMin=30'));
    });

    test('aging 90d+ factory is open-ended Active band', () {
      final q = DrillDownQuery.aging(minDays: 90);
      expect(q.title, 'Aging · 90d+');
      expect(q.status, ItemStatus.active);
      expect(q.ageMinDays, 90);
      expect(q.ageMaxDays, isNull);
      expect(q.chips.map((c) => c.label).toList(), ['Active', '90d+']);
      final loc = q.toLocation(path: '/drilldown/inventory');
      expect(loc, contains('ageMin=90'));
      expect(loc, isNot(contains('ageMax=')));
    });

    test('sell-through Sold factory', () {
      final q = DrillDownQuery.sellThroughSold();
      expect(q.status, ItemStatus.sold);
      expect(q.soldWithinDays, 90);
      expect(q.chips.map((c) => c.label).toList(), ['Sold', '90 days']);
    });

    test('sell-through Listed uses dateAdded window not status', () {
      final q = DrillDownQuery.sellThroughListed();
      expect(q.status, isNull);
      expect(q.addedWithinDays, 90);
      expect(q.listedChip, isTrue);
      expect(q.chips.map((c) => c.label).toList(), ['Listed', '90 days']);
    });

    test('monthly sold / listed factories', () {
      final month = DateTime(2026, 9, 1);
      final sold = DrillDownQuery.monthlySold(month);
      expect(sold.status, ItemStatus.sold);
      expect(sold.soldMonth, month);
      expect(sold.chips.map((c) => c.label).toList(), ['Sold', 'Sep 2026']);

      final listed = DrillDownQuery.monthlyListed(month);
      expect(listed.status, isNull);
      expect(listed.addedMonth, month);
      expect(listed.listedChip, isTrue);
      expect(listed.chips.map((c) => c.label).toList(), ['Listed', 'Sep 2026']);
    });

    test('clearing last chip returns null (pop to Home)', () {
      final q = DrillDownQuery.aging(minDays: 60, maxDays: 89);
      final afterStatus = q.clearingChip('status');
      expect(afterStatus, isNotNull);
      expect(afterStatus!.status, isNull);
      expect(afterStatus.ageMinDays, 60);

      final afterBand = afterStatus.clearingChip('ageBand');
      expect(afterBand, isNull);
    });

    test('clearing window chip on sell-through Sold pops when only status left then cleared',
        () {
      final q = DrillDownQuery.sellThroughSold();
      final afterWindow = q.clearingChip('window');
      expect(afterWindow, isNotNull);
      expect(afterWindow!.soldWithinDays, isNull);
      expect(afterWindow.clearingChip('status'), isNull);
    });
  });

  group('ExpenseDrillDownQuery', () {
    test('forMonth round-trips', () {
      final q = ExpenseDrillDownQuery.forMonth(DateTime(2026, 9, 15));
      expect(q.month, DateTime(2026, 9, 1));
      expect(q.title, 'Expenses · Sep 2026');
      expect(q.monthChipLabel, 'Sep 2026');
      final round =
          ExpenseDrillDownQuery.fromQueryParameters(q.toQueryParameters());
      expect(round.month, q.month);
      expect(round.title, q.title);
      expect(q.toLocation(), startsWith('/drilldown/expenses?'));
    });
  });
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/providers/dashboard_provider.dart';
import 'package:flipbin/widgets/flipbin_wordmark.dart';

/// Home dashboard — Option C v2 matching the approved mockup.
///
/// Section order: KPIs (Total cost + Total active) → quick actions →
/// aging capital → sell-through 90d → monthly expenses.
/// No Top movers. Bottom nav lives in [ShellRoute].
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _bg = Color(0xFF1A1D23);
  static const _card = Color(0xFF252830);
  static const _accent = Color(0xFF2196F3);
  static const _green = Color(0xFF4CAF50);
  static const _muted = Color(0x8AFFFFFF); // white54

  static void pushInventoryDrillDown(BuildContext context, DrillDownQuery q) {
    context.push(q.toLocation(path: '/drilldown/inventory'));
  }

  static void pushExpenseDrillDown(BuildContext context, DateTime month) {
    final q = ExpenseDrillDownQuery.forMonth(month);
    context.push(q.toLocation());
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCostAsync = ref.watch(activeTotalCostTimesQtyProvider);
    final activeCountAsync = ref.watch(activeItemCountProvider);
    final bucketsAsync = ref.watch(agingBucketsProvider);
    final sellThroughAsync = ref.watch(sellThroughProvider);
    final monthsAsync = ref.watch(monthlyExpensesProvider);
    final soldMonthsAsync = ref.watch(monthlySoldProvider);
    final listedMonthsAsync = ref.watch(monthlyListedProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        title: const FlipBinWordmark(),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Color(0xBFFFFFFF)),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiRow(
              totalCostLabel: formatDashboardTotalCost(
                totalCostAsync.valueOrNull ?? 0,
              ),
              activeCountLabel: '${activeCountAsync.valueOrNull ?? 0}',
            ),
            const SizedBox(height: 12),
            const _QuickActionsRow(),
            const SizedBox(height: 14),
            _AgingCapitalCard(buckets: bucketsAsync.valueOrNull),
            const SizedBox(height: 12),
            _SellThroughCard(metrics: sellThroughAsync.valueOrNull),
            const SizedBox(height: 12),
            _MonthlyExpensesCard(months: monthsAsync.valueOrNull),
            const SizedBox(height: 12),
            _MonthlyInventoryCard(
              title: 'Monthly sold',
              subtitle:
                  'Item counts by dateSold — not sale \$ (no sale price yet)',
              color: DashboardScreen._green,
              currentColor: const Color(0xFF81C784),
              months: soldMonthsAsync.valueOrNull,
              onMonthTap: (month) => DashboardScreen.pushInventoryDrillDown(
                context,
                DrillDownQuery.monthlySold(month),
              ),
            ),
            const SizedBox(height: 12),
            _MonthlyInventoryCard(
              title: 'Monthly listed',
              subtitle: 'Items added/listed by dateAdded',
              color: const Color(0xFF00897B),
              currentColor: const Color(0xFF4DB6AC),
              months: listedMonthsAsync.valueOrNull,
              onMonthTap: (month) => DashboardScreen.pushInventoryDrillDown(
                context,
                DrillDownQuery.monthlyListed(month),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── KPI row ────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalCostLabel,
    required this.activeCountLabel,
  });

  final String totalCostLabel;
  final String activeCountLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Total cost',
            value: totalCostLabel,
            valueColor: DashboardScreen._accent,
            subtitle: 'Active · cost × qty',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Total active',
            value: activeCountLabel,
            valueColor: DashboardScreen._green,
            subtitle: 'items in stock',
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtitle,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: DashboardScreen._card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: DashboardScreen._muted,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: DashboardScreen._muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick actions ──────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            label: 'Scan',
            icon: Icons.qr_code_scanner,
            color: const Color(0xFF2196F3),
            onTap: () => context.go('/scan'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'Add Item',
            icon: Icons.add,
            color: const Color(0xFF2E7D32),
            onTap: () => context.go('/inventory/new'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'Expense',
            icon: Icons.description_outlined,
            color: const Color(0xFF00897B),
            onTap: () => context.go('/expenses/new'),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardScreen._card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xE6FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared card chrome ─────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.badge,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String badge;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardScreen._card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x0FFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashboardScreen._muted,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: DashboardScreen._muted,
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Aging capital breakdown ────────────────────────────────────────────────

class _AgingCapitalCard extends StatelessWidget {
  const _AgingCapitalCard({required this.buckets});

  final AgingBuckets? buckets;

  static const _colors = [
    Color(0xFFFFB74D), // 30–59
    Color(0xFFFF9800), // 60–89
    Color(0xFFEF5350), // 90+
  ];

  @override
  Widget build(BuildContext context) {
    final data = buckets ??
        const AgingBuckets(
          bucket30to59: AgingBucket(
            label: '30–59d',
            totalCostTimesQty: 0,
            itemCount: 0,
          ),
          bucket60to89: AgingBucket(
            label: '60–89d',
            totalCostTimesQty: 0,
            itemCount: 0,
          ),
          bucket90plus: AgingBucket(
            label: '90d+',
            totalCostTimesQty: 0,
            itemCount: 0,
          ),
        );
    final maxAmt = data.maxAmount;

    return _DashCard(
      title: 'Aging capital',
      badge: 'Active stock',
      child: Column(
        children: [
          for (var i = 0; i < data.asList.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _AgingRow(
              bucket: data.asList[i],
              color: _colors[i],
              maxAmount: maxAmt,
              onTap: i == 0
                  ? () => DashboardScreen.pushInventoryDrillDown(
                        context,
                        DrillDownQuery.aging(minDays: 30, maxDays: 59),
                      )
                  : i == 1
                      ? () => DashboardScreen.pushInventoryDrillDown(
                            context,
                            DrillDownQuery.aging(minDays: 60, maxDays: 89),
                          )
                      : () => DashboardScreen.pushInventoryDrillDown(
                            context,
                            DrillDownQuery.aging(minDays: 90),
                          ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgingRow extends StatelessWidget {
  const _AgingRow({
    required this.bucket,
    required this.color,
    required this.maxAmount,
    this.onTap,
  });

  final AgingBucket bucket;
  final Color color;
  final double maxAmount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount <= 0
        ? 0.0
        : (bucket.totalCostTimesQty / maxAmount).clamp(0.0, 1.0);

    final row = Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            bucket.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xBFFFFFFF),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: const Color(0x14FFFFFF)),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDashboardMoney(bucket.totalCostTimesQty),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${bucket.itemCount} items',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: DashboardScreen._muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      ),
    );
  }
}

// ─── Sell-through ───────────────────────────────────────────────────────────

class _SellThroughCard extends StatelessWidget {
  const _SellThroughCard({required this.metrics});

  final SellThroughMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics ??
        const SellThroughMetrics(
          listed: 0,
          sold: 0,
          stillActive: 0,
          rate: 0,
          windowDays: 90,
        );
    final pct = (m.rate * 100).round();

    void openListed() => DashboardScreen.pushInventoryDrillDown(
          context,
          DrillDownQuery.sellThroughListed(windowDays: m.windowDays),
        );
    void openSold() => DashboardScreen.pushInventoryDrillDown(
          context,
          DrillDownQuery.sellThroughSold(windowDays: m.windowDays),
        );
    void openStillActive() => DashboardScreen.pushInventoryDrillDown(
          context,
          DrillDownQuery.sellThroughStillActive(windowDays: m.windowDays),
        );

    return _DashCard(
      title: 'Sell-through',
      badge: '${m.windowDays} days',
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openStillActive,
              borderRadius: BorderRadius.circular(60),
              child: SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: _SellThroughRingPainter(rate: m.rate),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: DashboardScreen._green,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'sold',
                          style: TextStyle(
                            fontSize: 12,
                            color: DashboardScreen._muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _StStat(
                  label: 'Listed',
                  value: '${m.listed}',
                  onTap: openListed,
                ),
                const Divider(height: 1, color: Color(0x0FFFFFFF)),
                _StStat(
                  label: 'Sold',
                  value: '${m.sold}',
                  valueColor: DashboardScreen._green,
                  onTap: openSold,
                ),
                const Divider(height: 1, color: Color(0x0FFFFFFF)),
                _StStat(
                  label: 'Still active',
                  value: '${m.stillActive}',
                  onTap: openStillActive,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StStat extends StatelessWidget {
  const _StStat({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: DashboardScreen._muted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _SellThroughRingPainter extends CustomPainter {
  _SellThroughRingPainter({required this.rate});

  final double rate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 12.0;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final progress = Paint()
      ..color = DashboardScreen._green
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * rate.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _SellThroughRingPainter oldDelegate) =>
      oldDelegate.rate != rate;
}

// ─── Monthly expenses ───────────────────────────────────────────────────────

class _MonthlyExpensesCard extends StatelessWidget {
  const _MonthlyExpensesCard({required this.months});

  final List<MonthlyExpenseTotal>? months;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = months ??
        [
          for (var i = 5; i >= 0; i--)
            MonthlyExpenseTotal(
              month: DateTime(now.year, now.month - i, 1),
              total: 0,
            ),
        ];
    final yearLabel =
        data.isNotEmpty ? '${data.last.month.year}' : '${now.year}';

    return _DashCard(
      title: 'Monthly expenses',
      badge: yearLabel,
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final month = _MonthlyBarsPainter.hitTestMonth(
                  details.localPosition,
                  constraints.biggest,
                  data,
                );
                if (month != null) {
                  DashboardScreen.pushExpenseDrillDown(context, month);
                }
              },
              child: CustomPaint(
                painter: _MonthlyBarsPainter(months: data, now: now),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MonthlyBarsPainter extends CustomPainter {
  _MonthlyBarsPainter({required this.months, required this.now});

  final List<MonthlyExpenseTotal> months;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    const leftGutter = 36.0;
    const bottomGutter = 28.0;
    const topPad = 16.0;
    final chartW = size.width - leftGutter;
    final chartH = size.height - bottomGutter - topPad;
    final maxVal = months.map((m) => m.total).fold<double>(0, math.max);
    final yMax = maxVal <= 0 ? 150.0 : _niceMax(maxVal);

    final gridPaint = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 1;
    final baselinePaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;

    // Grid lines at 100%, 50%, 0%
    for (final t in [0.0, 0.5, 1.0]) {
      final y = topPad + chartH * (1 - t);
      canvas.drawLine(
        Offset(leftGutter, y),
        Offset(size.width, y),
        t == 0 ? baselinePaint : gridPaint,
      );
      final label = _axisLabel(yMax * t);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0x80FFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: leftGutter - 6);
      tp.paint(canvas, Offset(leftGutter - 6 - tp.width, y - tp.height / 2));
    }

    final n = months.length;
    final slot = chartW / n;
    final barW = math.min(32.0, slot * 0.55);
    final monthFmt = DateFormat('MMM');

    for (var i = 0; i < n; i++) {
      final m = months[i];
      final isCurrent = m.month.year == now.year && m.month.month == now.month;
      final h = yMax <= 0 ? 0.0 : (m.total / yMax) * chartH;
      final cx = leftGutter + slot * i + slot / 2;
      final left = cx - barW / 2;
      final top = topPad + chartH - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barW, math.max(h, 0)),
        const Radius.circular(5),
      );
      final barPaint = Paint()
        ..color = isCurrent
            ? const Color(0xFF64B5F6)
            : const Color(0xFF2196F3).withValues(alpha: 0.85);
      canvas.drawRRect(rect, barPaint);

      // Month label
      final label = monthFmt.format(m.month);
      final ltp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0x8CFFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      ltp.paint(
        canvas,
        Offset(cx - ltp.width / 2, size.height - bottomGutter + 6),
      );

      // Current-month value callout
      if (isCurrent && m.total > 0) {
        final vLabel = formatDashboardMoney(m.total);
        final vtp = TextPainter(
          text: TextSpan(
            text: vLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64B5F6),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        vtp.paint(canvas, Offset(cx - vtp.width / 2, top - vtp.height - 2));
      }
    }
  }

  static double _niceMax(double v) {
    if (v <= 0) return 150;
    final exp = (math.log(v) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    final n = (v / base).ceilToDouble();
    final step = n <= 1
        ? 1.0
        : n <= 2
            ? 2.0
            : n <= 5
                ? 5.0
                : 10.0;
    return step * base;
  }

  static String _axisLabel(double v) {
    if (v >= 1000) {
      return '\$${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    }
    return '\$${v.round()}';
  }

  /// Returns the month under [localPos], or null if outside a bar slot.
  static DateTime? hitTestMonth(
    Offset localPos,
    Size size,
    List<MonthlyExpenseTotal> months,
  ) {
    if (months.isEmpty) return null;
    const leftGutter = 36.0;
    if (localPos.dx < leftGutter) return null;
    final chartW = size.width - leftGutter;
    final n = months.length;
    final slot = chartW / n;
    final index = ((localPos.dx - leftGutter) / slot).floor();
    if (index < 0 || index >= n) return null;
    return months[index].month;
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarsPainter oldDelegate) =>
      oldDelegate.months != months || oldDelegate.now != now;
}

// ─── Monthly sold/listed ────────────────────────────────────────────────────

class _MonthlyInventoryCard extends StatelessWidget {
  const _MonthlyInventoryCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.currentColor,
    required this.months,
    this.onMonthTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Color currentColor;
  final List<MonthlyInventoryCount>? months;
  final ValueChanged<DateTime>? onMonthTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = months ??
        [
          for (var i = 5; i >= 0; i--)
            MonthlyInventoryCount(
              month: DateTime(now.year, now.month - i, 1),
              count: 0,
            ),
        ];
    final yearLabel =
        data.isNotEmpty ? '${data.last.month.year}' : '${now.year}';

    return _DashCard(
      title: title,
      badge: 'Counts · $yearLabel',
      subtitle: subtitle,
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onMonthTap == null
                  ? null
                  : (details) {
                      final month = _MonthlyInventoryBarsPainter.hitTestMonth(
                        details.localPosition,
                        constraints.biggest,
                        data,
                      );
                      if (month != null) onMonthTap!(month);
                    },
              child: CustomPaint(
                painter: _MonthlyInventoryBarsPainter(
                  months: data,
                  now: now,
                  color: color,
                  currentColor: currentColor,
                ),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MonthlyInventoryBarsPainter extends CustomPainter {
  _MonthlyInventoryBarsPainter({
    required this.months,
    required this.now,
    required this.color,
    required this.currentColor,
  });

  final List<MonthlyInventoryCount> months;
  final DateTime now;
  final Color color;
  final Color currentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    const leftGutter = 36.0;
    const bottomGutter = 28.0;
    const topPad = 16.0;
    final chartW = size.width - leftGutter;
    final chartH = size.height - bottomGutter - topPad;
    final maxVal = months.map((m) => m.count).fold<int>(0, math.max);
    final yMax = maxVal <= 0 ? 1 : _niceMax(maxVal);

    final gridPaint = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 1;
    final baselinePaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;

    for (final t in [0.0, 0.5, 1.0]) {
      final y = topPad + chartH * (1 - t);
      canvas.drawLine(
        Offset(leftGutter, y),
        Offset(size.width, y),
        t == 0 ? baselinePaint : gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${(yMax * t).round()}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0x80FFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: leftGutter - 6);
      tp.paint(canvas, Offset(leftGutter - 6 - tp.width, y - tp.height / 2));
    }

    final n = months.length;
    final slot = chartW / n;
    final barW = math.min(32.0, slot * 0.55);
    final monthFmt = DateFormat('MMM');

    for (var i = 0; i < n; i++) {
      final month = months[i];
      final isCurrent =
          month.month.year == now.year && month.month.month == now.month;
      final h = (month.count / yMax) * chartH;
      final cx = leftGutter + slot * i + slot / 2;
      final left = cx - barW / 2;
      final top = topPad + chartH - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barW, math.max(h, 0)),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isCurrent ? currentColor : color.withValues(alpha: 0.85),
      );

      final ltp = TextPainter(
        text: TextSpan(
          text: monthFmt.format(month.month),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0x8CFFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      ltp.paint(
        canvas,
        Offset(cx - ltp.width / 2, size.height - bottomGutter + 6),
      );

      if (isCurrent && month.count > 0) {
        final vtp = TextPainter(
          text: TextSpan(
            text: '${month.count}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: currentColor,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        vtp.paint(canvas, Offset(cx - vtp.width / 2, top - vtp.height - 2));
      }
    }
  }

  static int _niceMax(int value) {
    if (value <= 1) return 1;
    final exp = (math.log(value) / math.ln10).floor();
    final base = math.pow(10, exp).toInt();
    final n = (value / base).ceil();
    final step = n <= 1
        ? 1
        : n <= 2
            ? 2
            : n <= 5
                ? 5
                : 10;
    return step * base;
  }

  /// Returns the month under [localPos], or null if outside a bar slot.
  static DateTime? hitTestMonth(
    Offset localPos,
    Size size,
    List<MonthlyInventoryCount> months,
  ) {
    if (months.isEmpty) return null;
    const leftGutter = 36.0;
    if (localPos.dx < leftGutter) return null;
    final chartW = size.width - leftGutter;
    final n = months.length;
    final slot = chartW / n;
    final index = ((localPos.dx - leftGutter) / slot).floor();
    if (index < 0 || index >= n) return null;
    return months[index].month;
  }

  @override
  bool shouldRepaint(covariant _MonthlyInventoryBarsPainter oldDelegate) =>
      oldDelegate.months != months ||
      oldDelegate.now != now ||
      oldDelegate.color != color ||
      oldDelegate.currentColor != currentColor;
}

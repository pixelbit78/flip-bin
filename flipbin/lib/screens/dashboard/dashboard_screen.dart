import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/providers/dashboard_provider.dart';

/// Home dashboard — Option C (sell-through) matching the approved mockup.
///
/// Section order: KPIs → quick actions → aging capital → sell-through →
/// monthly expenses → top movers. Bottom nav lives in [ShellRoute].
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _bg = Color(0xFF1A1D23);
  static const _card = Color(0xFF252830);
  static const _accent = Color(0xFF2196F3);
  static const _teal = Color(0xFF00BCD4);
  static const _aging = Color(0xFFFFB74D);
  static const _green = Color(0xFF4CAF50);
  static const _muted = Color(0x8AFFFFFF); // white54

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avgDaysAsync = ref.watch(avgDaysToSellProvider);
    final agingAsync = ref.watch(agingCapitalProvider);
    final totalCostAsync = ref.watch(activeTotalCostTimesQtyProvider);
    final bucketsAsync = ref.watch(agingBucketsProvider);
    final sellThroughAsync = ref.watch(sellThroughProvider);
    final monthsAsync = ref.watch(monthlyExpensesProvider);
    final moversAsync = ref.watch(topMoversProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'FlipBin',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Color(0xB3FFFFFF)),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiRow(
              avgDaysLabel: formatAvgDays(avgDaysAsync.valueOrNull),
              agingLabel: formatDashboardMoney(
                agingAsync.valueOrNull?.totalCostTimesQty ?? 0,
              ),
              agingSubtitle:
                  '${agingAsync.valueOrNull?.itemCount ?? 0} · 30d+',
              totalCostLabel: formatDashboardMoney(
                totalCostAsync.valueOrNull ?? 0,
              ),
            ),
            const SizedBox(height: 6),
            const _QuickActionsRow(),
            const SizedBox(height: 8),
            _AgingCapitalCard(buckets: bucketsAsync.valueOrNull),
            const SizedBox(height: 6),
            _SellThroughCard(metrics: sellThroughAsync.valueOrNull),
            const SizedBox(height: 6),
            _MonthlyExpensesCard(months: monthsAsync.valueOrNull),
            const SizedBox(height: 6),
            _TopMoversCard(movers: moversAsync.valueOrNull),
          ],
        ),
      ),
    );
  }
}

// ─── KPI row ────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.avgDaysLabel,
    required this.agingLabel,
    required this.agingSubtitle,
    required this.totalCostLabel,
  });

  final String avgDaysLabel;
  final String agingLabel;
  final String agingSubtitle;
  final String totalCostLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Avg days to sell',
            value: avgDaysLabel,
            valueColor: DashboardScreen._teal,
            subtitle: 'on Sold items',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _KpiCard(
            label: 'Aging capital',
            value: agingLabel,
            valueColor: DashboardScreen._aging,
            subtitle: agingSubtitle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _KpiCard(
            label: 'Total cost',
            value: totalCostLabel,
            valueColor: DashboardScreen._accent,
            subtitle: 'Active · cost×qty',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              fontSize: 10,
              color: DashboardScreen._muted,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
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
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            label: 'Add Item',
            icon: Icons.add,
            color: const Color(0xFF2E7D32),
            onTap: () => context.go('/inventory/new'),
          ),
        ),
        const SizedBox(width: 8),
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
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xD9FFFFFF),
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
  });

  final String title;
  final String badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x0FFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    color: DashboardScreen._muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
            if (i > 0) const SizedBox(height: 6),
            _AgingRow(
              bucket: data.asList[i],
              color: _colors[i],
              maxAmount: maxAmt,
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
  });

  final AgingBucket bucket;
  final Color color;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxAmount <= 0 ? 0.0 : (bucket.totalCostTimesQty / maxAmount).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            bucket.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xB3FFFFFF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: const Color(0x14FFFFFF)),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDashboardMoney(bucket.totalCostTimesQty),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xD9FFFFFF),
                ),
              ),
              Text(
                '${bucket.itemCount} items',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: DashboardScreen._muted,
                ),
              ),
            ],
          ),
        ),
      ],
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

    return _DashCard(
      title: 'Sell-through',
      badge: '${m.windowDays} days',
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: _SellThroughRingPainter(rate: m.rate),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: DashboardScreen._green,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'sold',
                      style: TextStyle(
                        fontSize: 10,
                        color: DashboardScreen._muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                _StStat(label: 'Listed', value: '${m.listed}'),
                const Divider(height: 1, color: Color(0x0FFFFFFF)),
                _StStat(
                  label: 'Sold',
                  value: '${m.sold}',
                  valueColor: DashboardScreen._green,
                ),
                const Divider(height: 1, color: Color(0x0FFFFFFF)),
                _StStat(label: 'Still active', value: '${m.stillActive}'),
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
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: DashboardScreen._muted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellThroughRingPainter extends CustomPainter {
  _SellThroughRingPainter({required this.rate});

  final double rate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.1;
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
    final yearLabel = data.isNotEmpty
        ? '${data.last.month.year}'
        : '${now.year}';

    return _DashCard(
      title: 'Monthly expenses',
      badge: yearLabel,
      child: SizedBox(
        height: 96,
        child: CustomPaint(
          painter: _MonthlyBarsPainter(months: data, now: now),
          child: const SizedBox.expand(),
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

    const leftGutter = 28.0;
    const bottomGutter = 18.0;
    const topPad = 14.0;
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
            fontSize: 9,
            color: Color(0x66FFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: leftGutter - 4);
      tp.paint(canvas, Offset(leftGutter - 4 - tp.width, y - tp.height / 2));
    }

    final n = months.length;
    final slot = chartW / n;
    final barW = math.min(28.0, slot * 0.55);
    final monthFmt = DateFormat('MMM');

    for (var i = 0; i < n; i++) {
      final m = months[i];
      final isCurrent =
          m.month.year == now.year && m.month.month == now.month;
      final h = yMax <= 0 ? 0.0 : (m.total / yMax) * chartH;
      final cx = leftGutter + slot * i + slot / 2;
      final left = cx - barW / 2;
      final top = topPad + chartH - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barW, math.max(h, 0)),
        const Radius.circular(4),
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
            fontSize: 10,
            color: Color(0x73FFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      ltp.paint(
        canvas,
        Offset(cx - ltp.width / 2, size.height - bottomGutter + 4),
      );

      // Current-month value callout
      if (isCurrent && m.total > 0) {
        final vLabel = formatDashboardMoney(m.total);
        final vtp = TextPainter(
          text: TextSpan(
            text: vLabel,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
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
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return '\$${v.round()}';
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarsPainter oldDelegate) =>
      oldDelegate.months != months || oldDelegate.now != now;
}

// ─── Top movers ─────────────────────────────────────────────────────────────

class _TopMoversCard extends StatelessWidget {
  const _TopMoversCard({required this.movers});

  final List<InventoryItem>? movers;

  @override
  Widget build(BuildContext context) {
    final list = movers ?? const <InventoryItem>[];

    return _DashCard(
      title: 'Top movers',
      badge: 'Fastest sold',
      child: list.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No sold items yet',
                style: TextStyle(
                  fontSize: 12,
                  color: DashboardScreen._muted,
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: Color(0x0FFFFFFF)),
                  _MoverRow(rank: i + 1, item: list[i]),
                ],
              ],
            ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  const _MoverRow({required this.rank, required this.item});

  final int rank;
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final days = item.daysToSell ?? 0;
    final costLabel = formatDashboardMoney(item.cost);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x2E2196F3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: DashboardScreen._accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    _MoverTypeBadge(type: item.type),
                    Text(
                      ' · cost $costLabel',
                      style: const TextStyle(
                        fontSize: 10,
                        color: DashboardScreen._muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${days}d',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DashboardScreen._teal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoverTypeBadge extends StatelessWidget {
  const _MoverTypeBadge({required this.type});

  final ItemType type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsFor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  static (Color, Color) _colorsFor(ItemType type) {
    switch (type) {
      case ItemType.dvd:
      case ItemType.bluray:
        return (const Color(0x2E2196F3), const Color(0xFF64B5F6));
      case ItemType.book:
        return (const Color(0x2EFF9800), const Color(0xFFFFB74D));
      case ItemType.game:
        return (const Color(0x2E4CAF50), const Color(0xFF81C784));
      case ItemType.cd:
        return (const Color(0x2E00BCD4), const Color(0xFF4DD0E1));
      case ItemType.other:
        return (const Color(0x2E9E9E9E), const Color(0xFFBDBDBD));
    }
  }
}

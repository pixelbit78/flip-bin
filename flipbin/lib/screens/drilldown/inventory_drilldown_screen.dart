import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flipbin/models/drilldown_query.dart';
import 'package:flipbin/providers/inventory_provider.dart';
import 'package:flipbin/utils/default_cover.dart';
import 'package:flipbin/widgets/status_badge.dart';
import 'package:flipbin/widgets/type_badge.dart';

/// Home-originated inventory drill-down: filter chips + cost-only list.
///
/// No search, no FAB. Bottom nav stays on Home via `/drilldown/inventory`.
class InventoryDrillDownScreen extends ConsumerStatefulWidget {
  const InventoryDrillDownScreen({super.key, required this.initialQuery});

  final DrillDownQuery initialQuery;

  @override
  ConsumerState<InventoryDrillDownScreen> createState() =>
      _InventoryDrillDownScreenState();
}

class _InventoryDrillDownScreenState
    extends ConsumerState<InventoryDrillDownScreen> {
  static const _bg = Color(0xFF1A1D23);
  static const _card = Color(0xFF252830);

  late DrillDownQuery _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  void didUpdateWidget(covariant InventoryDrillDownScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _query = widget.initialQuery;
    }
  }

  void _clearChip(String chipId) {
    final next = _query.clearingChip(chipId);
    if (next == null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return;
    }
    setState(() => _query = next);
    // Keep URL in sync without stacking another route.
    context.go(_query.toLocation(path: '/drilldown/inventory'));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = InventoryFilter.fromDrillDown(_query);
    final itemsAsync = ref.watch(inventoryListProvider(filter));
    final dateFmt = DateFormat('MMM d');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          tooltip: 'Home',
          onPressed: _goBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _query.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            itemsAsync.when(
              data: (items) {
                final cost = items.fold<double>(0, (s, i) => s + i.cost);
                final subtitle = _subtitleFor(items.length, cost);
                return Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w400,
                  ),
                );
              },
              loading: () => const Text(
                '…',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_query.chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in _query.chips)
                    _RemovableFilterChip(
                      label: chip.label,
                      onDeleted: () => _clearChip(chip.id),
                    ),
                ],
              ),
            ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final metaDate = item.dateSold ?? item.dateAdded;
                    return Card(
                      color: _card,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/inventory/${item.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ItemCoverImage(
                                imageUrl: item.imageUrl,
                                type: item.type,
                                width: 56,
                                height: 56,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemDescription,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        TypeBadge(type: item.type),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: item.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${item.cost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFmt.format(metaDate),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(int count, double cost) {
    if (_query.soldWithinDays != null || _query.addedWithinDays != null) {
      final days = _query.soldWithinDays ?? _query.addedWithinDays ?? 90;
      return '$count items · last $days days';
    }
    if (_query.soldMonth != null) {
      return '$count items · dateSold in ${DrillDownQuery.monthChipLabel(_query.soldMonth!)}';
    }
    if (_query.addedMonth != null) {
      return '$count items · dateAdded in ${DrillDownQuery.monthChipLabel(_query.addedMonth!)}';
    }
    if (_query.ageMinDays != null) {
      return '$count items · \$${cost.toStringAsFixed(0)} cost';
    }
    return '$count items';
  }
}

class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  static const _accent = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onDeleted,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

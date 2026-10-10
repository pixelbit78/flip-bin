// Review lots (SPEC §4.3): one-time, optional. Suggests qty from the
// description; nothing applies without confirmation; cost (line total) is
// never changed — only qty and cost per item = round4(cost / qty).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flipbin/config/env.dart';
import 'package:flipbin/database/database.dart';
import 'package:flipbin/providers/database_provider.dart';
import 'package:flipbin/providers/sync_provider.dart';
import 'package:flipbin/services/backends/local_file_backend.dart';
import 'package:flipbin/utils/cost_field.dart';

final String _kDismissed = Env.prefsKey('flipbin.lots.dismissed');

/// Settings entry card.
class ReviewLotsCard extends StatelessWidget {
  const ReviewLotsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: const Key('reviewLotsEntry'),
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Review lots'),
        subtitle: const Text(
            'Set quantity on rows like "17 comics". Totals never change.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/settings/lots'),
      ),
    );
  }
}

class LotReviewScreen extends ConsumerStatefulWidget {
  const LotReviewScreen({super.key});

  @override
  ConsumerState<LotReviewScreen> createState() => _LotReviewScreenState();
}

class _LotReviewScreenState extends ConsumerState<LotReviewScreen> {
  List<LotSuggestion>? _rows;
  final Map<int, int> _qty = {};
  Set<String> _dismissed = {};
  bool _backedUp = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissed = (prefs.getStringList(_kDismissed) ?? const []).toSet();
    final all =
        await ref.read(databaseProvider).inventoryItemsDao.lotSuggestions();
    if (!mounted) return;
    setState(() {
      _rows = all.where((s) => !_dismissed.contains('${s.item.id}')).toList();
      for (final s in _rows!) {
        _qty.putIfAbsent(s.item.id, () => s.suggestedQty);
      }
    });
  }

  /// Backup required before anything applies (SPEC §4.2/§4.3).
  Future<bool> _backup() async {
    if (_backedUp) return true;
    try {
      if (kIsProd) {
        final notifier = ref.read(syncProvider.notifier);
        await notifier.export();
        final st = ref.read(syncProvider);
        if (st.error != null || st.needsReauth || !st.isSignedIn) {
          _snack('Backup to Google Sheets failed — sign in and export first.');
          return false;
        }
      } else {
        await const LocalFileBackend().export(ref.read(databaseProvider));
      }
      _backedUp = true;
      return true;
    } catch (e) {
      _snack('Backup failed: $e');
      return false;
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _apply(List<LotSuggestion> targets) async {
    if (targets.isEmpty || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(targets.length == 1
            ? 'Set qty ${_qty[targets.first.item.id]}?'
            : 'Apply ${targets.length} lots?'),
        content: const Text(
            'A backup is taken first. Totals stay exactly the same; only the '
            'quantity and cost per item change.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      if (!await _backup()) return;
      final dao = ref.read(databaseProvider).inventoryItemsDao;
      var before = 0.0, after = 0.0, unitsBefore = 0, unitsAfter = 0;
      for (final t in targets) {
        final n = _qty[t.item.id] ?? t.suggestedQty;
        await dao.applyLotQty(t.item.id, n);
        final fresh = await dao.getById(t.item.id);
        before += t.item.cost;
        after += fresh.cost;
        unitsBefore += t.item.quantity;
        unitsAfter += fresh.quantity;
      }
      _snack('Updated ${targets.length} rows · cost \$${before.toStringAsFixed(2)}'
          ' → \$${after.toStringAsFixed(2)} · units $unitsBefore → $unitsAfter');
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss(LotSuggestion s) async {
    final prefs = await SharedPreferences.getInstance();
    _dismissed.add('${s.item.id}');
    await prefs.setStringList(_kDismissed, _dismissed.toList());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review lots'),
        actions: [
          if (rows != null && rows.isNotEmpty)
            TextButton(
              key: const Key('lotsApplyAll'),
              onPressed: _busy ? null : () => _apply(rows),
              child: const Text('Apply all'),
            ),
        ],
      ),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(
                  child: Text('No lots to review',
                      style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final s = rows[i];
                    final n = _qty[s.item.id] ?? s.suggestedQty;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.item.itemDescription,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Total \$${s.item.cost.toStringAsFixed(2)} · '
                              '${formatEach(cpiFromTotal(s.item.cost, n))} at qty $n',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            Row(children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: n > 2
                                    ? () => setState(() => _qty[s.item.id] = n - 1)
                                    : null,
                              ),
                              Text('$n',
                                  key: Key('lotQty-${s.item.id}'),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: n < kMaxQty
                                    ? () => setState(() => _qty[s.item.id] = n + 1)
                                    : null,
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _busy ? null : () => _dismiss(s),
                                child: const Text('Not a lot'),
                              ),
                              FilledButton(
                                key: Key('lotApply-${s.item.id}'),
                                onPressed: _busy ? null : () => _apply([s]),
                                child: Text('Set qty $n'),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

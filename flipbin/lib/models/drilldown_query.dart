import 'package:flipbin/models/enums.dart';
import 'package:intl/intl.dart';

/// Parsed Home chart → filtered-list drill-down query (go_router query params).
///
/// Authoritative filter map: ux-mockups/home-dashboard/drilldown/README.md
class DrillDownQuery {
  /// Screen title, e.g. `Aging · 30–59d`, `Sell-through · Sold`.
  final String title;

  /// Inventory status filter (Active / Sold). Null = any status.
  final ItemStatus? status;

  /// Inclusive age band in days (Active aging capital).
  final int? ageMinDays;
  final int? ageMaxDays;

  /// Trailing window in days for `dateSold` (sell-through Sold).
  final int? soldWithinDays;

  /// Trailing window in days for `dateAdded` (sell-through Listed / Still active).
  final int? addedWithinDays;

  /// Calendar month for `dateSold` (monthly sold bars), day=1.
  final DateTime? soldMonth;

  /// Calendar month for `dateAdded` (monthly listed bars), day=1.
  final DateTime? addedMonth;

  /// Whether the removable "Listed" chip is shown (dateAdded-month / window label,
  /// not an [ItemStatus]).
  final bool listedChip;

  /// Whether the removable "90 days" (or N days) window chip is shown.
  final bool windowChip;

  /// Whether the age-band chip (e.g. `30–59d`) is shown.
  final bool ageBandChip;

  /// Whether the month chip (e.g. `Sep 2026`) is shown.
  final bool monthChip;

  const DrillDownQuery({
    required this.title,
    this.status,
    this.ageMinDays,
    this.ageMaxDays,
    this.soldWithinDays,
    this.addedWithinDays,
    this.soldMonth,
    this.addedMonth,
    this.listedChip = false,
    this.windowChip = false,
    this.ageBandChip = false,
    this.monthChip = false,
  });

  /// Parse query parameters from a go_router location.
  factory DrillDownQuery.fromQueryParameters(Map<String, String> params) {
    ItemStatus? status;
    final statusRaw = params['status'];
    if (statusRaw != null && statusRaw.isNotEmpty) {
      status = ItemStatus.fromLabel(statusRaw);
    }

    int? parseInt(String key) {
      final raw = params[key];
      if (raw == null || raw.isEmpty) return null;
      return int.tryParse(raw);
    }

    DateTime? parseMonth(String key) {
      final raw = params[key];
      if (raw == null || raw.isEmpty) return null;
      final parts = raw.split('-');
      if (parts.length < 2) return null;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y == null || m == null) return null;
      return DateTime(y, m, 1);
    }

    final title = params['title']?.isNotEmpty == true
        ? params['title']!
        : 'Filtered';

    return DrillDownQuery(
      title: title,
      status: status,
      ageMinDays: parseInt('ageMin'),
      ageMaxDays: parseInt('ageMax'),
      soldWithinDays: parseInt('soldWithinDays'),
      addedWithinDays: parseInt('addedWithinDays'),
      soldMonth: parseMonth('soldMonth'),
      addedMonth: parseMonth('addedMonth'),
      listedChip: params['listedChip'] == '1',
      windowChip: params['windowChip'] == '1',
      ageBandChip: params['ageBandChip'] == '1',
      monthChip: params['monthChip'] == '1',
    );
  }

  /// Serialize to query parameters (values are already URI-safe via Uri).
  Map<String, String> toQueryParameters() {
    final map = <String, String>{'title': title};
    if (status != null) map['status'] = status!.label;
    if (ageMinDays != null) map['ageMin'] = '$ageMinDays';
    if (ageMaxDays != null) map['ageMax'] = '$ageMaxDays';
    if (soldWithinDays != null) map['soldWithinDays'] = '$soldWithinDays';
    if (addedWithinDays != null) map['addedWithinDays'] = '$addedWithinDays';
    if (soldMonth != null) {
      map['soldMonth'] = _monthKey(soldMonth!);
    }
    if (addedMonth != null) {
      map['addedMonth'] = _monthKey(addedMonth!);
    }
    if (listedChip) map['listedChip'] = '1';
    if (windowChip) map['windowChip'] = '1';
    if (ageBandChip) map['ageBandChip'] = '1';
    if (monthChip) map['monthChip'] = '1';
    return map;
  }

  String toLocation({required String path}) {
    final uri = Uri(path: path, queryParameters: toQueryParameters());
    return uri.toString();
  }

  bool get hasActiveFilters {
    return status != null ||
        ageMinDays != null ||
        ageMaxDays != null ||
        soldWithinDays != null ||
        addedWithinDays != null ||
        soldMonth != null ||
        addedMonth != null ||
        listedChip ||
        windowChip ||
        ageBandChip ||
        monthChip;
  }

  /// Removable chips currently shown (id → label).
  List<DrillDownChip> get chips {
    final result = <DrillDownChip>[];
    if (status != null) {
      result.add(DrillDownChip(id: 'status', label: status!.label));
    }
    if (listedChip) {
      result.add(const DrillDownChip(id: 'listed', label: 'Listed'));
    }
    if (ageBandChip && (ageMinDays != null || ageMaxDays != null)) {
      result.add(DrillDownChip(id: 'ageBand', label: ageBandLabel));
    }
    if (windowChip) {
      final days = soldWithinDays ?? addedWithinDays ?? 90;
      result.add(DrillDownChip(id: 'window', label: '$days days'));
    }
    if (monthChip) {
      final month = soldMonth ?? addedMonth;
      if (month != null) {
        result.add(DrillDownChip(id: 'month', label: monthChipLabel(month)));
      }
    }
    return result;
  }

  String get ageBandLabel {
    if (ageMinDays != null && ageMaxDays != null) {
      return '$ageMinDays–${ageMaxDays}d';
    }
    if (ageMinDays != null) return '${ageMinDays}d+';
    if (ageMaxDays != null) return '≤${ageMaxDays}d';
    return 'Age';
  }

  static String monthChipLabel(DateTime month) =>
      DateFormat('MMM yyyy').format(month);

  static String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  /// Clear one chip; returns null when no filters remain (caller should pop).
  DrillDownQuery? clearingChip(String chipId) {
    var next = this;
    switch (chipId) {
      case 'status':
        next = copyWith(clearStatus: true);
        break;
      case 'listed':
        next = copyWith(listedChip: false, clearAddedMonth: true, clearAddedWithin: true);
        break;
      case 'ageBand':
        next = copyWith(
          ageBandChip: false,
          clearAgeMin: true,
          clearAgeMax: true,
        );
        break;
      case 'window':
        next = copyWith(
          windowChip: false,
          clearSoldWithin: true,
          clearAddedWithin: true,
        );
        break;
      case 'month':
        next = copyWith(
          monthChip: false,
          clearSoldMonth: true,
          clearAddedMonth: true,
        );
        break;
      default:
        break;
    }
    if (!next.hasActiveFilters) return null;
    // If only decorative flags remain without real filters, treat as empty.
    final hasReal = next.status != null ||
        next.ageMinDays != null ||
        next.ageMaxDays != null ||
        next.soldWithinDays != null ||
        next.addedWithinDays != null ||
        next.soldMonth != null ||
        next.addedMonth != null;
    if (!hasReal) return null;
    return next;
  }

  DrillDownQuery copyWith({
    String? title,
    ItemStatus? status,
    bool clearStatus = false,
    int? ageMinDays,
    bool clearAgeMin = false,
    int? ageMaxDays,
    bool clearAgeMax = false,
    int? soldWithinDays,
    bool clearSoldWithin = false,
    int? addedWithinDays,
    bool clearAddedWithin = false,
    DateTime? soldMonth,
    bool clearSoldMonth = false,
    DateTime? addedMonth,
    bool clearAddedMonth = false,
    bool? listedChip,
    bool? windowChip,
    bool? ageBandChip,
    bool? monthChip,
  }) {
    return DrillDownQuery(
      title: title ?? this.title,
      status: clearStatus ? null : (status ?? this.status),
      ageMinDays: clearAgeMin ? null : (ageMinDays ?? this.ageMinDays),
      ageMaxDays: clearAgeMax ? null : (ageMaxDays ?? this.ageMaxDays),
      soldWithinDays:
          clearSoldWithin ? null : (soldWithinDays ?? this.soldWithinDays),
      addedWithinDays:
          clearAddedWithin ? null : (addedWithinDays ?? this.addedWithinDays),
      soldMonth: clearSoldMonth ? null : (soldMonth ?? this.soldMonth),
      addedMonth: clearAddedMonth ? null : (addedMonth ?? this.addedMonth),
      listedChip: listedChip ?? this.listedChip,
      windowChip: windowChip ?? this.windowChip,
      ageBandChip: ageBandChip ?? this.ageBandChip,
      monthChip: monthChip ?? this.monthChip,
    );
  }

  // ─── Factory helpers for Home chart taps ─────────────────────────────────

  static DrillDownQuery aging({required int minDays, required int maxDays}) {
    return DrillDownQuery(
      title: 'Aging · $minDays–${maxDays}d',
      status: ItemStatus.active,
      ageMinDays: minDays,
      ageMaxDays: maxDays,
      ageBandChip: true,
    );
  }

  static DrillDownQuery sellThroughSold({int windowDays = 90}) {
    return DrillDownQuery(
      title: 'Sell-through · Sold',
      status: ItemStatus.sold,
      soldWithinDays: windowDays,
      windowChip: true,
    );
  }

  static DrillDownQuery sellThroughListed({int windowDays = 90}) {
    return DrillDownQuery(
      title: 'Sell-through · Listed',
      addedWithinDays: windowDays,
      listedChip: true,
      windowChip: true,
    );
  }

  static DrillDownQuery sellThroughStillActive({int windowDays = 90}) {
    return DrillDownQuery(
      title: 'Sell-through · Still active',
      status: ItemStatus.active,
      addedWithinDays: windowDays,
      windowChip: true,
    );
  }

  static DrillDownQuery monthlySold(DateTime month) {
    final m = DateTime(month.year, month.month, 1);
    return DrillDownQuery(
      title: 'Sold · ${monthChipLabel(m)}',
      status: ItemStatus.sold,
      soldMonth: m,
      monthChip: true,
    );
  }

  static DrillDownQuery monthlyListed(DateTime month) {
    final m = DateTime(month.year, month.month, 1);
    return DrillDownQuery(
      title: 'Listed · ${monthChipLabel(m)}',
      addedMonth: m,
      listedChip: true,
      monthChip: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrillDownQuery &&
          title == other.title &&
          status == other.status &&
          ageMinDays == other.ageMinDays &&
          ageMaxDays == other.ageMaxDays &&
          soldWithinDays == other.soldWithinDays &&
          addedWithinDays == other.addedWithinDays &&
          soldMonth == other.soldMonth &&
          addedMonth == other.addedMonth &&
          listedChip == other.listedChip &&
          windowChip == other.windowChip &&
          ageBandChip == other.ageBandChip &&
          monthChip == other.monthChip;

  @override
  int get hashCode => Object.hash(
        title,
        status,
        ageMinDays,
        ageMaxDays,
        soldWithinDays,
        addedWithinDays,
        soldMonth,
        addedMonth,
        listedChip,
        windowChip,
        ageBandChip,
        monthChip,
      );
}

class DrillDownChip {
  final String id;
  final String label;

  const DrillDownChip({required this.id, required this.label});
}

/// Expense drill-down: filter by `expenseDate` calendar month.
class ExpenseDrillDownQuery {
  final String title;
  final DateTime month;

  const ExpenseDrillDownQuery({required this.title, required this.month});

  factory ExpenseDrillDownQuery.fromQueryParameters(
    Map<String, String> params,
  ) {
    final raw = params['month'] ?? '';
    final parts = raw.split('-');
    final y = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final month = (y != null && m != null)
        ? DateTime(y, m, 1)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    final title = params['title']?.isNotEmpty == true
        ? params['title']!
        : 'Expenses · ${DrillDownQuery.monthChipLabel(month)}';
    return ExpenseDrillDownQuery(title: title, month: month);
  }

  factory ExpenseDrillDownQuery.forMonth(DateTime month) {
    final m = DateTime(month.year, month.month, 1);
    return ExpenseDrillDownQuery(
      title: 'Expenses · ${DrillDownQuery.monthChipLabel(m)}',
      month: m,
    );
  }

  Map<String, String> toQueryParameters() => {
        'title': title,
        'month':
            '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
      };

  String toLocation({String path = '/drilldown/expenses'}) {
    return Uri(path: path, queryParameters: toQueryParameters()).toString();
  }

  String get monthChipLabel => DrillDownQuery.monthChipLabel(month);
}

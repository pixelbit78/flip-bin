import 'package:flutter/material.dart';
import 'package:flipbin/models/enums.dart';

/// Colored status badge chip for an inventory item (green=Active, orange=Sold, blue=Personal).
///
/// When [onTap] is set, the badge becomes tappable with opaque hit testing so
/// parent row InkWells do not also fire.
class StatusBadge extends StatelessWidget {
  final ItemStatus status;
  final VoidCallback? onTap;

  const StatusBadge({super.key, required this.status, this.onTap});

  Color _getColor() {
    switch (status) {
      case ItemStatus.active:
        return Colors.green;
      case ItemStatus.sold:
        return Colors.orange;
      case ItemStatus.personal:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    // Own semantics node (container) so it is never merged into the
    // surrounding row's label/tap action.
    if (onTap == null) {
      return Semantics(
        container: true,
        label: 'Status ${status.label}',
        excludeSemantics: true,
        child: badge,
      );
    }

    // L-02: keep the badge's visual size but give it a 44×44 hit area, and
    // expose it as its own button so screen readers reach the sell action.
    return Semantics(
      container: true,
      button: true,
      label: 'Status ${status.label}, tap to mark sold',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(widthFactor: 1, child: badge),
        ),
      ),
    );
  }
}

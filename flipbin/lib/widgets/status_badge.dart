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

    if (onTap == null) return badge;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: badge,
    );
  }
}

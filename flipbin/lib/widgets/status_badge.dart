import 'package:flutter/material.dart';
import 'package:flipbin/models/enums.dart';

/// Colored status badge chip for an inventory item (green=Active, orange=Sold, blue=Personal).
class StatusBadge extends StatelessWidget {
  final ItemStatus status;

  const StatusBadge({super.key, required this.status});

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
    return Container(
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
  }
}

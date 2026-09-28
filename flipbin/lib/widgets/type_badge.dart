import 'package:flutter/material.dart';
import 'package:flipbin/models/enums.dart';

/// Type badge chip for an inventory item with teal color theme.
class TypeBadge extends StatelessWidget {
  final ItemType type;

  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    const color = Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        type.label,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

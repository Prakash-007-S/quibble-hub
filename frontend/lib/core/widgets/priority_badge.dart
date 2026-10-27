import 'package:flutter/material.dart';
import '../../app/theme.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  Color _getColor() {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return AppTheme.priorityCritical;
      case 'HIGH':
        return AppTheme.priorityHigh;
      case 'MEDIUM':
        return AppTheme.priorityMedium;
      case 'LOW':
        return AppTheme.priorityLow;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getIcon() {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return Icons.warning_rounded;
      case 'HIGH':
        return Icons.arrow_upward_rounded;
      case 'MEDIUM':
        return Icons.drag_handle_rounded;
      case 'LOW':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

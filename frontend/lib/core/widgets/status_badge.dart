import 'package:flutter/material.dart';
import '../../app/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isSmall;

  const StatusBadge({super.key, required this.status, this.isSmall = false});

  Color _getColor() {
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
        return AppTheme.statusSubmitted;
      case 'ASSIGNED':
        return AppTheme.statusAssigned;
      case 'IN_PROGRESS':
        return AppTheme.statusInProgress;
      case 'AWAITING_USER':
        return AppTheme.statusAwaiting;
      case 'RESOLVED':
        return AppTheme.statusResolved;
      case 'CLOSED':
        return AppTheme.statusClosed;
      case 'REJECTED':
        return AppTheme.statusRejected;
      case 'REOPENED':
        return AppTheme.statusReopened;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getLabel() {
    return status.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmall ? 5 : 6,
            height: isSmall ? 5 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _getLabel(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: isSmall ? 10.5 : 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

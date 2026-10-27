import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/complaint_provider.dart';
import '../../core/widgets/state_views.dart';
import '../complaints/complaint_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<ComplaintProvider>(context, listen: false).fetchNotifications(auth.currentUser?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final complaintProv = Provider.of<ComplaintProvider>(context);
    final notifs = complaintProv.notifications;
    final dateFormat = DateFormat('MMM d • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final horizontalPadding = isWide ? (constraints.maxWidth - 700) / 2 : 16.0;

          return RefreshIndicator(
            onRefresh: () => complaintProv.fetchNotifications(auth.currentUser?.id),
            child: notifs.isEmpty
                ? const EmptyStateView(
                    icon: Icons.notifications_off_outlined,
                    title: 'All Caught Up',
                    message: 'No notifications or status alerts right now.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                itemCount: notifs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final n = notifs[idx];
                  return Card(
                    color: n.isRead ? Colors.white : AppTheme.primaryLight.withValues(alpha: 0.4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: n.isRead ? AppTheme.borderLight : AppTheme.primary,
                        foregroundColor: n.isRead ? AppTheme.textSecondary : Colors.white,
                        child: Icon(
                          n.notificationType == 'SLA_BREACH'
                              ? Icons.alarm_rounded
                              : n.notificationType == 'STATUS_CHANGE'
                                  ? Icons.update_rounded
                                  : Icons.notifications_active_rounded,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            n.message,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dateFormat.format(n.createdAt),
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      onTap: () {
                        complaintProv.markNotificationRead(n.id);
                        if (n.complaintId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ComplaintDetailScreen(complaintId: n.complaintId!),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
          );
        },
      ),
    );
  }
}

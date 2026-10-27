import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../state/auth_provider.dart';
import '../state/complaint_provider.dart';
import '../../features/auth/admin_setup_screen.dart';
import '../../features/organizations/organization_switcher_dialog.dart';
import '../../features/complaints/create_complaint_screen.dart';
import '../../features/notifications/notifications_screen.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final Function(int) onTabSelected;
  final String title;

  const AppScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onTabSelected,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final complaintProv = Provider.of<ComplaintProvider>(context);
    final user = auth.currentUser;
    final activeOrg = auth.activeOrganization;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            if (activeOrg != null)
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const OrganizationSwitcherDialog(),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        activeOrg.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primary),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // Central Server Sync Button (Section 8)
          IconButton(
            icon: complaintProv.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Icon(Icons.sync_rounded, size: 22),
            tooltip: 'Sync with Central Server',
            onPressed: complaintProv.isSyncing
                ? null
                : () async {
                    final res = await complaintProv.triggerSync(token: auth.authToken);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.isOnline ? AppTheme.statusResolved : Colors.blueGrey,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
          ),
          // Notification Bell
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 24),
                if (complaintProv.unreadNotificationsCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.priorityCritical,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${complaintProv.unreadNotificationsCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          // User Menu (Role Chip & Menu)
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            tooltip: 'Account & Sign Out',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppTheme.primary,
                child: Text(
                  user != null && user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(user?.email ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        auth.activeRole.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (auth.isOrgAdmin)
                const PopupMenuItem(
                  value: 'admin_portal',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('4 Admin Accounts Setup', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'switch_org',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Switch Organization', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppTheme.statusRejected),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(fontSize: 13, color: AppTheme.statusRejected, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'admin_portal') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSetupScreen()),
                );
              } else if (val == 'switch_org') {
                showDialog(
                  context: context,
                  builder: (_) => const OrganizationSwitcherDialog(),
                );
              } else if (val == 'logout') {
                _confirmLogout(context, auth);
              }
            },
          ),
          // Quick Sign Out Icon Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.statusRejected, size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _confirmLogout(context, auth),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
      // Strictly do not show "New Complaint" FAB to administrators (Section 1)
      floatingActionButton: auth.isComplainant
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateComplaintScreen()),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Complaint', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabSelected,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard_rounded),
            label: auth.isOrgAdmin ? 'Dashboard' : 'Overview',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox_outlined),
            activeIcon: const Icon(Icons.inbox_rounded),
            label: auth.isOrgAdmin ? 'Inbox' : 'Complaints',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_rounded),
            activeIcon: Icon(Icons.notifications_rounded),
            label: 'Updates',
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await auth.logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

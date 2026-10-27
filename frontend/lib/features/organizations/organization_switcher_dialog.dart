import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/complaint_provider.dart';

class OrganizationSwitcherDialog extends StatelessWidget {
  const OrganizationSwitcherDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final activeOrg = auth.activeOrganization;

    if (user == null) return const SizedBox.shrink();

    // Map memberships to organizations
    final userOrgs = auth.availableOrganizations.where((org) {
      if (user.isPlatformAdmin) return true;
      return user.memberships.any((m) => m.organizationId == org.id && m.isActive);
    }).toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Switch Organization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: userOrgs.isEmpty
            ? const Text('No other organizations assigned.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: userOrgs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final org = userOrgs[index];
                  final isCurrent = activeOrg?.id == org.id;

                  // Find user role in this organization
                  String roleLabel = 'PLATFORM ADMIN';
                  if (!user.isPlatformAdmin) {
                    final mem = user.memberships.firstWhere((m) => m.organizationId == org.id);
                    roleLabel = mem.role.replaceAll('_', ' ');
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? AppTheme.primary : AppTheme.borderLight,
                      foregroundColor: isCurrent ? Colors.white : AppTheme.textPrimary,
                      child: Text(org.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(
                      org.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${org.typeLabel} • $roleLabel',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    trailing: isCurrent ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 20) : null,
                    onTap: () async {
                      if (!isCurrent) {
                        final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
                        final nav = Navigator.of(context);
                        await auth.switchOrganization(org);
                        complaintProv.fetchComplaints(resetFilters: true);
                        complaintProv.fetchDashboardMetrics();
                        complaintProv.fetchCategoriesAndDepartments();
                        nav.pop();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

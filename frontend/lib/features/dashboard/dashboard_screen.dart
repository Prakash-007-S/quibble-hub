import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/complaint_provider.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/priority_badge.dart';
import '../../core/widgets/state_views.dart';
import '../complaints/complaint_detail_screen.dart';
import '../complaints/create_complaint_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    await complaintProv.fetchDashboardMetrics(
      role: auth.activeRole,
      userId: auth.currentUser?.id,
    );
    await complaintProv.fetchComplaints(
      userId: auth.currentUser?.id,
      role: auth.activeRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final complaintProv = Provider.of<ComplaintProvider>(context);
    final data = complaintProv.dashboardData;
    final role = auth.activeRole;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final horizontalPadding = isWide ? (constraints.maxWidth - 700) / 2 : 16.0;

        return RefreshIndicator(
          onRefresh: () async => _loadDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            _buildWelcomeCard(auth),
            const SizedBox(height: 16),

            // Role-Specific Metrics Grid
            if (role == 'COMPLAINANT')
              _buildComplainantGrid(data)
            else if (role == 'STAFF')
              _buildStaffGrid(data)
            else
              _buildAdminGrid(data, complaintProv),

            const SizedBox(height: 20),

            // Recent Cases Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  auth.isOrgAdmin ? 'Recently Updated Cases' : 'Recent Activity',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(1),
                  child: const Text('View All in Inbox', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (complaintProv.isLoadingList)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: LoadingView(message: 'Loading complaints...'),
              )
            else if (complaintProv.complaints.isEmpty)
              EmptyStateView(
                title: 'No Complaints Yet',
                message: auth.isOrgAdmin
                    ? 'No complaints have been submitted yet. When users submit grievances, they will appear here.'
                    : 'You have not submitted any complaints yet.',
                actionLabel: auth.isComplainant ? 'Submit a Complaint' : null,
                onAction: auth.isComplainant
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateComplaintScreen()),
                        );
                      }
                    : null,
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: complaintProv.complaints.take(5).length,
                itemBuilder: (ctx, index) {
                  final complaint = complaintProv.complaints[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              complaint.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: complaint.status, isSmall: true),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  complaint.trackingNumber,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                ),
                                const Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                                Flexible(
                                  child: Text(
                                    complaint.categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PriorityBadge(priority: complaint.priority),
                              ],
                            ),
                            if (auth.isOrgAdmin)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 12, color: Colors.blueGrey.shade600),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'By: ${complaint.complainantName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 150),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: complaint.isAssigned ? Colors.indigo.shade50 : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: complaint.isAssigned ? Colors.indigo.shade200 : Colors.amber.shade300,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          complaint.displayAssignee,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: complaint.isAssigned ? Colors.indigo.shade800 : Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComplaintDetailScreen(complaintId: complaint.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildWelcomeCard(AuthProvider auth) {
    final user = auth.currentUser;
    final org = auth.activeOrganization;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkSlate, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  auth.activeRole.replaceAll('_', ' '),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              if (org != null)
                Text(
                  org.typeLabel,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              const Spacer(),
              InkWell(
                onTap: () => _showSignOutDialog(context, auth),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Welcome back, ${user?.fullName ?? 'User'}',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            org?.name ?? 'Quibble Hub',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Portal Identity & Switcher Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final switchButton = InkWell(
                  onTap: () async {
                    if (auth.isOrgAdmin) {
                      await auth.loginAsFirstComplainant();
                    } else {
                      await auth.loginAsAuthority();
                    }
                    if (mounted) {
                      _loadDashboard();
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: auth.isOrgAdmin ? AppTheme.primary : AppTheme.darkSlate,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      auth.isOrgAdmin ? 'Switch to Complainant' : 'Switch to Authority',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            auth.isOrgAdmin ? Icons.shield_rounded : Icons.person_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.isOrgAdmin
                                  ? 'Authority Desk: View all received grievances & take action'
                                  : 'Complainant Portal: Submit & track your personal grievances',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: switchButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Icon(
                      auth.isOrgAdmin ? Icons.shield_rounded : Icons.person_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.isOrgAdmin
                            ? 'Authority Desk: View all received grievances & take action'
                            : 'Complainant Portal: Submit & track your personal grievances',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    switchButton,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider auth) {
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

  Widget _buildComplainantGrid(dynamic data) {
    final total = data?.totalComplaints ?? 0;
    final inProgress = data?.inProgressCount ?? 0;
    final awaiting = data?.awaitingUserCount ?? 0;
    final resolved = data?.resolvedClosedCount ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('Total Submitted', total.toString(), Icons.folder_outlined, AppTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('In Progress', inProgress.toString(), Icons.sync_rounded, AppTheme.statusInProgress)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Needs Your Action', awaiting.toString(), Icons.feedback_outlined, AppTheme.statusAwaiting)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('Resolved & Closed', resolved.toString(), Icons.check_circle_outline, AppTheme.statusResolved)),
          ],
        ),
      ],
    );
  }

  Widget _buildStaffGrid(dynamic data) {
    final assigned = data?.assignedCount ?? 0;
    final unassigned = data?.unassignedDeptQueue ?? 0;
    final highCritical = data?.highCriticalCount ?? 0;
    final overdue = data?.overdueCount ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('My Assigned Cases', assigned.toString(), Icons.assignment_ind_outlined, AppTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('Unassigned Queue', unassigned.toString(), Icons.queue_outlined, AppTheme.statusAssigned)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricCard('High & Critical', highCritical.toString(), Icons.warning_amber_rounded, AppTheme.priorityCritical)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('Overdue / SLA Risk', overdue.toString(), Icons.alarm_off_rounded, AppTheme.statusRejected)),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminGrid(dynamic data, ComplaintProvider complaintProv) {
    final total = data?.totalReceived ?? 0;
    final newUnreviewed = data?.newUnreviewed ?? 0;
    final pending = data?.pendingComplaints ?? 0;
    final underInvestigation = data?.underInvestigation ?? 0;
    final awaitingInfo = data?.awaitingInformation ?? 0;
    final resolved = data?.resolvedCount ?? 0;
    final rejected = data?.rejectedCount ?? 0;
    final highUrgent = data?.highUrgentCount ?? 0;
    final recentlyUpdated = data?.recentlyUpdatedCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.darkSlate),
              const SizedBox(width: 6),
              const Text(
                'Live Complaint Metrics',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Text(
                'Tap to inspect in Inbox',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        // Row 1: Total Received & New/Unreviewed
        Row(
          children: [
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'Total Received',
                value: total.toString(),
                icon: Icons.inventory_2_outlined,
                color: AppTheme.darkSlate,
                onTap: () {
                  complaintProv.setFilterStatus(null);
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'New / Unreviewed',
                value: newUnreviewed.toString(),
                icon: Icons.mark_email_unread_outlined,
                color: Colors.blue.shade700,
                onTap: () {
                  complaintProv.setFilterStatus('NEW_UNREVIEWED');
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: Pending & Under Investigation
        Row(
          children: [
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'Pending Cases',
                value: pending.toString(),
                icon: Icons.hourglass_top_outlined,
                color: Colors.orange.shade800,
                onTap: () {
                  complaintProv.setFilterStatus('PENDING');
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'Under Investigation',
                value: underInvestigation.toString(),
                icon: Icons.biotech_outlined,
                color: Colors.indigo.shade700,
                onTap: () {
                  complaintProv.setFilterStatus('INVESTIGATION');
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 3: Awaiting Info & High/Urgent
        Row(
          children: [
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'Awaiting Info',
                value: awaitingInfo.toString(),
                icon: Icons.contact_support_outlined,
                color: Colors.purple.shade700,
                onTap: () {
                  complaintProv.setFilterStatus('AWAITING_USER');
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'High & Urgent',
                value: highUrgent.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppTheme.priorityCritical,
                onTap: () {
                  complaintProv.setFilterStatus(null);
                  complaintProv.setFilterPriority('HIGH_URGENT');
                  widget.onNavigateTab(1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 4: Resolved & Rejected
        Row(
          children: [
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'Resolved Cases',
                value: resolved.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: AppTheme.statusResolved,
                onTap: () {
                  complaintProv.setFilterStatus('RESOLVED_ALL');
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectableMetricCard(
                title: 'Rejected Cases',
                value: rejected.toString(),
                icon: Icons.cancel_outlined,
                color: AppTheme.statusRejected,
                onTap: () {
                  complaintProv.setFilterStatus('REJECTED');
                  complaintProv.setFilterPriority(null);
                  widget.onNavigateTab(1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 5: Recently Updated banner
        InkWell(
          onTap: () {
            complaintProv.setSortBy('updated_at DESC');
            complaintProv.setFilterStatus(null);
            complaintProv.setFilterPriority(null);
            widget.onNavigateTab(1);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 20, color: Colors.teal.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recently Updated Complaints: $recentlyUpdated cases active this week',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.teal.shade800),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ),
                  Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 13, color: color.withValues(alpha: 0.6)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

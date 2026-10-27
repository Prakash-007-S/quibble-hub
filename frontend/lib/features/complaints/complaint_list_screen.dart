import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/complaint_provider.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/priority_badge.dart';
import '../../core/widgets/state_views.dart';
import 'complaint_detail_screen.dart';
import 'create_complaint_screen.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statuses = [
    'ALL',
    'SUBMITTED',
    'UNDER_REVIEW',
    'IN_PROGRESS',
    'AWAITING_USER',
    'RESOLVED',
    'REJECTED',
    'CLOSED',
  ];

  final List<String> _priorities = ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    complaintProv.fetchComplaints(
      userId: auth.currentUser?.id,
      role: auth.activeRole,
    );
  }

  void _onSearchChanged(String val) {
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    complaintProv.searchKeyword = val.trim().isEmpty ? null : val.trim();
    _refresh();
  }

  void _onStatusFilter(String status) {
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    complaintProv.setFilterStatus(status == 'ALL' ? null : status);
    _refresh();
  }

  void _onPriorityFilter(String priority) {
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    complaintProv.setFilterPriority(priority == 'ALL' ? null : priority);
    _refresh();
  }

  void _onWorkloadFilter(String workload) {
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    complaintProv.setWorkloadFilter(workload);
    _refresh();
  }

  void _onSortChanged(String sort) {
    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    complaintProv.setSortBy(sort);
    _refresh();
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('MMM d, y • HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final complaintProv = Provider.of<ComplaintProvider>(context);

    final currentStatus = complaintProv.selectedStatus ?? 'ALL';
    final currentPriority = complaintProv.selectedPriority ?? 'ALL';
    final currentWorkload = complaintProv.workloadFilter;
    final currentSort = complaintProv.sortBy;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final horizontalMargin = isWide ? (constraints.maxWidth - 700) / 2 : 0.0;

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
            child: Column(
              children: [
          // Queue Context Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: auth.isOrgAdmin ? AppTheme.darkSlate : AppTheme.primaryLight.withValues(alpha: 0.6),
            ),
            child: Row(
              children: [
                Icon(
                  auth.isOrgAdmin ? Icons.inbox_rounded : Icons.person_rounded,
                  size: 16,
                  color: auth.isOrgAdmin ? Colors.white : AppTheme.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.isOrgAdmin
                        ? 'Incoming Complaints Inbox (${complaintProv.totalComplaints} Cases)'
                        : 'Personal Complainant Queue (${complaintProv.totalComplaints} Grievances)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: auth.isOrgAdmin ? Colors.white : AppTheme.primaryDark,
                    ),
                  ),
                ),
                if (auth.isOrgAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Admin Portal',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: auth.isOrgAdmin
                        ? 'Search title, tracking #, complainant...'
                        : 'Search your grievances...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),

                // Administrator Workload Filter (Section 7)
                if (auth.isOrgAdmin) ...[
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      const Text(
                        'Workload:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildWorkloadChip('ALL', 'All Cases', currentWorkload),
                              const SizedBox(width: 6),
                              _buildWorkloadChip('ASSIGNED_TO_ME', 'Assigned to Me', currentWorkload),
                              const SizedBox(width: 6),
                              _buildWorkloadChip('UNASSIGNED', 'Unassigned Queue', currentWorkload),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Sort Dropdown & Quick Filter info
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 15, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        const Text(
                          'Sort by:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 6),
                        DropdownButton<String>(
                          value: currentSort,
                          isDense: true,
                          underline: const SizedBox(),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          items: const [
                            DropdownMenuItem(value: 'created_at DESC', child: Text('Newest First')),
                            DropdownMenuItem(value: 'updated_at DESC', child: Text('Recently Updated')),
                            DropdownMenuItem(value: 'priority DESC', child: Text('Priority: High-Low')),
                          ],
                          onChanged: (val) {
                            if (val != null) _onSortChanged(val);
                          },
                        ),
                      ],
                    ),
                    if (complaintProv.selectedStatus != null ||
                        complaintProv.selectedPriority != null ||
                        currentWorkload != 'ALL' ||
                        _searchController.text.isNotEmpty)
                      InkWell(
                        onTap: () {
                          _searchController.clear();
                          complaintProv.fetchComplaints(resetFilters: true);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Clear All Filters',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((s) {
                      final isSelected = s == currentStatus;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            s.replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.backgroundLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onSelected: (_) => _onStatusFilter(s),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 4),

                // Priority Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _priorities.map((p) {
                      final isSelected = p == currentPriority;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            p,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.darkSlate,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: isSelected ? AppTheme.darkSlate : AppTheme.borderLight,
                            ),
                          ),
                          onSelected: (_) => _onPriorityFilter(p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List Body
          Expanded(
            child: complaintProv.isLoadingList
                ? const LoadingView(message: 'Loading complaints...')
                : complaintProv.complaints.isEmpty
                    ? ((complaintProv.selectedStatus != null && complaintProv.selectedStatus != 'ALL') ||
                            (complaintProv.selectedPriority != null && complaintProv.selectedPriority != 'ALL') ||
                            (currentWorkload != 'ALL') ||
                            (_searchController.text.trim().isNotEmpty))
                        ? EmptyStateView(
                            title: 'No Matching Complaints',
                            message: 'No complaints match the selected filter criteria.',
                            actionLabel: 'Reset Filters',
                            onAction: () {
                              _searchController.clear();
                              complaintProv.fetchComplaints(resetFilters: true);
                            },
                          )
                        : EmptyStateView(
                            title: auth.isOrgAdmin ? 'Inbox is Empty' : 'No Complaints Yet',
                            message: auth.isOrgAdmin
                                ? 'No user complaints are currently pending in this queue.'
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
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        itemCount: complaintProv.complaints.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, index) {
                          final c = complaintProv.complaints[index];
                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: c.priority == 'CRITICAL'
                                    ? Colors.red.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ComplaintDetailScreen(complaintId: c.id),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(13.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Tracking ID, Sync status, Status badge
                                    Row(
                                      children: [
                                        Text(
                                          c.trackingNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: AppTheme.primary,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // On-device vs Server Sync Indicator (Section 8)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: c.isSynced ? Colors.green.shade50 : Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: c.isSynced ? Colors.green.shade300 : Colors.blueGrey.shade200,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                c.isSynced ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
                                                size: 10,
                                                color: c.isSynced ? Colors.green.shade700 : Colors.blueGrey.shade700,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                c.isSynced ? 'Synced' : 'Local Only',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: c.isSynced ? Colors.green.shade800 : Colors.blueGrey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (c.isEscalated) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.priorityCritical.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'URGENT',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.priorityCritical),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        StatusBadge(status: c.status, isSmall: true),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 2: Title
                                    Text(
                                      c.title,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 5),

                                    // Row 3: Category & Complainant Identifier
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.backgroundLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            c.categoryName,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textSecondary),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            c.complainantName,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 4: Dates & Assignee (Section 3)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade200, width: 0.7),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.schedule_rounded, size: 12, color: Colors.grey.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Submitted: ${_formatDateTime(c.createdAt)}',
                                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800),
                                              ),
                                            ],
                                          ),
                                          // Assigned Admin (Section 3 & 7)
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 180),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: c.isAssigned ? Colors.indigo.shade50 : Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.assignment_ind_outlined,
                                                  size: 11,
                                                  color: c.isAssigned ? Colors.indigo.shade700 : Colors.amber.shade900,
                                                ),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    c.displayAssignee,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: c.isAssigned ? Colors.indigo.shade800 : Colors.amber.shade900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 5: Priority badge & Counts
                                    Row(
                                      children: [
                                        PriorityBadge(priority: c.priority),
                                        const Spacer(),
                                        if (c.commentsCount > 0) ...[
                                          const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: AppTheme.textMuted),
                                          const SizedBox(width: 3),
                                          Text('${c.commentsCount}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                          const SizedBox(width: 8),
                                        ],
                                        if (c.attachmentsCount > 0) ...[
                                          const Icon(Icons.attach_file_rounded, size: 12, color: AppTheme.textMuted),
                                          const SizedBox(width: 2),
                                          Text('${c.attachmentsCount}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkloadChip(String value, String label, String current) {
    final isSelected = value == current;
    return InkWell(
      onTap: () => _onWorkloadFilter(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkSlate : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.darkSlate : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

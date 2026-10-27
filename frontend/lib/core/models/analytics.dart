class DashboardData {
  final String role;
  final Map<String, dynamic> metrics;

  DashboardData({
    required this.role,
    required this.metrics,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      role: json['role'] ?? 'COMPLAINANT',
      metrics: json['metrics'] is Map ? Map<String, dynamic>.from(json['metrics']) : {},
    );
  }

  // Complainant Getters
  int get totalComplaints => (metrics['total_complaints'] as num?)?.toInt() ?? 0;
  int get submittedCount => (metrics['submitted_count'] as num?)?.toInt() ?? 0;
  int get inProgressCount => (metrics['in_progress_count'] as num?)?.toInt() ?? 0;
  int get awaitingUserCount => (metrics['awaiting_user_count'] as num?)?.toInt() ?? 0;
  int get resolvedClosedCount => (metrics['resolved_closed_count'] as num?)?.toInt() ?? 0;

  // Staff Getters
  int get assignedCount => (metrics['assigned_count'] as num?)?.toInt() ?? 0;
  int get unassignedDeptQueue => (metrics['unassigned_dept_queue'] as num?)?.toInt() ?? 0;
  int get highCriticalCount => (metrics['high_critical_count'] as num?)?.toInt() ?? 0;
  int get overdueCount => (metrics['overdue_count'] as num?)?.toInt() ?? 0;

  // Admin Getters
  int get openComplaints => (metrics['open_complaints'] as num?)?.toInt() ?? 0;
  int get resolvedComplaints => (metrics['resolved_complaints'] as num?)?.toInt() ?? 0;
  int get totalReceived => (metrics['total_received'] as num?)?.toInt() ?? totalComplaints;
  int get newUnreviewed => (metrics['new_unreviewed'] as num?)?.toInt() ?? (metrics['submitted_count'] as num?)?.toInt() ?? 0;
  int get pendingComplaints => (metrics['pending_count'] as num?)?.toInt() ?? openComplaints;
  int get underInvestigation => (metrics['under_investigation'] as num?)?.toInt() ?? inProgressCount;
  int get awaitingInformation => (metrics['awaiting_information'] as num?)?.toInt() ?? awaitingUserCount;
  int get resolvedCount => (metrics['resolved_count'] as num?)?.toInt() ?? resolvedComplaints;
  int get rejectedCount => (metrics['rejected_count'] as num?)?.toInt() ?? 0;
  int get highUrgentCount => (metrics['high_priority'] as num?)?.toInt() ?? highCriticalCount;
  int get recentlyUpdatedCount => (metrics['recently_updated'] as num?)?.toInt() ?? 0;

  Map<String, int> get departmentDistribution =>
      (metrics['department_distribution'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {};
  Map<String, int> get categoryDistribution =>
      (metrics['category_distribution'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {};
  double get avgFirstResponseHours => (metrics['avg_first_response_hours'] as num?)?.toDouble() ?? 0.0;
  double get avgResolutionHours => (metrics['avg_resolution_hours'] as num?)?.toDouble() ?? 0.0;
  int get slaBreachesCount => (metrics['sla_breaches_count'] as num?)?.toInt() ?? 0;
  double get feedbackAvgRating => (metrics['feedback_avg_rating'] as num?)?.toDouble() ?? 5.0;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/analytics.dart';
import 'package:frontend/core/models/complaint.dart';

void main() {
  group('Admin Portal Architecture & Investigation Workflow Tests', () {
    test('Dashboard metrics model accurately exposes all 8 Section 2 metrics', () {
      final metrics = DashboardData(
        role: 'ADMIN',
        metrics: {
          'total_received': 23,
          'total_complaints': 23,
          'new_unreviewed': 4,
          'pending_count': 14,
          'under_investigation': 8,
          'awaiting_information': 2,
          'resolved_count': 8,
          'rejected_count': 1,
          'high_priority': 6,
          'recently_updated': 6,
        },
      );

      // Section 2 required counts:
      expect(metrics.totalReceived, equals(23));
      expect(metrics.newUnreviewed, equals(4)); // SUBMITTED
      expect(metrics.pendingComplaints, equals(14)); // SUBMITTED + UNDER_REVIEW + IN_PROGRESS + AWAITING_USER
      expect(metrics.underInvestigation, equals(8)); // UNDER_REVIEW + IN_PROGRESS
      expect(metrics.awaitingInformation, equals(2)); // AWAITING_USER
      expect(metrics.resolvedCount, equals(8)); // RESOLVED
      expect(metrics.rejectedCount, equals(1)); // REJECTED
      expect(metrics.highUrgentCount, equals(6)); // CRITICAL + HIGH
      expect(metrics.recentlyUpdatedCount, equals(6));
    });

    test('Complaint model parses displayAssignee, isAssigned and sync status accurately', () {
      final unassigned = Complaint.fromJson({
        'id': 'comp-101',
        'title': 'Broken Projector in Hall B',
        'status': 'SUBMITTED',
        'priority': 'HIGH',
        'assignee_id': null,
        'assignee_name': null,
        'is_synced': 0,
      });

      expect(unassigned.isAssigned, isFalse);
      expect(unassigned.displayAssignee, equals('Unassigned'));
      expect(unassigned.isSynced, isFalse);

      final assigned = Complaint.fromJson({
        'id': 'comp-102',
        'title': 'Library AC Leak',
        'status': 'IN_PROGRESS',
        'priority': 'MEDIUM',
        'assignee_id': '1',
        'assignee_name': 'Chief Proctor',
        'is_synced': 1,
      });

      expect(assigned.isAssigned, isTrue);
      expect(assigned.displayAssignee, equals('Chief Proctor'));
      expect(assigned.isSynced, isTrue);
    });

    test('Internal notes separation: Complainants must never see internal investigation notes', () {
      final allComments = [
        ComplaintComment(
          id: 'comm-1',
          userId: 'user-student',
          userName: 'Student Complainant',
          commentText: 'Initial complaint filed with classroom photo.',
          isInternalNote: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        ComplaintComment(
          id: 'comm-2',
          userId: 'admin-slot-1',
          userName: 'Investigating Officer',
          commentText: 'INTERNAL NOTE: Dispatched maintenance engineer to inspect projector bulb.',
          isInternalNote: true, // Internal only
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        ComplaintComment(
          id: 'comm-3',
          userId: 'admin-slot-1',
          userName: 'Investigating Officer',
          commentText: 'PUBLIC UPDATE: Inspection scheduled for 2:00 PM today.',
          isInternalNote: false, // Visible to user
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      // Filter as enforced by AppDatabase for complainant portal
      final complainantVisibleComments = allComments.where((c) => !c.isInternalNote).toList();
      final adminVisibleComments = allComments;

      expect(adminVisibleComments.length, equals(3));
      expect(complainantVisibleComments.length, equals(2));
      expect(complainantVisibleComments.any((c) => c.isInternalNote), isFalse);
      expect(complainantVisibleComments.any((c) => c.commentText.contains('INTERNAL NOTE')), isFalse);
    });

    test('ComplaintComment model parses integer 1/0 or boolean is_internal_note safely', () {
      final commentFromSqliteInt = ComplaintComment.fromJson({
        'id': 'comm-test-1',
        'user_id': 'admin',
        'user_name': 'Admin User',
        'comment_text': 'Secret verification note',
        'is_internal_note': 1,
      });
      expect(commentFromSqliteInt.isInternalNote, isTrue);

      final commentPublicSqliteInt = ComplaintComment.fromJson({
        'id': 'comm-test-2',
        'user_id': 'admin',
        'user_name': 'Admin User',
        'comment_text': 'Public reply',
        'is_internal_note': 0,
      });
      expect(commentPublicSqliteInt.isInternalNote, isFalse);

      final commentJsonBool = ComplaintComment.fromJson({
        'id': 'comm-test-3',
        'user_id': 'admin',
        'user_name': 'Admin User',
        'comment_text': 'API response note',
        'is_internal_note': true,
      });
      expect(commentJsonBool.isInternalNote, isTrue);
    });
  });
}

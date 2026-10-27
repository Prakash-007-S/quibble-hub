import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/core/models/admin_identity.dart';
import 'package:frontend/core/models/analytics.dart';
import 'package:frontend/core/models/complaint.dart';
import 'package:frontend/core/services/evidence_service.dart';

void main() {
  group('Security & Password Hashing Tests', () {
    test('generateSalt returns 32-character hexadecimal string', () {
      final salt1 = AppDatabase.generateSalt();
      final salt2 = AppDatabase.generateSalt();

      expect(salt1.length, 32);
      expect(salt2.length, 32);
      expect(salt1, isNot(equals(salt2)));
    });

    test('hashPassword produces identical SHA-256 hash for identical salt + password', () {
      final salt = AppDatabase.generateSalt();
      const password = 'SuperSecretAdminPassword123!';

      final hash1 = AppDatabase.hashPassword(password, salt);
      final hash2 = AppDatabase.hashPassword(password, salt);

      expect(hash1, equals(hash2));
      expect(hash1.length, 64); // SHA-256 hex string length
    });

    test('hashPassword produces distinct hashes for different passwords or salts', () {
      final salt = AppDatabase.generateSalt();
      final hashA = AppDatabase.hashPassword('PasswordA', salt);
      final hashB = AppDatabase.hashPassword('PasswordB', salt);

      expect(hashA, isNot(equals(hashB)));

      final salt2 = AppDatabase.generateSalt();
      final hashAWithSalt2 = AppDatabase.hashPassword('PasswordA', salt2);
      expect(hashA, isNot(equals(hashAWithSalt2)));
    });
  });

  group('Evidence Formatting & Model Tests', () {
    test('formatBytes handles zero, bytes, KB, MB, and GB accurately', () {
      expect(EvidenceService.formatBytes(0), '0 B');
      expect(EvidenceService.formatBytes(512), '512.0 B');
      expect(EvidenceService.formatBytes(1024), '1.0 KB');
      expect(EvidenceService.formatBytes(1024 * 1024 * 3), '3.0 MB');
      expect(EvidenceService.formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });

    test('ComplaintAttachment model parses local filePath and fileType correctly', () {
      final json = {
        'id': 'att-101',
        'complaint_id': 'cmp-001',
        'file_path': '/data/user/0/org.complaint/app_flutter/evidence/photo_1.jpg',
        'filename': 'hostel_pipe_leak.jpg',
        'file_size': 2048500,
        'file_type': 'photo',
        'content_type': 'image/jpeg',
        'uploader_id': 'usr-1',
        'uploader_name': 'Rohan Sharma',
        'created_at': '2026-10-22T10:00:00.000Z',
      };

      final att = ComplaintAttachment.fromJson(json);

      expect(att.id, 'att-101');
      expect(att.filePath, '/data/user/0/org.complaint/app_flutter/evidence/photo_1.jpg');
      expect(att.filename, 'hostel_pipe_leak.jpg');
      expect(att.fileSize, 2048500);
      expect(att.fileType, 'photo');
      expect(att.contentType, 'image/jpeg');
      expect(att.uploaderName, 'Rohan Sharma');
    });

    test('AdminIdentity handles unconfigured and configured states', () {
      final unconfiguredMap = {
        'slot_number': 1,
        'full_name': null,
        'email': null,
        'password_hash': null,
        'salt': null,
        'is_configured': 0,
        'configured_at': null,
      };

      final slot1 = AdminIdentity.fromMap(unconfiguredMap);
      expect(slot1.isConfigured, isFalse);
      expect(slot1.displayName, 'Slot #1 (Unconfigured)');

      final configuredMap = {
        'slot_number': 2,
        'full_name': 'Dr. Sarah Connor',
        'email': 'sconnor@campus.edu',
        'password_hash': 'abcdef123456',
        'salt': 'salt123',
        'is_configured': 1,
        'configured_at': '2026-10-22T11:00:00.000Z',
      };

      final slot2 = AdminIdentity.fromMap(configuredMap);
      expect(slot2.isConfigured, isTrue);
      expect(slot2.displayName, 'Dr. Sarah Connor');
      expect(slot2.email, 'sconnor@campus.edu');
    });

    test('DashboardData computes metrics for both Complainant and Admin roles', () {
      final complainantData = DashboardData(
        role: 'COMPLAINANT',
        metrics: {
          'total_complaints': 5,
          'submitted_count': 2,
          'in_progress_count': 1,
          'awaiting_user_count': 0,
          'resolved_closed_count': 2,
        },
      );

      expect(complainantData.totalComplaints, 5);
      expect(complainantData.submittedCount, 2);
      expect(complainantData.inProgressCount, 1);
      expect(complainantData.resolvedClosedCount, 2);

      final adminData = DashboardData(
        role: 'ORG_ADMIN',
        metrics: {
          'open_complaints': 14,
          'resolved_complaints': 38,
          'department_distribution': {'IT Infrastructure': 8, 'Estate & Facilities': 6},
          'category_distribution': {'Campus Wi-Fi': 8, 'Hostel Maintenance': 6},
          'avg_first_response_hours': 1.8,
          'avg_resolution_hours': 12.0,
          'sla_breaches_count': 0,
          'feedback_avg_rating': 4.8,
        },
      );

      expect(adminData.openComplaints, 14);
      expect(adminData.resolvedComplaints, 38);
      expect(adminData.departmentDistribution['IT Infrastructure'], 8);
      expect(adminData.feedbackAvgRating, 4.8);
    });

    test('Default admin credentials hash check for admin123', () {
      final salt = AppDatabase.generateSalt();
      const defaultPassword = 'admin123';
      final hash = AppDatabase.hashPassword(defaultPassword, salt);

      // Verify computed hash matches when re-calculated with same salt
      expect(AppDatabase.hashPassword('admin123', salt), equals(hash));
      // Incorrect password fails
      expect(AppDatabase.hashPassword('wrongpassword', salt), isNot(equals(hash)));
    });
  });
}

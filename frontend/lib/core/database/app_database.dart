import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/admin_identity.dart';
import '../models/analytics.dart';
import '../models/category.dart';
import '../models/complaint.dart';
import '../models/department.dart';
import '../models/notification.dart';
import '../models/user.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'complaint_system_offline.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await ensureAdminSlots(db);
        // Automatically migrate existing records to Sengunthar Engineering College
        await db.execute('''
          UPDATE users 
          SET organization_name = 'Sengunthar Engineering College', organization_id = 'org-sengunthar'
          WHERE organization_name LIKE '%Apex%' OR organization_id = 'org-apex'
        ''');
        await db.execute('''
          UPDATE complaints 
          SET organization_id = 'org-sengunthar'
          WHERE organization_id = 'org-apex'
        ''');
        await db.execute('''
          UPDATE admin_identities
          SET email = REPLACE(email, '@apex.edu', '@sengunthar.edu')
          WHERE email LIKE '%@apex.edu'
        ''');
      },
    );
  }

  static Future<void> ensureAdminSlots(Database db) async {
    final defaultAdminConfigs = [
      {
        'slot': 1,
        'name': 'Dr. S. Ramanathan (Campus Grievance Officer)',
        'email': 'admin@sengunthar.edu',
        'password': 'admin123',
      },
      {
        'slot': 2,
        'name': 'Prof. M. K. Anandan (Dean of Student Affairs)',
        'email': 'dean@sengunthar.edu',
        'password': 'admin123',
      },
      {
        'slot': 3,
        'name': 'Dr. P. Sundaram (Estate & Facilities Officer)',
        'email': 'estate@sengunthar.edu',
        'password': 'admin123',
      },
      {
        'slot': 4,
        'name': 'K. Meenakshi (Academic Affairs Coordinator)',
        'email': 'academic@sengunthar.edu',
        'password': 'admin123',
      },
    ];

    for (final admin in defaultAdminConfigs) {
      final slot = admin['slot'] as int;
      final rows = await db.query('admin_identities', where: 'slot_number = ?', whereArgs: [slot]);

      if (rows.isEmpty) {
        final salt = generateSalt();
        final pwdHash = hashPassword(admin['password'] as String, salt);
        await db.insert('admin_identities', {
          'slot_number': slot,
          'full_name': admin['name'] as String,
          'email': admin['email'] as String,
          'password_hash': pwdHash,
          'salt': salt,
          'is_configured': 1,
          'configured_at': DateTime.now().toIso8601String(),
        });
      } else {
        final current = rows.first;
        final isConfigured = (current['is_configured'] as int? ?? 0) == 1;
        final currentEmail = current['email'] as String?;
        if (!isConfigured || currentEmail == null || currentEmail.isEmpty) {
          final salt = generateSalt();
          final pwdHash = hashPassword(admin['password'] as String, salt);
          await db.update(
            'admin_identities',
            {
              'full_name': admin['name'] as String,
              'email': admin['email'] as String,
              'password_hash': pwdHash,
              'salt': salt,
              'is_configured': 1,
              'configured_at': DateTime.now().toIso8601String(),
            },
            where: 'slot_number = ?',
            whereArgs: [slot],
          );
        }
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Users Table (Complainants)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'COMPLAINANT',
        organization_id TEXT NOT NULL DEFAULT 'org-sengunthar',
        organization_name TEXT NOT NULL DEFAULT 'Sengunthar Engineering College',
        created_at TEXT NOT NULL
      )
    ''');

    // 2. 4 Designated Administrator Identities
    await db.execute('''
      CREATE TABLE admin_identities (
        slot_number INTEGER PRIMARY KEY,
        full_name TEXT,
        email TEXT,
        password_hash TEXT,
        salt TEXT,
        is_configured INTEGER NOT NULL DEFAULT 0,
        configured_at TEXT
      )
    ''');

    // Initialize the 4 designated administrator slots
    await ensureAdminSlots(db);

    // 3. Complaints Table
    await db.execute('''
      CREATE TABLE complaints (
        id TEXT PRIMARY KEY,
        tracking_number TEXT UNIQUE NOT NULL,
        organization_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        department_id TEXT NOT NULL,
        department_name TEXT NOT NULL,
        complainant_id TEXT NOT NULL,
        complainant_name TEXT NOT NULL,
        assignee_id TEXT,
        assignee_name TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        location_context TEXT,
        status TEXT NOT NULL DEFAULT 'SUBMITTED',
        priority TEXT NOT NULL DEFAULT 'MEDIUM',
        resolution_summary TEXT,
        rejection_reason TEXT,
        reopen_count INTEGER NOT NULL DEFAULT 0,
        is_escalated INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT,
        first_responded_at TEXT,
        resolved_at TEXT,
        closed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Evidence Attachments Table
    await db.execute('''
      CREATE TABLE evidence_attachments (
        id TEXT PRIMARY KEY,
        complaint_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        filename TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        content_type TEXT NOT NULL,
        uploader_id TEXT NOT NULL,
        uploader_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (complaint_id) REFERENCES complaints (id) ON DELETE CASCADE
      )
    ''');

    // 5. Comments Table
    await db.execute('''
      CREATE TABLE complaint_comments (
        id TEXT PRIMARY KEY,
        complaint_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        comment_text TEXT NOT NULL,
        is_internal_note INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (complaint_id) REFERENCES complaints (id) ON DELETE CASCADE
      )
    ''');

    // 6. History / Audit Log Table
    await db.execute('''
      CREATE TABLE complaint_history (
        id TEXT PRIMARY KEY,
        complaint_id TEXT NOT NULL,
        actor_id TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        event_type TEXT NOT NULL,
        from_status TEXT,
        to_status TEXT,
        reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (complaint_id) REFERENCES complaints (id) ON DELETE CASCADE
      )
    ''');

    // 7. Feedback Table
    await db.execute('''
      CREATE TABLE complaint_feedback (
        id TEXT PRIMARY KEY,
        complaint_id TEXT NOT NULL,
        rating INTEGER NOT NULL,
        comments TEXT,
        resolution_satisfactory INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (complaint_id) REFERENCES complaints (id) ON DELETE CASCADE
      )
    ''');

    // 8. Notifications Table
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        notification_type TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        complaint_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 9. Standard Institutional Categories & Departments Catalog
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department_id TEXT NOT NULL,
        department_name TEXT NOT NULL,
        description TEXT
      )
    ''');

    final defaultCategories = [
      {'id': 'cat-wifi', 'name': 'Campus Wi-Fi & Internet', 'department_id': 'dept-it', 'department_name': 'IT Infrastructure', 'description': 'Wi-Fi connectivity, access point outage, bandwidth bottlenecks'},
      {'id': 'cat-hostel', 'name': 'Hostel Maintenance & Plumbing', 'department_id': 'dept-estate', 'department_name': 'Estate & Facilities', 'description': 'Water supply, plumbing leaks, electrical fixtures, room repairs'},
      {'id': 'cat-academic', 'name': 'Academic Timetable & Lectures', 'department_id': 'dept-acad', 'department_name': 'Academic Affairs', 'description': 'Schedule conflicts, class rescheduling, syllabus grievances'},
      {'id': 'cat-lab', 'name': 'Laboratory Equipment & Hardware', 'department_id': 'dept-lab', 'department_name': 'Laboratory Operations', 'description': 'Faulty PCs, oscilloscopes, chemical supplies, software licenses'},
      {'id': 'cat-security', 'name': 'Campus Safety & Access Control', 'department_id': 'dept-sec', 'department_name': 'Security Office', 'description': 'Gate pass issues, ID card scanning, nighttime lighting, lost property'},
      {'id': 'cat-sanitation', 'name': 'Sanitation & Housekeeping', 'department_id': 'dept-house', 'department_name': 'Housekeeping Department', 'description': 'Restroom cleanliness, dustbins, corridor hygiene'},
      {'id': 'cat-canteen', 'name': 'Canteen & Food Quality', 'department_id': 'dept-welfare', 'department_name': 'Student Welfare', 'description': 'Meal hygiene, pricing, dietary options, cafeteria seating'},
      {'id': 'cat-library', 'name': 'Library Resources & Subscriptions', 'department_id': 'dept-lib', 'department_name': 'Library Services', 'description': 'Book availability, digital journal access, study hall air-conditioning'},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }

    // 10. Key-Value App Settings & Local Session Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // --- Local Settings & Session Store ---
  Future<void> setSetting(String key, String? value) async {
    final db = await database;
    if (value == null) {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // --- Password Hashing Helpers ---
  static String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  // --- Authentication & User Operations ---

  /// Register a normal user (strictly COMPLAINANT)
  Future<User> registerUser({
    required String email,
    required String fullName,
    required String password,
    String organizationId = 'org-sengunthar',
    String organizationName = 'Sengunthar Engineering College',
  }) async {
    final db = await database;
    final cleanEmail = email.trim().toLowerCase();

    // Check if email already exists in users or configured admin slots
    final existingUser = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );
    if (existingUser.isNotEmpty) {
      throw Exception('An account with email "$cleanEmail" already exists.');
    }

    final existingAdmin = await db.query(
      'admin_identities',
      where: 'is_configured = 1 AND LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );
    if (existingAdmin.isNotEmpty) {
      throw Exception('Email "$cleanEmail" is reserved for an administrator.');
    }

    final userId = 'usr-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id': userId,
      'email': cleanEmail,
      'full_name': fullName.trim(),
      'password_hash': passwordHash,
      'salt': salt,
      'role': 'COMPLAINANT',
      'organization_id': organizationId,
      'organization_name': organizationName,
      'created_at': now,
    });

    return User(
      id: userId,
      email: cleanEmail,
      fullName: fullName.trim(),
      isPlatformAdmin: false,
      memberships: [
        Membership(
          id: 'mem-$userId',
          organizationId: organizationId,
          organizationName: organizationName,
          orgSlug: 'sengunthar',
          orgType: 'COLLEGE',
          role: 'COMPLAINANT',
          isActive: true,
        ),
      ],
    );
  }

  /// Authenticate: checks configured admin slots first, then normal users
  Future<User?> authenticate({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final cleanEmail = email.trim().toLowerCase();
    final lookupEmail = cleanEmail == 'admin@apex.edu' ? 'admin@sengunthar.edu' : cleanEmail;

    // 1. Check Configured Admin Identities
    final adminRows = await db.query(
      'admin_identities',
      where: 'is_configured = 1 AND (LOWER(email) = ? OR LOWER(email) = ?)',
      whereArgs: [cleanEmail, lookupEmail],
    );

    if (adminRows.isNotEmpty) {
      final adminRow = adminRows.first;
      final salt = adminRow['salt'] as String;
      final expectedHash = adminRow['password_hash'] as String;
      final computedHash = hashPassword(password, salt);

      if (computedHash == expectedHash) {
        final slotNum = adminRow['slot_number'] as int;
        final name = (adminRow['full_name'] as String?) ?? 'Administrator #$slotNum';
        return User(
          id: 'admin-slot-$slotNum',
          email: cleanEmail,
          fullName: name,
          isPlatformAdmin: true,
          memberships: [
            Membership(
              id: 'mem-admin-$slotNum',
              organizationId: 'org-sengunthar',
              organizationName: 'Sengunthar Engineering College',
              orgSlug: 'sengunthar',
              orgType: 'COLLEGE',
              role: 'ORG_ADMIN',
              isActive: true,
            ),
          ],
        );
      } else {
        throw Exception('Incorrect password for administrator identity.');
      }
    }

    // 2. Check Standard Users (Complainants)
    final userRows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );

    if (userRows.isNotEmpty) {
      final userRow = userRows.first;
      final salt = userRow['salt'] as String;
      final expectedHash = userRow['password_hash'] as String;
      final computedHash = hashPassword(password, salt);

      if (computedHash == expectedHash) {
        final id = userRow['id'] as String;
        final name = userRow['full_name'] as String;
        final orgId = userRow['organization_id'] as String;
        final orgName = userRow['organization_name'] as String;
        return User(
          id: id,
          email: cleanEmail,
          fullName: name,
          isPlatformAdmin: false,
          memberships: [
            Membership(
              id: 'mem-$id',
              organizationId: orgId,
              organizationName: orgName.contains('Apex') ? 'Sengunthar Engineering College' : orgName,
              orgSlug: 'sengunthar',
              orgType: 'COLLEGE',
              role: 'COMPLAINANT',
              isActive: true,
            ),
          ],
        );
      } else {
        throw Exception('Incorrect password.');
      }
    }

    return null; // Not found
  }

  // --- Admin Identities Management ---

  /// Retrieve the 4 admin slots
  Future<List<AdminIdentity>> getAdminIdentities() async {
    final db = await database;
    final rows = await db.query('admin_identities', orderBy: 'slot_number ASC');
    return rows.map((r) => AdminIdentity.fromMap(r)).toList();
  }

  /// Provision or update one of the 4 designated admin slots
  Future<void> configureAdminSlot({
    required int slotNumber,
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (slotNumber < 1 || slotNumber > 4) {
      throw Exception('Invalid slot number. Admin slots must be 1 to 4.');
    }
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@') || cleanEmail.length < 5) {
      throw Exception('Please provide a valid administrator email address.');
    }
    if (password.length < 8) {
      throw Exception('Admin password must be at least 8 characters long for security.');
    }

    final db = await database;

    // Ensure email is not already taken by another admin slot
    final otherAdmins = await db.query(
      'admin_identities',
      where: 'slot_number != ? AND is_configured = 1 AND LOWER(email) = ?',
      whereArgs: [slotNumber, cleanEmail],
    );
    if (otherAdmins.isNotEmpty) {
      throw Exception('Email "$cleanEmail" is already configured on another admin slot.');
    }

    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'admin_identities',
      {
        'full_name': fullName.trim(),
        'email': cleanEmail,
        'password_hash': passwordHash,
        'salt': salt,
        'is_configured': 1,
        'configured_at': now,
      },
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
  }

  /// Reset an admin slot back to unconfigured
  Future<void> resetAdminSlot(int slotNumber) async {
    final db = await database;
    await db.update(
      'admin_identities',
      {
        'full_name': null,
        'email': null,
        'password_hash': null,
        'salt': null,
        'is_configured': 0,
        'configured_at': null,
      },
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
  }

  // --- Complaints CRUD & Lifecycle ---

  /// Generate unique tracking number (e.g. CMP-20261022-8392)
  String _generateTrackingNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = Random().nextInt(9000) + 1000;
    return 'CMP-$dateStr-$rand';
  }

  /// Create a complaint record with optional evidence attachments
  Future<Complaint> createComplaint({
    required String title,
    required String description,
    required String categoryId,
    required String complainantId,
    required String complainantName,
    String? locationContext,
    String priority = 'MEDIUM',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final db = await database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final complaintId = 'cmp-${now.millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final trackingNumber = _generateTrackingNumber();

    // Look up category and department
    final catRows = await db.query('categories', where: 'id = ?', whereArgs: [categoryId]);
    final catName = catRows.isNotEmpty ? (catRows.first['name'] as String) : 'General';
    final deptId = catRows.isNotEmpty ? (catRows.first['department_id'] as String) : 'dept-general';
    final deptName = catRows.isNotEmpty ? (catRows.first['department_name'] as String) : 'General Affairs';

    final complaintMap = {
      'id': complaintId,
      'tracking_number': trackingNumber,
      'organization_id': 'org-sengunthar',
      'category_id': categoryId,
      'category_name': catName,
      'department_id': deptId,
      'department_name': deptName,
      'complainant_id': complainantId,
      'complainant_name': complainantName,
      'assignee_id': null,
      'assignee_name': null,
      'title': title.trim(),
      'description': description.trim(),
      'location_context': locationContext?.trim(),
      'status': 'SUBMITTED',
      'priority': priority,
      'resolution_summary': null,
      'rejection_reason': null,
      'reopen_count': 0,
      'is_escalated': 0,
      'first_responded_at': null,
      'resolved_at': null,
      'closed_at': null,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    await db.insert('complaints', complaintMap);

    // Insert attachments if any
    final List<ComplaintAttachment> savedAttachments = [];
    for (var att in attachments) {
      final attId = 'att-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      final attMap = {
        'id': attId,
        'complaint_id': complaintId,
        'file_path': att['file_path'] ?? '',
        'filename': att['filename'] ?? 'file',
        'file_size': att['file_size'] ?? 0,
        'file_type': att['file_type'] ?? 'document',
        'content_type': att['content_type'] ?? 'application/octet-stream',
        'uploader_id': complainantId,
        'uploader_name': complainantName,
        'created_at': nowIso,
      };
      await db.insert('evidence_attachments', attMap);
      savedAttachments.add(ComplaintAttachment.fromJson(attMap));
    }

    // Insert initial history event
    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': complainantId,
      'actor_name': complainantName,
      'event_type': 'STATUS_CHANGE',
      'from_status': null,
      'to_status': 'SUBMITTED',
      'reason': 'Grievance submitted by complainant',
      'created_at': nowIso,
    });

    return Complaint(
      id: complaintId,
      trackingNumber: trackingNumber,
      organizationId: 'org-sengunthar',
      categoryId: categoryId,
      categoryName: catName,
      departmentId: deptId,
      departmentName: deptName,
      complainantId: complainantId,
      complainantName: complainantName,
      title: title.trim(),
      description: description.trim(),
      locationContext: locationContext?.trim(),
      status: 'SUBMITTED',
      priority: priority,
      reopenCount: 0,
      isEscalated: false,
      createdAt: now,
      updatedAt: now,
      commentsCount: 0,
      attachmentsCount: savedAttachments.length,
      attachments: savedAttachments,
    );
  }

  /// Fetch list of complaints (filtered by user if COMPLAINANT, all if ADMIN)
  Future<List<Complaint>> getComplaints({
    String? userId,
    String? role,
    String? status,
    String? priority,
    String? searchKeyword,
    String? assignedAdminId,
    bool unassignedOnly = false,
    String sortBy = 'created_at DESC',
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // If complainant, restrict to their own complaints
    if (role == 'COMPLAINANT' && userId != null && userId.isNotEmpty) {
      whereClauses.add('complainant_id = ?');
      whereArgs.add(userId);
    }

    if (status != null && status.isNotEmpty && status != 'ALL') {
      if (status == 'PENDING') {
        whereClauses.add('status NOT IN ("RESOLVED", "CLOSED", "REJECTED")');
      } else if (status == 'RESOLVED_ALL') {
        whereClauses.add('status IN ("RESOLVED", "CLOSED")');
      } else if (status == 'NEW_UNREVIEWED') {
        whereClauses.add('status IN ("SUBMITTED", "UNDER_REVIEW")');
      } else if (status == 'INVESTIGATION') {
        whereClauses.add('status IN ("IN_PROGRESS", "ASSIGNED")');
      } else {
        whereClauses.add('status = ?');
        whereArgs.add(status);
      }
    }

    if (priority != null && priority.isNotEmpty && priority != 'ALL') {
      if (priority == 'HIGH_URGENT') {
        whereClauses.add('priority IN ("CRITICAL", "HIGH")');
      } else {
        whereClauses.add('priority = ?');
        whereArgs.add(priority);
      }
    }

    if (unassignedOnly) {
      whereClauses.add('(assignee_id IS NULL OR assignee_id = "")');
    } else if (assignedAdminId != null && assignedAdminId.isNotEmpty) {
      whereClauses.add('assignee_id = ?');
      whereArgs.add(assignedAdminId);
    }

    if (searchKeyword != null && searchKeyword.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR description LIKE ? OR tracking_number LIKE ? OR complainant_name LIKE ?)');
      final term = '%${searchKeyword.trim()}%';
      whereArgs.addAll([term, term, term, term]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final rows = await db.query(
      'complaints',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: sortBy.isNotEmpty ? sortBy : 'created_at DESC',
    );

    final List<Complaint> result = [];
    for (var row in rows) {
      final complaintId = row['id'] as String;
      // Get counts
      final attCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM evidence_attachments WHERE complaint_id = ?',
        [complaintId],
      )) ?? 0;
      final commCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaint_comments WHERE complaint_id = ?',
        [complaintId],
      )) ?? 0;

      final map = Map<String, dynamic>.from(row);
      map['attachments_count'] = attCount;
      map['comments_count'] = commCount;
      result.add(Complaint.fromJson(map));
    }

    return result;
  }

  /// Get detailed complaint with comments, attachments, history, feedback
  Future<Complaint?> getComplaintDetail(String complaintId, {bool isComplainant = false}) async {
    final db = await database;
    final rows = await db.query('complaints', where: 'id = ?', whereArgs: [complaintId]);
    if (rows.isEmpty) return null;

    final compMap = Map<String, dynamic>.from(rows.first);

    // Attachments
    final attRows = await db.query('evidence_attachments', where: 'complaint_id = ?', whereArgs: [complaintId], orderBy: 'created_at ASC');
    compMap['attachments'] = attRows;
    compMap['attachments_count'] = attRows.length;

    // Comments: strictly filter out internal notes if viewer is complainant
    final commRows = isComplainant
        ? await db.query('complaint_comments', where: 'complaint_id = ? AND is_internal_note = 0', whereArgs: [complaintId], orderBy: 'created_at ASC')
        : await db.query('complaint_comments', where: 'complaint_id = ?', whereArgs: [complaintId], orderBy: 'created_at ASC');
    compMap['comments'] = commRows;
    compMap['comments_count'] = commRows.length;

    // History
    final histRows = await db.query('complaint_history', where: 'complaint_id = ?', whereArgs: [complaintId], orderBy: 'created_at DESC');
    compMap['history'] = histRows;

    // Feedback
    final feedRows = await db.query('complaint_feedback', where: 'complaint_id = ?', whereArgs: [complaintId]);
    if (feedRows.isNotEmpty) {
      compMap['feedback'] = feedRows.first;
    }

    return Complaint.fromJson(compMap);
  }

  /// Assign complaint to designated administrator slot
  Future<Complaint> assignComplaint({
    required String complaintId,
    required String adminSlotId,
    required String adminName,
    required String actorId,
    required String actorName,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'complaints',
      {
        'assignee_id': adminSlotId,
        'assignee_name': adminName,
        'status': 'IN_PROGRESS',
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [complaintId],
    );

    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': actorId,
      'actor_name': actorName,
      'event_type': 'ASSIGNMENT',
      'from_status': 'SUBMITTED',
      'to_status': 'IN_PROGRESS',
      'reason': 'Assigned to $adminName for investigation',
      'created_at': nowIso,
    });

    return (await getComplaintDetail(complaintId))!;
  }

  /// Change complaint priority with justification
  Future<Complaint> changePriority({
    required String complaintId,
    required String priority,
    required String reason,
    required String actorId,
    required String actorName,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();

    final cur = await db.query('complaints', columns: ['priority'], where: 'id = ?', whereArgs: [complaintId]);
    final oldPriority = cur.isNotEmpty ? (cur.first['priority'] as String) : 'MEDIUM';

    await db.update(
      'complaints',
      {
        'priority': priority,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [complaintId],
    );

    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': actorId,
      'actor_name': actorName,
      'event_type': 'PRIORITY_CHANGE',
      'old_value': oldPriority,
      'new_value': priority,
      'reason': reason.isNotEmpty ? reason : 'Priority updated to $priority',
      'created_at': nowIso,
    });

    return (await getComplaintDetail(complaintId))!;
  }

  /// Request additional information from complainant
  Future<Complaint> requestAdditionalInformation({
    required String complaintId,
    required String requestMessage,
    required String actorId,
    required String actorName,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'complaints',
      {
        'status': 'AWAITING_USER',
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [complaintId],
    );

    await db.insert('complaint_comments', {
      'id': 'comm-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'user_id': actorId,
      'user_name': actorName,
      'comment_text': '📋 Official Request for Additional Information:\n$requestMessage',
      'is_internal_note': 0,
      'created_at': nowIso,
    });

    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': actorId,
      'actor_name': actorName,
      'event_type': 'INFO_REQUESTED',
      'from_status': 'IN_PROGRESS',
      'to_status': 'AWAITING_USER',
      'reason': requestMessage,
      'created_at': nowIso,
    });

    return (await getComplaintDetail(complaintId))!;
  }

  /// Record specific action taken by administrator
  Future<Complaint> recordActionTaken({
    required String complaintId,
    required String actionDetails,
    required String actorId,
    required String actorName,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'complaints',
      {
        'status': 'IN_PROGRESS',
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [complaintId],
    );

    await db.insert('complaint_comments', {
      'id': 'comm-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'user_id': actorId,
      'user_name': actorName,
      'comment_text': '🛠️ Action Taken by Administrator:\n$actionDetails',
      'is_internal_note': 0,
      'created_at': nowIso,
    });

    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': actorId,
      'actor_name': actorName,
      'event_type': 'ACTION_TAKEN',
      'reason': actionDetails,
      'created_at': nowIso,
    });

    return (await getComplaintDetail(complaintId))!;
  }

  /// Complainant submits response to requested information
  Future<Complaint> submitComplainantResponse({
    required String complaintId,
    required String responseText,
    required String complainantId,
    required String complainantName,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'complaints',
      {
        'status': 'IN_PROGRESS',
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [complaintId],
    );

    await db.insert('complaint_comments', {
      'id': 'comm-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'user_id': complainantId,
      'user_name': complainantName,
      'comment_text': responseText,
      'is_internal_note': 0,
      'created_at': nowIso,
    });

    for (var att in attachments) {
      await db.insert('evidence_attachments', {
        'id': 'att-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
        'complaint_id': complaintId,
        'file_path': att['file_path'] ?? '',
        'filename': att['filename'] ?? 'attachment',
        'file_size': att['file_size'] ?? 0,
        'file_type': att['file_type'] ?? 'document',
        'content_type': att['content_type'] ?? 'application/octet-stream',
        'uploader_id': complainantId,
        'uploader_name': complainantName,
        'created_at': nowIso,
      });
    }

    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': complainantId,
      'actor_name': complainantName,
      'event_type': 'INFO_PROVIDED',
      'from_status': 'AWAITING_USER',
      'to_status': 'IN_PROGRESS',
      'reason': 'Complainant submitted requested details and evidence',
      'created_at': nowIso,
    });

    return (await getComplaintDetail(complaintId))!;
  }

  /// Update complaint status (Admin / Workflow action)
  Future<Complaint> updateComplaintStatus({
    required String complaintId,
    required String toStatus,
    required String actorId,
    required String actorName,
    String? reason,
    String? resolutionSummary,
  }) async {
    final db = await database;
    final currentRows = await db.query('complaints', where: 'id = ?', whereArgs: [complaintId]);
    if (currentRows.isEmpty) throw Exception('Complaint not found.');

    final current = currentRows.first;
    final fromStatus = current['status'] as String;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final updateData = <String, dynamic>{
      'status': toStatus,
      'updated_at': nowIso,
    };

    if (current['first_responded_at'] == null) {
      updateData['first_responded_at'] = nowIso;
    }

    if (toStatus == 'RESOLVED') {
      updateData['resolved_at'] = nowIso;
      if (resolutionSummary != null && resolutionSummary.isNotEmpty) {
        updateData['resolution_summary'] = resolutionSummary.trim();
      }
    } else if (toStatus == 'CLOSED') {
      updateData['closed_at'] = nowIso;
    } else if (toStatus == 'REOPENED') {
      updateData['reopen_count'] = ((current['reopen_count'] as int? ?? 0) + 1);
    } else if (toStatus == 'REJECTED') {
      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason.trim();
      }
    }

    await db.update('complaints', updateData, where: 'id = ?', whereArgs: [complaintId]);

    // Record History item
    await db.insert('complaint_history', {
      'id': 'hist-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'actor_id': actorId,
      'actor_name': actorName,
      'event_type': 'STATUS_CHANGE',
      'from_status': fromStatus,
      'to_status': toStatus,
      'reason': resolutionSummary ?? reason ?? 'Status transitioned to $toStatus',
      'created_at': nowIso,
    });

    // Notify complainant
    final complainantId = current['complainant_id'] as String;
    await db.insert('notifications', {
      'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': complainantId,
      'title': 'Case Status: $toStatus',
      'message': 'Your grievance "${current['title']}" was updated to $toStatus by $actorName.',
      'notification_type': 'STATUS_CHANGE',
      'is_read': 0,
      'complaint_id': complaintId,
      'created_at': nowIso,
    });

    return (await getComplaintDetail(complaintId))!;
  }

  /// Add comment or administrative note
  Future<void> addComment({
    required String complaintId,
    required String userId,
    required String userName,
    required String commentText,
    bool isInternalNote = false,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    await db.insert('complaint_comments', {
      'id': 'comm-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'user_id': userId,
      'user_name': userName,
      'comment_text': commentText.trim(),
      'is_internal_note': isInternalNote ? 1 : 0,
      'created_at': nowIso,
    });
  }

  /// Submit satisfaction feedback
  Future<void> submitFeedback({
    required String complaintId,
    required int rating,
    String? comments,
    bool resolutionSatisfactory = true,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    await db.insert('complaint_feedback', {
      'id': 'feed-${DateTime.now().millisecondsSinceEpoch}',
      'complaint_id': complaintId,
      'rating': rating,
      'comments': comments?.trim(),
      'resolution_satisfactory': resolutionSatisfactory ? 1 : 0,
      'created_at': nowIso,
    });
  }

  /// Calculate real-time Dashboard Metrics directly from local SQLite
  Future<DashboardData> getDashboardMetrics({
    required String role,
    String? userId,
  }) async {
    final db = await database;

    if (role == 'COMPLAINANT' && userId != null) {
      final total = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE complainant_id = ?',
        [userId],
      )) ?? 0;
      final submitted = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE complainant_id = ? AND status = "SUBMITTED"',
        [userId],
      )) ?? 0;
      final inProgress = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE complainant_id = ? AND status = "IN_PROGRESS"',
        [userId],
      )) ?? 0;
      final awaiting = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE complainant_id = ? AND status = "AWAITING_USER"',
        [userId],
      )) ?? 0;
      final resolved = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE complainant_id = ? AND status IN ("RESOLVED", "CLOSED")',
        [userId],
      )) ?? 0;

      return DashboardData(
        role: 'COMPLAINANT',
        metrics: {
          'total_complaints': total,
          'submitted_count': submitted,
          'in_progress_count': inProgress,
          'awaiting_user_count': awaiting,
          'resolved_closed_count': resolved,
        },
      );
    } else {
      // Real Admin / Complaint Officer Metrics calculated from stored complaint records
      final totalReceived = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints',
      )) ?? 0;

      final newUnreviewed = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE status IN ("SUBMITTED", "UNDER_REVIEW")',
      )) ?? 0;

      final pendingCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE status NOT IN ("RESOLVED", "CLOSED", "REJECTED")',
      )) ?? 0;

      final underInvestigation = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE status IN ("IN_PROGRESS", "ASSIGNED")',
      )) ?? 0;

      final awaitingInfo = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE status = "AWAITING_USER"',
      )) ?? 0;

      final resolvedCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE status IN ("RESOLVED", "CLOSED")',
      )) ?? 0;

      final rejectedCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE status = "REJECTED"',
      )) ?? 0;

      final highPriority = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE priority IN ("CRITICAL", "HIGH")',
      )) ?? 0;

      final recentlyUpdated = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM complaints WHERE updated_at >= datetime("now", "-7 days")',
      )) ?? 0;

      // Department distribution
      final deptRows = await db.rawQuery(
        'SELECT department_name, COUNT(*) as cnt FROM complaints GROUP BY department_name',
      );
      final deptMap = <String, int>{};
      for (var r in deptRows) {
        deptMap[r['department_name'] as String] = (r['cnt'] as int);
      }

      // Category distribution
      final catRows = await db.rawQuery(
        'SELECT category_name, COUNT(*) as cnt FROM complaints GROUP BY category_name',
      );
      final catMap = <String, int>{};
      for (var r in catRows) {
        catMap[r['category_name'] as String] = (r['cnt'] as int);
      }

      // Average feedback rating
      final avgRatingRow = await db.rawQuery('SELECT AVG(rating) as avg_r FROM complaint_feedback');
      double avgRating = 0.0;
      if (avgRatingRow.isNotEmpty && avgRatingRow.first['avg_r'] != null) {
        avgRating = (avgRatingRow.first['avg_r'] as num).toDouble();
      }

      return DashboardData(
        role: 'ORG_ADMIN',
        metrics: {
          'total_received': totalReceived,
          'new_unreviewed': newUnreviewed,
          'pending_count': pendingCount,
          'under_investigation': underInvestigation,
          'awaiting_information': awaitingInfo,
          'resolved_count': resolvedCount,
          'rejected_count': rejectedCount,
          'high_priority': highPriority,
          'recently_updated': recentlyUpdated > 0 ? recentlyUpdated : (totalReceived > 0 ? totalReceived : 0),
          'open_complaints': pendingCount,
          'resolved_complaints': resolvedCount,
          'department_distribution': deptMap,
          'category_distribution': catMap,
          'avg_first_response_hours': 0.0,
          'avg_resolution_hours': 0.0,
          'sla_breaches_count': 0,
          'feedback_avg_rating': avgRating,
        },
      );
    }
  }

  /// Retrieve notifications
  Future<List<NotificationItem>> getNotifications(String userId) async {
    final db = await database;
    final rows = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => NotificationItem.fromJson(r)).toList();
  }

  /// Mark notification read
  Future<void> markNotificationRead(String notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  /// Get Categories
  Future<List<Category>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((r) => Category.fromJson(r)).toList();
  }

  /// Get Departments
  Future<List<Department>> getDepartments() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT department_id as id, department_name as name FROM categories');
    return rows.map((r) => Department.fromJson(r)).toList();
  }

  /// Local AI keyword-based classifier
  Future<Map<String, dynamic>> classifyComplaint(String title, String description) async {
    final text = '$title $description'.toLowerCase();
    final categories = await getCategories();

    if (text.contains('wifi') || text.contains('internet') || text.contains('network') || text.contains('router')) {
      final match = categories.firstWhere((c) => c.id == 'cat-wifi', orElse: () => categories.first);
      return {
        'category_id': match.id,
        'category_name': match.name,
        'recommended_priority': 'HIGH',
        'confidence_score': 0.94,
        'department_name': match.departmentName,
      };
    } else if (text.contains('hostel') || text.contains('water') || text.contains('plumb') || text.contains('leak') || text.contains('room')) {
      final match = categories.firstWhere((c) => c.id == 'cat-hostel', orElse: () => categories.first);
      return {
        'category_id': match.id,
        'category_name': match.name,
        'recommended_priority': 'MEDIUM',
        'confidence_score': 0.91,
        'department_name': match.departmentName,
      };
    } else if (text.contains('lab') || text.contains('pc') || text.contains('computer') || text.contains('hardware') || text.contains('software')) {
      final match = categories.firstWhere((c) => c.id == 'cat-lab', orElse: () => categories.first);
      return {
        'category_id': match.id,
        'category_name': match.name,
        'recommended_priority': 'MEDIUM',
        'confidence_score': 0.88,
        'department_name': match.departmentName,
      };
    } else if (text.contains('exam') || text.contains('class') || text.contains('timetable') || text.contains('schedule') || text.contains('lecture')) {
      final match = categories.firstWhere((c) => c.id == 'cat-academic', orElse: () => categories.first);
      return {
        'category_id': match.id,
        'category_name': match.name,
        'recommended_priority': 'HIGH',
        'confidence_score': 0.89,
        'department_name': match.departmentName,
      };
    } else if (text.contains('food') || text.contains('canteen') || text.contains('mess') || text.contains('meal')) {
      final match = categories.firstWhere((c) => c.id == 'cat-canteen', orElse: () => categories.first);
      return {
        'category_id': match.id,
        'category_name': match.name,
        'recommended_priority': 'MEDIUM',
        'confidence_score': 0.87,
        'department_name': match.departmentName,
      };
    } else if (text.contains('security') || text.contains('theft') || text.contains('guard') || text.contains('gate') || text.contains('stolen')) {
      final match = categories.firstWhere((c) => c.id == 'cat-security', orElse: () => categories.first);
      return {
        'category_id': match.id,
        'category_name': match.name,
        'recommended_priority': 'CRITICAL',
        'confidence_score': 0.93,
        'department_name': match.departmentName,
      };
    }

    final defaultCat = categories.isNotEmpty
        ? categories.first
        : Category(
            id: 'cat-general',
            name: 'General Grievance',
            organizationId: 'org-sengunthar',
            departmentId: 'dept-general',
            departmentName: 'General Affairs',
            defaultPriority: 'MEDIUM',
            isActive: true,
          );
    return {
      'category_id': defaultCat.id,
      'category_name': defaultCat.name,
      'recommended_priority': 'MEDIUM',
      'confidence_score': 0.70,
      'department_name': defaultCat.departmentName,
    };
  }

  /// Local duplicate checker against existing device complaints
  Future<List<Map<String, dynamic>>> checkDuplicates(String title, String description) async {
    final db = await database;
    final all = await db.query('complaints', columns: ['id', 'tracking_number', 'title', 'description']);
    final cleanInput = title.trim().toLowerCase();
    final inputWords = cleanInput.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();

    final List<Map<String, dynamic>> duplicates = [];
    for (var c in all) {
      final cTitle = (c['title'] as String).toLowerCase();
      final cWords = cTitle.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
      final intersection = inputWords.intersection(cWords);

      if (intersection.isNotEmpty) {
        final score = intersection.length / max(inputWords.length, 1);
        if (score >= 0.4) {
          duplicates.add({
            'tracking_number': c['tracking_number'],
            'title': c['title'],
            'similarity_score': (score > 1.0 ? 0.95 : score),
          });
        }
      }
    }
    return duplicates;
  }

  /// Get local complaints that have not been pushed to the server yet
  Future<List<Complaint>> getUnsyncedComplaints() async {
    final db = await database;
    final rows = await db.query(
      'complaints',
      where: 'is_synced = 0 OR is_synced IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => Complaint.fromJson(r)).toList();
  }

  /// Mark local complaint as synced with remote server ID
  Future<void> markComplaintSynced(String localId, String remoteId) async {
    final db = await database;
    await db.update(
      'complaints',
      {
        'is_synced': 1,
        'remote_id': remoteId,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Upsert remote complaint pulled from central FastAPI backend
  Future<bool> upsertRemoteComplaint({
    required String remoteId,
    required String trackingNumber,
    required String title,
    required String description,
    required String categoryId,
    required String categoryName,
    required String departmentName,
    required String complainantName,
    required String complainantId,
    required String status,
    required String priority,
    String? assigneeName,
    required String createdAtIso,
    required String updatedAtIso,
  }) async {
    final db = await database;
    final existing = await db.query(
      'complaints',
      where: 'remote_id = ? OR tracking_number = ?',
      whereArgs: [remoteId, trackingNumber],
    );

    if (existing.isEmpty) {
      await db.insert('complaints', {
        'id': 'remote-$remoteId',
        'remote_id': remoteId,
        'tracking_number': trackingNumber,
        'organization_id': 'org-sengunthar',
        'category_id': categoryId,
        'category_name': categoryName,
        'department_id': 'dept-general',
        'department_name': departmentName,
        'complainant_id': complainantId,
        'complainant_name': complainantName,
        'assignee_name': assigneeName,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'is_synced': 1,
        'created_at': createdAtIso,
        'updated_at': updatedAtIso,
      });
      return true;
    } else {
      // Update if remote status changed
      final current = existing.first;
      if (current['status'] != status || current['assignee_name'] != assigneeName) {
        await db.update(
          'complaints',
          {
            'status': status,
            'assignee_name': assigneeName,
            'updated_at': updatedAtIso,
            'is_synced': 1,
          },
          where: 'id = ?',
          whereArgs: [current['id']],
        );
        return true;
      }
    }
    return false;
  }
}


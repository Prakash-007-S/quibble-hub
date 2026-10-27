import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/admin_identity.dart';
import '../models/organization.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;

  User? _currentUser;
  Organization? _activeOrganization;
  List<Organization> _availableOrganizations = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  Organization? get activeOrganization => _activeOrganization;
  List<Organization> get availableOrganizations => _availableOrganizations;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isServerReachable => true; // Always true in offline-first mode
  String? get serverStatusMessage => null;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  String? get authToken => null;

  String get activeRole {
    if (_currentUser == null) return 'GUEST';
    if (_currentUser!.isPlatformAdmin) return 'ORG_ADMIN';
    if (_currentUser!.memberships.isNotEmpty) {
      return _currentUser!.memberships.first.role;
    }
    return 'COMPLAINANT';
  }

  bool get isComplainant => activeRole == 'COMPLAINANT';
  bool get isStaff => activeRole == 'STAFF';
  bool get isDeptManager => activeRole == 'DEPT_MANAGER';
  bool get isOrgAdmin => activeRole == 'ORG_ADMIN' || activeRole == 'PLATFORM_ADMIN';

  AuthProvider() {
    _initDefaultOrganizations();
  }

  void _initDefaultOrganizations() {
    _availableOrganizations = [
      Organization(
        id: 'org-sengunthar',
        name: 'Sengunthar Engineering College',
        slug: 'sengunthar',
        orgType: 'COLLEGE',
        settings: const {},
        isActive: true,
      ),
    ];
    _activeOrganization = _availableOrganizations.first;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize local SQLite database
      await _db.database;

      // Restore session if available from SQLite app_settings
      final savedEmail = await _db.getSetting('saved_session_email');
      final savedRole = await _db.getSetting('saved_session_role');

      if (savedEmail != null && savedEmail.isNotEmpty) {
        if (savedRole == 'ORG_ADMIN') {
          // Check if admin slot still configured
          final admins = await _db.getAdminIdentities();
          final match = admins.where((a) => a.isConfigured && a.email?.toLowerCase() == savedEmail.toLowerCase());
          if (match.isNotEmpty) {
            final a = match.first;
            _currentUser = User(
              id: 'admin-slot-${a.slotNumber}',
              email: a.email!,
              fullName: a.fullName ?? 'Administrator #${a.slotNumber}',
              isPlatformAdmin: true,
              memberships: [
                Membership(
                  id: 'mem-admin-${a.slotNumber}',
                  organizationId: 'org-sengunthar',
                  organizationName: 'Sengunthar Engineering College',
                  orgSlug: 'sengunthar',
                  orgType: 'COLLEGE',
                  role: 'ORG_ADMIN',
                  isActive: true,
                ),
              ],
            );
          }
        } else {
          // Check normal users
          final dbInstance = await _db.database;
          final userRows = await dbInstance.query('users', where: 'LOWER(email) = ?', whereArgs: [savedEmail.toLowerCase()]);
          if (userRows.isNotEmpty) {
            final u = userRows.first;
            _currentUser = User(
              id: u['id'] as String,
              email: u['email'] as String,
              fullName: u['full_name'] as String,
              isPlatformAdmin: false,
              memberships: [
                Membership(
                  id: 'mem-${u['id']}',
                  organizationId: 'org-sengunthar',
                  organizationName: 'Sengunthar Engineering College',
                  orgSlug: 'sengunthar',
                  orgType: 'COLLEGE',
                  role: 'COMPLAINANT',
                  isActive: true,
                ),
              ],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password, {String? organizationId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _db.authenticate(email: email, password: password);
      if (user == null) {
        _errorMessage = 'No account found with this email. Please register or verify admin configuration.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;

      // Save session in SQLite
      await _db.setSetting('saved_session_email', user.email);
      await _db.setSetting('saved_session_role', user.isPlatformAdmin ? 'ORG_ADMIN' : 'COMPLAINANT');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String fullName,
    required String password,
    required String organizationId,
    String role = 'COMPLAINANT',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Normal registration strictly creates a COMPLAINANT
      final user = await _db.registerUser(
        email: email,
        fullName: fullName,
        password: password,
      );

      _currentUser = user;

      // Save session in SQLite
      await _db.setSetting('saved_session_email', user.email);
      await _db.setSetting('saved_session_role', 'COMPLAINANT');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<AdminIdentity>> getAdminSlots() async {
    try {
      return await _db.getAdminIdentities();
    } catch (e) {
      debugPrint('getAdminSlots fallback: $e');
      return List.generate(
        4,
        (i) => AdminIdentity(slotNumber: i + 1, isConfigured: false),
      );
    }
  }

  Future<bool> configureAdminSlot({
    required int slotNumber,
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      await _db.configureAdminSlot(
        slotNumber: slotNumber,
        fullName: fullName,
        email: email,
        password: password,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> resetAdminSlot(int slotNumber) async {
    await _db.resetAdminSlot(slotNumber);
    notifyListeners();
  }

  Future<void> switchOrganization(Organization org) async {
    _activeOrganization = org;
    notifyListeners();
  }

  /// Direct 1-tap sign-in to the Authority / Organization portal
  Future<bool> loginAsAuthority({int slotNumber = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final slots = await _db.getAdminIdentities();
      final target = slots.firstWhere((s) => s.slotNumber == slotNumber, orElse: () => slots.first);
      if (target.email != null && target.isConfigured) {
        _currentUser = User(
          id: 'admin-slot-${target.slotNumber}',
          email: target.email!,
          fullName: target.fullName ?? 'Authorized Official #${target.slotNumber}',
          isPlatformAdmin: true,
          memberships: [
            Membership(
              id: 'mem-admin-${target.slotNumber}',
              organizationId: 'org-sengunthar',
              organizationName: 'Sengunthar Engineering College',
              orgSlug: 'sengunthar',
              orgType: 'COLLEGE',
              role: 'ORG_ADMIN',
              isActive: true,
            ),
          ],
        );

        await _db.setSetting('saved_session_email', target.email);
        await _db.setSetting('saved_session_role', 'ORG_ADMIN');

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Authority slot #$slotNumber is not configured.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Direct switch back to the Complainant portal
  Future<bool> loginAsFirstComplainant() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await _db.database;
      final rows = await db.query('users', orderBy: 'created_at ASC', limit: 1);
      if (rows.isNotEmpty) {
        final u = rows.first;
        final id = u['id'] as String;
        final email = u['email'] as String;
        final name = u['full_name'] as String;

        _currentUser = User(
          id: id,
          email: email,
          fullName: name,
          isPlatformAdmin: false,
          memberships: [
            Membership(
              id: 'mem-$id',
              organizationId: 'org-sengunthar',
              organizationName: 'Sengunthar Engineering College',
              orgSlug: 'sengunthar',
              orgType: 'COLLEGE',
              role: 'COMPLAINANT',
              isActive: true,
            ),
          ],
        );

        await _db.setSetting('saved_session_email', email);
        await _db.setSetting('saved_session_role', 'COMPLAINANT');

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        await logout();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.setSetting('saved_session_email', null);
      await _db.setSetting('saved_session_role', null);
    } catch (e) {
      debugPrint('Error clearing session setting: $e');
    }

    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}

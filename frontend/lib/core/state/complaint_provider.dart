import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/analytics.dart';
import '../models/category.dart';
import '../models/complaint.dart';
import '../models/department.dart';
import '../models/notification.dart';
import '../services/evidence_service.dart';
import '../services/sync_service.dart';

class ComplaintProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;

  final SyncService _syncService = SyncService();

  List<Complaint> _complaints = [];
  int _totalComplaints = 0;
  List<Category> _categories = [];
  List<Department> _departments = [];
  DashboardData? _dashboardData;
  List<NotificationItem> _notifications = [];

  Complaint? _currentDetail;
  bool _isLoadingList = false;
  bool _isLoadingDetail = false;
  bool _isSubmitting = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _lastSyncMessage;

  // Selected filter states
  String? selectedStatus;
  String? selectedPriority;
  String? searchKeyword;
  String workloadFilter = 'ALL'; // 'ALL', 'ASSIGNED_TO_ME', 'UNASSIGNED'
  String sortBy = 'created_at DESC';

  List<Complaint> get complaints => _complaints;
  int get totalComplaints => _totalComplaints;
  List<Category> get categories => _categories;
  List<Department> get departments => _departments;
  DashboardData? get dashboardData => _dashboardData;
  List<NotificationItem> get notifications => _notifications;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  Complaint? get currentDetail => _currentDetail;
  bool get isLoadingList => _isLoadingList;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isSubmitting => _isSubmitting;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get lastSyncMessage => _lastSyncMessage;

  void setFilterStatus(String? status) {
    selectedStatus = status;
    notifyListeners();
  }

  void setFilterPriority(String? priority) {
    selectedPriority = priority;
    notifyListeners();
  }

  void setWorkloadFilter(String filter) {
    workloadFilter = filter;
    notifyListeners();
  }

  void setSortBy(String sort) {
    sortBy = sort;
    notifyListeners();
  }

  Future<void> fetchComplaints({
    bool resetFilters = false,
    String? userId,
    String? role,
  }) async {
    _isLoadingList = true;
    _errorMessage = null;
    notifyListeners();

    if (resetFilters) {
      selectedStatus = null;
      selectedPriority = null;
      searchKeyword = null;
      workloadFilter = 'ALL';
      sortBy = 'created_at DESC';
    }

    try {
      final assignedId = (workloadFilter == 'ASSIGNED_TO_ME') ? userId : null;
      final unassigned = (workloadFilter == 'UNASSIGNED');

      _complaints = await _db.getComplaints(
        userId: userId,
        role: role,
        status: selectedStatus,
        priority: selectedPriority,
        searchKeyword: searchKeyword,
        assignedAdminId: assignedId,
        unassignedOnly: unassigned,
        sortBy: sortBy,
      );
      _totalComplaints = _complaints.length;
    } catch (e) {
      _errorMessage = 'Failed to load complaints: $e';
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategoriesAndDepartments() async {
    try {
      _categories = await _db.getCategories();
      _departments = await _db.getDepartments();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchDashboardMetrics({String role = 'COMPLAINANT', String? userId}) async {
    try {
      _dashboardData = await _db.getDashboardMetrics(role: role, userId: userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchNotifications([String? userId]) async {
    if (userId == null) return;
    try {
      _notifications = await _db.getNotifications(userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationRead(String notifId) async {
    try {
      await _db.markNotificationRead(notifId);
      final idx = _notifications.indexWhere((n) => n.id == notifId);
      if (idx != -1) {
        final old = _notifications[idx];
        _notifications[idx] = NotificationItem(
          id: old.id,
          title: old.title,
          message: old.message,
          notificationType: old.notificationType,
          isRead: true,
          complaintId: old.complaintId,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Complaint?> loadComplaintDetail(String complaintId, {bool isComplainant = false}) async {
    _isLoadingDetail = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentDetail = await _db.getComplaintDetail(complaintId, isComplainant: isComplainant);
      return _currentDetail;
    } catch (e) {
      _errorMessage = 'Failed to load complaint: $e';
      return null;
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getAIClassification(String title, String description) async {
    try {
      return await _db.classifyComplaint(title, description);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> checkDuplicates(String title, String description) async {
    try {
      return await _db.checkDuplicates(title, description);
    } catch (_) {
      return [];
    }
  }

  Future<bool> createComplaint({
    required String title,
    required String description,
    required String categoryId,
    required String complainantId,
    required String complainantName,
    String? locationContext,
    String? priority,
    List<PickedEvidence> evidenceFiles = const [],
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Copy each evidence attachment into app's private persistent storage
      final List<Map<String, dynamic>> attachmentsData = [];
      for (var evidence in evidenceFiles) {
        final persistentPath = await EvidenceService.persistAttachment(evidence);
        attachmentsData.add({
          'file_path': persistentPath,
          'filename': evidence.fileName,
          'file_size': evidence.fileSize,
          'file_type': evidence.fileType,
          'content_type': evidence.mimeType,
        });
      }

      // 2. Insert into SQLite
      final newComplaint = await _db.createComplaint(
        title: title,
        description: description,
        categoryId: categoryId,
        complainantId: complainantId,
        complainantName: complainantName,
        locationContext: locationContext,
        priority: priority ?? 'MEDIUM',
        attachments: attachmentsData,
      );

      _complaints.insert(0, newComplaint);
      _totalComplaints += 1;
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Submission failed: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> transitionStatus({
    required String complaintId,
    required String toStatus,
    required String actorId,
    required String actorName,
    String? reason,
    String? resolutionSummary,
  }) async {
    try {
      _currentDetail = await _db.updateComplaintStatus(
        complaintId: complaintId,
        toStatus: toStatus,
        actorId: actorId,
        actorName: actorName,
        reason: reason,
        resolutionSummary: resolutionSummary,
      );

      // Refresh list in background
      await fetchComplaints();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Status update failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addComment({
    required String complaintId,
    required String userId,
    required String userName,
    required String commentText,
    bool isInternalNote = false,
  }) async {
    try {
      await _db.addComment(
        complaintId: complaintId,
        userId: userId,
        userName: userName,
        commentText: commentText,
        isInternalNote: isInternalNote,
      );

      await loadComplaintDetail(complaintId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to post comment: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitFeedback({
    required String complaintId,
    required int rating,
    String? comments,
    bool resolutionSatisfactory = true,
  }) async {
    try {
      await _db.submitFeedback(
        complaintId: complaintId,
        rating: rating,
        comments: comments,
        resolutionSatisfactory: resolutionSatisfactory,
      );

      await loadComplaintDetail(complaintId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit feedback: $e';
      notifyListeners();
      return false;
    }
  }

  /// Assign complaint to designated admin
  Future<bool> assignComplaint({
    required String complaintId,
    required String adminSlotId,
    required String adminName,
    required String actorId,
    required String actorName,
  }) async {
    try {
      _currentDetail = await _db.assignComplaint(
        complaintId: complaintId,
        adminSlotId: adminSlotId,
        adminName: adminName,
        actorId: actorId,
        actorName: actorName,
      );
      await fetchComplaints();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to assign complaint: $e';
      notifyListeners();
      return false;
    }
  }

  /// Change complaint priority with recorded justification
  Future<bool> changePriority({
    required String complaintId,
    required String priority,
    required String reason,
    required String actorId,
    required String actorName,
  }) async {
    try {
      _currentDetail = await _db.changePriority(
        complaintId: complaintId,
        priority: priority,
        reason: reason,
        actorId: actorId,
        actorName: actorName,
      );
      await fetchComplaints();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to change priority: $e';
      notifyListeners();
      return false;
    }
  }

  /// Request additional information from complainant
  Future<bool> requestAdditionalInformation({
    required String complaintId,
    required String requestMessage,
    required String actorId,
    required String actorName,
  }) async {
    try {
      _currentDetail = await _db.requestAdditionalInformation(
        complaintId: complaintId,
        requestMessage: requestMessage,
        actorId: actorId,
        actorName: actorName,
      );
      await fetchComplaints();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to request information: $e';
      notifyListeners();
      return false;
    }
  }

  /// Record investigative or corrective action taken
  Future<bool> recordActionTaken({
    required String complaintId,
    required String actionDetails,
    required String actorId,
    required String actorName,
  }) async {
    try {
      _currentDetail = await _db.recordActionTaken(
        complaintId: complaintId,
        actionDetails: actionDetails,
        actorId: actorId,
        actorName: actorName,
      );
      await fetchComplaints();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to record action: $e';
      notifyListeners();
      return false;
    }
  }

  /// Complainant provides response and evidence to an information request
  Future<bool> submitComplainantResponse({
    required String complaintId,
    required String responseText,
    required String complainantId,
    required String complainantName,
    List<PickedEvidence> evidenceFiles = const [],
  }) async {
    try {
      final List<Map<String, dynamic>> attachmentsData = [];
      for (var evidence in evidenceFiles) {
        final persistentPath = await EvidenceService.persistAttachment(evidence);
        attachmentsData.add({
          'file_path': persistentPath,
          'filename': evidence.fileName,
          'file_size': evidence.fileSize,
          'file_type': evidence.fileType,
          'content_type': evidence.mimeType,
        });
      }

      _currentDetail = await _db.submitComplainantResponse(
        complaintId: complaintId,
        responseText: responseText,
        complainantId: complainantId,
        complainantName: complainantName,
        attachments: attachmentsData,
      );
      await fetchComplaints();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit response: $e';
      notifyListeners();
      return false;
    }
  }

  /// Trigger synchronization with central FastAPI backend
  Future<SyncResult> triggerSync({String? token}) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final res = await _syncService.synchronize(userToken: token);
      _lastSyncMessage = res.message;
      await fetchComplaints();
      return res;
    } catch (e) {
      _lastSyncMessage = 'Sync error: $e';
      return SyncResult(
        isOnline: false,
        pushedCount: 0,
        pulledCount: 0,
        message: 'Sync error: $e',
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}

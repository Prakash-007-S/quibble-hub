import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';
import '../api/api_constants.dart';
import '../database/app_database.dart';

class SyncResult {
  final bool isOnline;
  final int pushedCount;
  final int pulledCount;
  final String message;

  const SyncResult({
    required this.isOnline,
    required this.pushedCount,
    required this.pulledCount,
    required this.message,
  });
}

class SyncService {
  final ApiClient _apiClient;
  final AppDatabase _db;
  bool _isSyncing = false;

  SyncService({
    ApiClient? apiClient,
    AppDatabase? db,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = db ?? AppDatabase.instance;

  bool get isSyncing => _isSyncing;

  /// Check whether the central backend server is reachable
  Future<bool> isBackendReachable() async {
    try {
      final baseUrl = await _apiClient.getBaseUrl();
      return await _apiClient.testConnection(baseUrl, timeoutMs: 1500);
    } catch (_) {
      return false;
    }
  }

  /// Perform bidirectional synchronization between local SQLite and FastAPI backend
  Future<SyncResult> synchronize({String? userToken}) async {
    if (_isSyncing) {
      return const SyncResult(
        isOnline: true,
        pushedCount: 0,
        pulledCount: 0,
        message: 'Sync already in progress.',
      );
    }

    _isSyncing = true;
    try {
      final baseUrl = await _apiClient.getBaseUrl();
      final isOnline = await _apiClient.testConnection(baseUrl, timeoutMs: 1500);

      if (!isOnline) {
        _isSyncing = false;
        return const SyncResult(
          isOnline: false,
          pushedCount: 0,
          pulledCount: 0,
          message: 'Central server unreachable. Running in offline on-device mode.',
        );
      }

      int pushed = 0;
      int pulled = 0;

      // 1. Push local unsynced complaints to server
      final unsyncedComplaints = await _db.getUnsyncedComplaints();
      for (final comp in unsyncedComplaints) {
        try {
          final uri = Uri.parse('$baseUrl${ApiConstants.complaints}');
          final headers = <String, String>{
            'Content-Type': 'application/json',
          };
          if (userToken != null && userToken.isNotEmpty) {
            headers['Authorization'] = 'Bearer $userToken';
          }

          final body = jsonEncode({
            'tracking_number': comp.trackingNumber,
            'title': comp.title,
            'description': comp.description,
            'category_id': comp.categoryId.isNotEmpty ? comp.categoryId : 'cat-academic',
            'priority': comp.priority,
            'location_context': comp.locationContext,
          });

          final response = await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 4));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final remoteId = data['id']?.toString() ?? comp.id;
            await _db.markComplaintSynced(comp.id, remoteId);
            pushed++;
          }
        } catch (e) {
          debugPrint('Failed to push complaint ${comp.id}: $e');
        }
      }

      // 2. Pull complaints from central server
      try {
        final uri = Uri.parse('$baseUrl${ApiConstants.complaints}');
        final headers = <String, String>{};
        if (userToken != null && userToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $userToken';
        }

        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List<dynamic> items = jsonDecode(response.body);
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final remoteId = item['id']?.toString() ?? '';
              final trackingNumber = item['tracking_number']?.toString() ?? '';
              final status = item['status']?.toString() ?? 'SUBMITTED';

              // Upsert into local database if not present or update status
              final updated = await _db.upsertRemoteComplaint(
                remoteId: remoteId,
                trackingNumber: trackingNumber,
                title: item['title']?.toString() ?? 'Grievance',
                description: item['description']?.toString() ?? '',
                categoryId: item['category_id']?.toString() ?? 'cat-academic',
                categoryName: item['category']?['name']?.toString() ?? 'General',
                departmentName: item['department']?['name']?.toString() ?? 'Administration',
                complainantName: item['complainant']?['full_name']?.toString() ?? 'Complainant',
                complainantId: item['complainant_id']?.toString() ?? 'remote-user',
                status: status,
                priority: item['priority']?.toString() ?? 'MEDIUM',
                assigneeName: item['assignee']?['full_name']?.toString(),
                createdAtIso: item['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                updatedAtIso: item['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
              );

              if (updated) {
                pulled++;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to pull complaints: $e');
      }

      _isSyncing = false;
      return SyncResult(
        isOnline: true,
        pushedCount: pushed,
        pulledCount: pulled,
        message: 'Synchronized with central server ($pushed pushed, $pulled updated).',
      );
    } catch (e) {
      _isSyncing = false;
      return SyncResult(
        isOnline: false,
        pushedCount: 0,
        pulledCount: 0,
        message: 'Sync error: $e',
      );
    }
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}

class ApiClient {
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyOrgId = 'active_org_id';
  static const String _keyBaseUrl = 'custom_base_url';

  final http.Client _client = http.Client();
  static String? _cachedDetectedUrl;
  static final Map<String, String> _memoryStorage = {};

  Future<bool> testConnection(String url, {int timeoutMs = 1500}) async {
    try {
      final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
      final healthUri = Uri.parse('$cleanUrl${ApiConstants.health}');
      final res = await _client.get(healthUri).timeout(Duration(milliseconds: timeoutMs));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<String> getBaseUrl() async {
    final customUrl = _memoryStorage[_keyBaseUrl];
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }

    if (_cachedDetectedUrl != null) {
      return _cachedDetectedUrl!;
    }

    // On web or desktop, 127.0.0.1 is standard
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _cachedDetectedUrl = ApiConstants.defaultBaseUrl;
      return _cachedDetectedUrl!;
    }

    // On Android, probe candidate URLs concurrently with a strict 800ms timeout
    try {
      final probes = ApiConstants.candidateBaseUrls.map((candidate) async {
        final isHealthy = await testConnection(candidate, timeoutMs: 700);
        return isHealthy ? candidate : null;
      });

      final results = await Future.wait(probes).timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => List.filled(ApiConstants.candidateBaseUrls.length, null),
      );

      for (final candidate in results) {
        if (candidate != null) {
          _cachedDetectedUrl = candidate;
          return candidate;
        }
      }
    } catch (_) {
      // Ignore background probing errors
    }

    // Default fallback
    _cachedDetectedUrl = ApiConstants.defaultBaseUrl;
    return _cachedDetectedUrl!;
  }

  Future<void> setCustomBaseUrl(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _memoryStorage[_keyBaseUrl] = cleanUrl;
    _cachedDetectedUrl = cleanUrl;
  }

  Future<void> resetCustomBaseUrl() async {
    _memoryStorage.remove(_keyBaseUrl);
    _cachedDetectedUrl = null;
  }

  Future<String?> getToken() async {
    return _memoryStorage[_keyToken];
  }

  Future<void> setToken(String token, String? refreshToken) async {
    _memoryStorage[_keyToken] = token;
    if (refreshToken != null) {
      _memoryStorage[_keyRefreshToken] = refreshToken;
    }
  }

  Future<String?> getActiveOrgId() async {
    return _memoryStorage[_keyOrgId];
  }

  Future<void> setActiveOrgId(String orgId) async {
    _memoryStorage[_keyOrgId] = orgId;
  }

  Future<void> clearAuth() async {
    _memoryStorage.remove(_keyToken);
    _memoryStorage.remove(_keyRefreshToken);
    _memoryStorage.remove(_keyOrgId);
  }

  Future<Map<String, String>> _buildHeaders({bool includeJson = true}) async {
    final headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }

    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final orgId = await getActiveOrgId();
    if (orgId != null && orgId.isNotEmpty) {
      headers['X-Organization-ID'] = orgId;
    }

    return headers;
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }

    String errorMsg = 'HTTP ${response.statusCode} error';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded.containsKey('detail')) {
        errorMsg = decoded['detail'].toString();
      }
    } catch (_) {
      errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
    }

    throw ApiException(statusCode: response.statusCode, message: errorMsg);
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final base = await getBaseUrl();
    var uri = Uri.parse('$base$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      final headers = await _buildHeaders();
      final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      return _processResponse(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to backend server at $base. Tap the server icon in the top right to check connection settings.',
      );
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base$endpoint');

    try {
      final headers = await _buildHeaders();
      final res = await _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 8));
      return _processResponse(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to backend server at $base. Tap the server icon in the top right to check connection settings.',
      );
    }
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base$endpoint');

    try {
      final headers = await _buildHeaders();
      final res = await _client.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 8));
      return _processResponse(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to backend server at $base. Tap the server icon in the top right to check connection settings.',
      );
    }
  }

  Future<dynamic> uploadFile(String endpoint, String fieldName, String filename, List<int> bytes) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base$endpoint');

    try {
      final headers = await _buildHeaders(includeJson: false);
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to backend server at $base. Tap the server icon in the top right to check connection settings.',
      );
    }
  }
}

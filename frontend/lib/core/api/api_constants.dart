class ApiConstants {
  // Configurable base URL with sensible defaults per runtime platform
  static String get defaultBaseUrl {
    // 127.0.0.1 is universal for Web, Desktop, and physical Android devices with adb reverse
    return 'http://127.0.0.1:8000/api/v1';
  }

  // Common Candidate URLs for quick selection on mobile devices
  static const List<String> candidateBaseUrls = [
    'http://127.0.0.1:8000/api/v1', // Physical phone via USB (adb reverse) / Web / Desktop
    'http://10.114.65.106:8000/api/v1', // Host PC Wi-Fi / LAN IP
    'http://10.0.2.2:8000/api/v1', // Standard Android Emulator
  ];

  // Endpoints
  static const String health = '/health';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String organizations = '/organizations';
  static const String departments = '/departments';
  static const String categories = '/categories';
  static const String complaints = '/complaints';
  static const String notifications = '/notifications';
  static const String analyticsDashboard = '/analytics/dashboard';
  
  static const String aiClassify = '/ai/classify';
  static const String aiDuplicateCheck = '/ai/duplicate-check';
}

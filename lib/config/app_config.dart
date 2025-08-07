class AppConfig {
  // API Configuration - pointing to mobile server
  static const String baseUrl =
      'http://10.0.2.2:5000'; // Android emulator localhost (port 5000 for mobile server)
  // static const String baseUrl = 'http://localhost:5000'; // iOS simulator
  // static const String baseUrl = 'https://your-production-domain.com'; // Production

  // API Endpoints
  static const String loginEndpoint = '$baseUrl/api/auth/login';
  static const String updateFCMEndpoint = '$baseUrl/api/auth/update-fcm-token';
  static const String profileEndpoint = '$baseUrl/api/auth/profile';
  static const String prescriptionsEndpoint = '$baseUrl/api/prescriptions';
  static const String syncEndpoint = '$baseUrl/api/prescriptions/sync';
  static const String healthEndpoint = '$baseUrl/api/health';

  // App Configuration
  static const String appName = 'MedAssist';
  static const String appVersion = '1.0.0';

  // Debug settings
  static const bool isDebug = true;
  static const bool enableLogging = true;
}

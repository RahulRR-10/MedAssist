class AppConfig {
  // API Configuration - pointing to your web app server
  static const String baseUrl =
      'http://10.0.2.2:5000/api'; // Android emulator localhost (port 5000 for your web app)
  // static const String baseUrl = 'http://localhost:5000/api'; // iOS simulator
  // static const String baseUrl = 'https://your-production-domain.com/api'; // Production

  // API Endpoints
  static const String loginEndpoint = '$baseUrl/auth/login';
  static const String updateFCMEndpoint = '$baseUrl/auth/update-fcm-token';
  static const String profileEndpoint = '$baseUrl/auth/profile';
  static const String patientsListEndpoint = '$baseUrl/auth/patients-list';

  // App Configuration
  static const String appName = 'MedAssist';
  static const String appVersion = '1.0.0';

  // Debug settings
  static const bool isDebug = true;
  static const bool enableLogging = true;
}

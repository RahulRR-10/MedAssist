import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // API Endpoints from config
  static const String _loginEndpoint = AppConfig.loginEndpoint;
  static const String _updateFCMEndpoint = AppConfig.updateFCMEndpoint;
  static const String _profileEndpoint = AppConfig.profileEndpoint;

  // Storage keys
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';
  static const String _isLoggedInKey = 'is_logged_in';

  User? _currentUser;
  String? _authToken;
  bool _isLoggedIn = false;

  // Getters
  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isLoggedIn => _isLoggedIn;

  // Initialize auth service - check if user is already logged in
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (_isLoggedIn) {
        final userJson = prefs.getString(_userKey);
        final token = prefs.getString(_tokenKey);

        if (userJson != null && token != null) {
          _currentUser = User.fromJson(jsonDecode(userJson));
          _authToken = token;
          AppLogger.info(
            'User restored from storage: ${_currentUser?.username}',
          );
        } else {
          // Clear invalid session
          await logout();
        }
      }
    } catch (e) {
      AppLogger.error('Failed to initialize auth service', e);
      await logout(); // Clear any corrupted data
    }
  }

  // Login with username and password
  Future<LoginResponse> login(String username, String password) async {
    try {
      AppLogger.info('Attempting login for username: $username');

      // Use real API call
      final response = await _apiLogin(username, password);

      if (response.success && response.user != null) {
        _currentUser = response.user;
        _authToken = response.token ?? 'error_no_token';
        _isLoggedIn = true;

        await _saveUserSession();
        AppLogger.info('Login successful for user: ${_currentUser?.username}');
      }

      return response;
    } catch (e) {
      AppLogger.error('Login failed', e);
      return LoginResponse(
        success: false,
        message: 'Login failed: ${e.toString()}',
      );
    }
  }

  // Real API login method
  Future<LoginResponse> _apiLogin(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(_loginEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(responseData);
      } else {
        return LoginResponse(
          success: false,
          message: responseData['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Save user session to local storage
  Future<void> _saveUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_currentUser != null) {
        await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      }

      if (_authToken != null) {
        await prefs.setString(_tokenKey, _authToken!);
      }

      await prefs.setBool(_isLoggedInKey, _isLoggedIn);

      AppLogger.info('User session saved');
    } catch (e) {
      AppLogger.error('Failed to save user session', e);
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear user data
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.setBool(_isLoggedInKey, false);

      // Clear in-memory data
      _currentUser = null;
      _authToken = null;
      _isLoggedIn = false;

      AppLogger.info('User logged out successfully');
    } catch (e) {
      AppLogger.error('Failed to logout user', e);
    }
  }

  // Update FCM token for the current user
  Future<void> updateFCMToken(String fcmToken) async {
    if (_currentUser == null || _authToken == null) {
      AppLogger.warning('Cannot update FCM token: user not logged in');
      return;
    }

    try {
      AppLogger.info('Updating FCM token for user: ${_currentUser?.username}');

      final response = await http
          .post(
            Uri.parse(_updateFCMEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken', // Use Bearer token format
            },
            body: jsonEncode({'fcmToken': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        AppLogger.info('FCM token updated successfully');
      } else {
        AppLogger.warning('Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Failed to update FCM token', e);
    }
  }

  // Check if the current session is valid
  Future<bool> isSessionValid() async {
    if (!_isLoggedIn || _currentUser == null || _authToken == null) {
      return false;
    }

    try {
      // Validate token with backend
      final response = await http
          .get(
            Uri.parse(_profileEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        AppLogger.warning('Session validation failed: ${response.statusCode}');
        await logout();
        return false;
      }
    } catch (e) {
      AppLogger.error('Session validation failed', e);
      await logout();
      return false;
    }
  }
}

// Extension to add toJson method to User class
extension UserJson on User {
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'address': address?.toJson(),
      'emergencyContact': emergencyContact?.toJson(),
      'medicalHistory': medicalHistory.map((item) => item.toJson()).toList(),
      'currentIllness': currentIllness,
      'lastVisit': lastVisit?.toIso8601String(),
      'notes': notes.map((item) => item.toJson()).toList(),
      'fcmToken': fcmToken,
      'username': username,
    };
  }
}

extension AddressJson on Address {
  Map<String, dynamic> toJson() {
    return {'street': street, 'city': city, 'state': state, 'zipCode': zipCode};
  }
}

extension EmergencyContactJson on EmergencyContact {
  Map<String, dynamic> toJson() {
    return {'name': name, 'phone': phone, 'relationship': relationship};
  }
}

extension MedicalHistoryJson on MedicalHistory {
  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'diagnosedDate': diagnosedDate?.toIso8601String(),
      'status': status,
    };
  }
}

extension NoteJson on Note {
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'date': date.toIso8601String(),
      'doctor': doctor,
    };
  }
}

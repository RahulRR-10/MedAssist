import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _authService.isLoggedIn;
  User? get currentUser => _authService.currentUser;
  String? get authToken => _authService.authToken;

  // Initialize the provider
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _authService.initialize();
      AppLogger.info('AuthProvider initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize AuthProvider', e);
      _setError('Failed to initialize authentication');
    } finally {
      _setLoading(false);
    }
  }

  // Login method
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.login(username.trim(), password);

      if (response.success) {
        AppLogger.info('Login successful for user: $username');
        notifyListeners();
        return true;
      } else {
        _setError(response.message);
        return false;
      }
    } catch (e) {
      AppLogger.error('Login error', e);
      _setError('Login failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout method
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
      AppLogger.info('User logged out');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Logout error', e);
      _setError('Failed to logout. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // Update FCM token
  Future<void> updateFCMToken(String fcmToken) async {
    try {
      await _authService.updateFCMToken(fcmToken);
    } catch (e) {
      AppLogger.error('Failed to update FCM token', e);
    }
  }

  // Check if session is valid
  Future<bool> validateSession() async {
    try {
      final isValid = await _authService.isSessionValid();
      if (!isValid) {
        notifyListeners();
      }
      return isValid;
    } catch (e) {
      AppLogger.error('Session validation error', e);
      return false;
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear any error messages
  void clearError() {
    _clearError();
  }
}

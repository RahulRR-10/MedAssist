import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../utils/logger.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();

      // Check if session is still valid
      if (authProvider.isLoggedIn) {
        final isValid = await authProvider.validateSession();
        if (!isValid) {
          AppLogger.info('Session expired, user needs to login again');
        }
      }
    } catch (e) {
      AppLogger.error('Error initializing authentication', e);
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Please wait...'),
                ],
              ),
            ),
          );
        }

        if (authProvider.isLoggedIn) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

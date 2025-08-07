import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../models/prescription_model.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/prescription_sync_service.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import 'prescription_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PrescriptionData> _prescriptions = [];
  bool _isLoading = true;
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final PrescriptionSyncService _syncService = PrescriptionSyncService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('HomeScreen: Starting app initialization...');

    try {
      print('HomeScreen: Initializing notification service...');
      // Initialize notification service with timeout
      await _notificationService.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.warning('Notification service initialization timed out');
          throw Exception('Notification service timeout');
        },
      );

      print('HomeScreen: Setting up FCM message handling...');
      // Set up FCM message handling
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for FCM token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('📱 FCM token refreshed: $newToken');
        _updateFCMTokenWithNewValue(newToken);
      });

      // Get and update FCM token after successful login
      await _updateFCMToken();

      // Sync prescriptions from server
      await _syncPrescriptionsFromServer();

      AppLogger.info('Notification service initialized successfully');
      print('HomeScreen: Notification service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize notification service', e);
      print('HomeScreen: Failed to initialize notification service: $e');
      // Continue without notification service
    }

    try {
      print('HomeScreen: Loading prescriptions...');
      // First remove any duplicates from previous syncs
      await _storageService.removeDuplicates();

      // Load saved prescriptions from local storage with timeout
      await _loadPrescriptions().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('Loading prescriptions timed out');
          throw Exception('Storage service timeout');
        },
      );
      print('HomeScreen: Prescriptions loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load prescriptions', e);
      print('HomeScreen: Failed to load prescriptions: $e');
      // Continue with empty prescription list
    }

    print('HomeScreen: Setting loading to false...');
    // Always set loading to false, even if services fail
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      print('HomeScreen: UI updated, loading complete');
    }
  }

  // Get and update FCM token on the server
  Future<void> _updateFCMToken() async {
    try {
      final fcmToken = await _notificationService.getFCMToken();
      if (fcmToken != null && mounted) {
        print('📱 Got FCM token: $fcmToken');

        // Update FCM token on the server via AuthProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.updateFCMToken(fcmToken);

        AppLogger.info('FCM token updated on server');
        print('📱 FCM token updated on server successfully');
      } else {
        AppLogger.warning('Failed to get FCM token');
        print('📱 Failed to get FCM token');
      }
    } catch (e) {
      AppLogger.error('Error updating FCM token', e);
      print('📱 Error updating FCM token: $e');
    }
  }

  // Update FCM token when it refreshes
  Future<void> _updateFCMTokenWithNewValue(String newToken) async {
    try {
      print('📱 Updating refreshed FCM token: $newToken');

      // Update FCM token on the server via AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateFCMToken(newToken);

      AppLogger.info('Refreshed FCM token updated on server');
      print('📱 Refreshed FCM token updated on server successfully');
    } catch (e) {
      AppLogger.error('Error updating refreshed FCM token', e);
      print('📱 Error updating refreshed FCM token: $e');
    }
  }

  // Sync prescriptions from server
  Future<void> _syncPrescriptionsFromServer() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.authToken;

      if (token == null) {
        AppLogger.warning('No auth token available for prescription sync');
        print('💊 No auth token available for prescription sync');
        return;
      }

      print('💊 Syncing prescriptions from server...');
      print('💊 Auth token: ${token.substring(0, 20)}...');

      // Get prescriptions from server
      final result = await _syncService.getPrescriptions(token);
      print('💊 Server response: $result');

      if (result['success']) {
        final serverPrescriptions = result['prescriptions'] as List? ?? [];
        print(
          '💊 Retrieved ${serverPrescriptions.length} prescriptions from server',
        );
        print('💊 Server prescriptions: $serverPrescriptions');

        if (serverPrescriptions.isNotEmpty) {
          // Get current user's username for patientId
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final currentUsername =
              authProvider.currentUser?.username ?? 'unknown_patient';
          print('💊 Current username: $currentUsername');

          // Convert server prescriptions to local format
          final convertedPrescriptions = _syncService
              .convertServerPrescriptions(
                serverPrescriptions,
                patientId: currentUsername,
              );
          print('💊 Converted prescriptions: $convertedPrescriptions');

          // Save prescriptions locally (will prevent duplicates)
          for (final prescriptionData in convertedPrescriptions) {
            try {
              print('💊 Converting prescription data: $prescriptionData');
              final prescription = PrescriptionData.fromJson(prescriptionData);
              await _storageService.savePrescription(prescription);
              print('💊 Saved prescription: ${prescription.diagnosis}');
            } catch (e) {
              AppLogger.error('Error saving prescription from server', e);
              print('💊 Error saving prescription from server: $e');
            }
          }

          // Remove any duplicates that might have been created
          await _storageService.removeDuplicates();

          // Reload local prescriptions
          print('💊 Reloading local prescriptions...');
          await _loadPrescriptions();
          print(
            '💊 Local prescriptions count after reload: ${_prescriptions.length}',
          );

          AppLogger.info('Prescriptions synced successfully from server');
          print('💊 Prescriptions synced successfully from server');
        } else {
          print('💊 No new prescriptions found on server');
        }
      } else {
        AppLogger.warning('Failed to sync prescriptions: ${result['error']}');
        print('💊 Failed to sync prescriptions: ${result['error']}');
      }
    } catch (e) {
      AppLogger.error('Error syncing prescriptions from server', e);
      print('💊 Error syncing prescriptions from server: $e');
    }
  }

  // Manual sync prescriptions (triggered by sync button)
  Future<void> _manualSync() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syncing prescriptions...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      // First remove any existing duplicates
      await _storageService.removeDuplicates();

      // Then sync from server
      await _syncPrescriptionsFromServer();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescriptions synced successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadPrescriptions() async {
    try {
      print('📋 Loading prescriptions from storage...');
      final prescriptions = await _storageService.getPrescriptions();
      print('📋 Loaded ${prescriptions.length} prescriptions from storage');
      setState(() {
        _prescriptions = prescriptions;
      });
      print('📋 UI updated with ${_prescriptions.length} prescriptions');
    } catch (e) {
      AppLogger.error('Error loading prescriptions', e);
      print('📋 Error loading prescriptions: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    if (message.data.containsKey('type') &&
        message.data['type'] == 'prescription') {
      try {
        // Parse prescription data from FCM message
        final prescriptionData = PrescriptionData.fromFCM(message.data);

        // Save prescription data locally
        await _storageService.savePrescription(prescriptionData);

        // Reload prescriptions
        await _loadPrescriptions();

        // Show a snackbar notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('New prescription received'),
              backgroundColor: Colors.blue,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PrescriptionDetailsScreen(
                            prescription: prescriptionData,
                          ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        AppLogger.error('Error processing prescription message', e);
      }
    }
  }

  void _showDeleteConfirmation(PrescriptionData prescription) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Delete Prescription',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete the prescription for "${prescription.diagnosis}"?\n\nThis action cannot be undone.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePrescription(prescription);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePrescription(PrescriptionData prescription) async {
    try {
      await _storageService.deletePrescription(prescription.id);
      await _loadPrescriptions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription "${prescription.diagnosis}" deleted'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting prescription: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'MedAssist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        shadowColor: Colors.transparent,
        actions: [
          // Sync prescriptions button
          IconButton(
            icon: Icon(Icons.sync, color: Colors.blue.shade700),
            onPressed: () => _manualSync(),
            tooltip: 'Sync Prescriptions',
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    _showLogoutDialog(context, authProvider);
                  } else if (value == 'profile') {
                    _showUserProfile(context, authProvider);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red[600]),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(color: Colors.red[600]),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.blue.withOpacity(0.1)),
        ),
      ),
      body: Container(
        color: Colors.grey[50],
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
                : _prescriptions.isEmpty
                ? _buildEmptyState()
                : _buildPrescriptionList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 64,
              color: Colors.blue[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Prescriptions Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your prescriptions will appear here when\nreceived from your doctor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[400], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You\'ll receive notifications for new prescriptions and medication reminders',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionList() {
    return RefreshIndicator(
      onRefresh: _loadPrescriptions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _prescriptions.length,
        itemBuilder: (context, index) {
          final prescription = _prescriptions[index];
          return _buildPrescriptionCard(prescription);
        },
      ),
    );
  }

  Widget _buildPrescriptionCard(PrescriptionData prescription) {
    final isRecent =
        DateTime.now().difference(prescription.createdAt).inHours < 24;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      PrescriptionDetailsScreen(prescription: prescription),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medical_information_outlined,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prescription.diagnosis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          if (isRecent)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSelected: (String result) {
                        if (result == 'delete') {
                          _showDeleteConfirmation(prescription);
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red[400],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red[400]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.sick_outlined,
                        'Symptom',
                        prescription.symptom,
                        Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.medication_outlined,
                        'Medications',
                        '${prescription.medications.length} prescribed',
                        Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.event_outlined,
                        'Follow-up',
                        '${prescription.followUpDate.day}/${prescription.followUpDate.month}/${prescription.followUpDate.year}',
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${prescription.createdAt.day}/${prescription.createdAt.month}/${prescription.createdAt.year}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap for details',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue[400]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.logout();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showUserProfile(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('User Profile'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileRow('Name', user.name),
                _buildProfileRow('Username', user.username),
                _buildProfileRow('Email', user.email),
                _buildProfileRow('Phone', user.phone),
                if (user.gender != null)
                  _buildProfileRow('Gender', user.gender!),
                if (user.currentIllness != null)
                  _buildProfileRow('Current Illness', user.currentIllness!),
                if (user.address != null)
                  _buildProfileRow(
                    'City',
                    user.address!.city ?? 'Not specified',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/prescription_model.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
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

      AppLogger.info('Notification service initialized successfully');
      print('HomeScreen: Notification service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize notification service', e);
      print('HomeScreen: Failed to initialize notification service: $e');
      // Continue without notification service
    }

    try {
      print('HomeScreen: Loading prescriptions...');
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

  Future<void> _loadPrescriptions() async {
    try {
      final prescriptions = await _storageService.getPrescriptions();
      setState(() {
        _prescriptions = prescriptions;
      });
    } catch (e) {
      AppLogger.error('Error loading prescriptions', e);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePrescription(prescription);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
      ),
      body: Container(
        color: Colors.grey[50],
        child: _isLoading
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
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[400],
                  size: 20,
                ),
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
    final isRecent = DateTime.now().difference(prescription.createdAt).inHours < 24;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionDetailsScreen(prescription: prescription),
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (String result) {
                        if (result == 'delete') {
                          _showDeleteConfirmation(prescription);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
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
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

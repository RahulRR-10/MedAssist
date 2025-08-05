import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'models/prescription_model.dart';
import 'utils/logger.dart';

// This function must be top-level to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background execution
  await Firebase.initializeApp();

  // Initialize timezone data for background execution
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  print('Background message received: ${message.messageId}');
  AppLogger.info('Background FCM message received: ${message.messageId}');

  if (message.data.containsKey('type') &&
      message.data['type'] == 'prescription') {
    try {
      // Parse prescription data from FCM message
      final prescriptionData = PrescriptionData.fromFCM(message.data);

      // Store prescription data locally
      await StorageService().savePrescription(prescriptionData);

      // Initialize notification service and schedule reminders
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.scheduleMedicationRemindersFromBackground(
        prescriptionData,
      );

      AppLogger.info('Background prescription processing completed');
      print('Background prescription processing completed');
    } catch (e) {
      AppLogger.error('Error processing background prescription message', e);
      print('Error processing background prescription message: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Starting app initialization...');

  try {
    print('Initializing Firebase...');
    // Add timeout for Firebase initialization
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print('Firebase initialization timed out');
        throw Exception('Firebase initialization failed');
      },
    );
    print('Firebase initialized successfully');

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('Background message handler set up');

    print('Initializing timezone data...');
    tz_data.initializeTimeZones();
    // Set location to India Standard Time (GMT+5:30)
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    print(
      'Timezone data initialized successfully - Local timezone: ${tz.local.name}',
    );
  } catch (e) {
    print('Error during app initialization: $e');
    // Continue with app launch even if Firebase fails
  }

  print('Starting Flutter app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedAssist',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

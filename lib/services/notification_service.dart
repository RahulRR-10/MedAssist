import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/prescription_model.dart';
import '../utils/logger.dart';
import 'storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Helper function to convert 24-hour time to 12-hour format
  String _formatTo12Hour(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      AppLogger.error('Failed to get FCM token', e);
      return null;
    }
  }

  // Public method for background processing of prescription messages
  Future<void> scheduleMedicationRemindersFromBackground(
    PrescriptionData prescription,
  ) async {
    try {
      await _scheduleMedicationReminders(prescription);
      AppLogger.info('Background medication reminders scheduled successfully');
    } catch (e) {
      AppLogger.error('Failed to schedule background medication reminders', e);
    }
  }

  Future<void> initialize() async {
    print('NotificationService: Starting initialization...');

    try {
      print('NotificationService: Requesting Firebase permissions...');
      // Request notification permissions with timeout
      await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              AppLogger.warning(
                'Firebase messaging permission request timed out',
              );
              return NotificationSettings(
                authorizationStatus: AuthorizationStatus.denied,
                alert: AppleNotificationSetting.disabled,
                announcement: AppleNotificationSetting.disabled,
                badge: AppleNotificationSetting.disabled,
                carPlay: AppleNotificationSetting.disabled,
                lockScreen: AppleNotificationSetting.disabled,
                notificationCenter: AppleNotificationSetting.disabled,
                showPreviews: AppleShowPreviewSetting.never,
                timeSensitive: AppleNotificationSetting.disabled,
                criticalAlert: AppleNotificationSetting.disabled,
                sound: AppleNotificationSetting.disabled,
                providesAppNotificationSettings:
                    AppleNotificationSetting.disabled,
              );
            },
          );
      print('NotificationService: Firebase permissions requested');

      // Get and print FCM token
      try {
        final token = await _firebaseMessaging.getToken();
        print('=================================');
        print('FCM TOKEN: $token');
        print('=================================');
        AppLogger.info('FCM Token: $token');
      } catch (e) {
        print('Failed to get FCM token: $e');
        AppLogger.error('Failed to get FCM token', e);
      }

      print('NotificationService: Initializing local notifications...');
      // Initialize local notifications with error handling
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications
          .initialize(
            initSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) {
              // Handle notification tap
              print(
                '🔔 NOTIFICATION RECEIVED! ID: ${response.id}, payload: ${response.payload}',
              );
              AppLogger.info('Notification received: ID ${response.id}');
              final payload = response.payload;
              if (payload != null) {
                // Navigate to prescription details page
                // This would be implemented based on your app's navigation structure
                print('📱 Notification payload: $payload');
              }
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              AppLogger.warning('Local notifications initialization timed out');
              throw Exception('Local notifications timeout');
            },
          );

      AppLogger.info('Local notifications initialized successfully');
      print(
        'NotificationService: Local notifications initialized successfully',
      );
    } catch (e) {
      AppLogger.error('Failed to initialize notifications', e);
      print('NotificationService: Failed to initialize notifications: $e');
      // Continue without local notifications
    }

    try {
      print('NotificationService: Setting up FCM message handling...');
      // Set up FCM message handling with error handling
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      // Background handler is set up in main.dart
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              AppLogger.warning('Getting initial FCM message timed out');
              return null;
            },
          );

      if (initialMessage != null) {
        _handleInitialMessage(initialMessage);
      }

      AppLogger.info('FCM message handling set up successfully');
      print('NotificationService: FCM message handling set up successfully');
    } catch (e) {
      AppLogger.error('Failed to set up FCM message handling', e);
      print('NotificationService: Failed to set up FCM message handling: $e');
      // Continue without FCM
    }

    print('NotificationService: Initialization completed');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 FCM Message received in foreground: ${message.data}');

    if (message.data.containsKey('type')) {
      final messageType = message.data['type'];

      if (messageType == 'prescription') {
        _processPrescriptionMessage(message);
      } else if (messageType == 'medication_reminder') {
        _processMedicationReminderMessage(message);
      }
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('🔔 FCM Message opened app: ${message.data}');

    if (message.data.containsKey('type')) {
      final messageType = message.data['type'];

      if (messageType == 'prescription') {
        // Navigate to prescription details
        // This would be implemented based on your app's navigation structure
      } else if (messageType == 'medication_reminder') {
        // Navigate to medication reminder details
        print('📱 Medication reminder tapped: ${message.data}');
      }
    }
  }

  void _handleInitialMessage(RemoteMessage message) {
    print('🔔 FCM Initial message: ${message.data}');

    if (message.data.containsKey('type')) {
      final messageType = message.data['type'];

      if (messageType == 'prescription') {
        // Navigate to prescription details
        // This would be implemented based on your app's navigation structure
      } else if (messageType == 'medication_reminder') {
        // Navigate to medication reminder details
        print('📱 App opened from medication reminder: ${message.data}');
      }
    }
  }

  Future<void> _processPrescriptionMessage(RemoteMessage message) async {
    try {
      // Parse prescription data from FCM message
      final prescriptionData = PrescriptionData.fromFCM(message.data);

      // Store prescription data locally using StorageService
      await StorageService().savePrescription(prescriptionData);

      // Instead of local scheduling (which fails), show immediate confirmation
      await _showPrescriptionReceivedNotification(prescriptionData);

      // Log that we received the prescription
      print(
        '✅ Prescription received and stored: ${prescriptionData.diagnosis}',
      );
      AppLogger.info(
        'Prescription processed successfully: ${prescriptionData.id}',
      );

      // Note: Medication reminders will be sent via FCM scheduler
      // The FCM scheduler should be running separately to handle timing
    } catch (e) {
      AppLogger.error('Error processing prescription message', e);
    }
  }

  Future<void> _showPrescriptionReceivedNotification(
    PrescriptionData prescription,
  ) async {
    try {
      await _localNotifications.show(
        999998, // Fixed ID for prescription confirmations
        '💊 New Prescription Received',
        'Prescription for ${prescription.diagnosis} has been saved. Reminders will be sent at scheduled times.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prescription_confirmations',
            'Prescription Confirmations',
            channelDescription: 'Confirmations when prescriptions are received',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: true,
            ongoing: false,
            category: AndroidNotificationCategory.message,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        payload: jsonEncode({
          'type': 'prescription_received',
          'prescriptionId': prescription.id,
        }),
      );

      print('✅ Prescription confirmation notification shown');
    } catch (e) {
      print('❌ Failed to show prescription confirmation: $e');
    }
  }

  Future<void> _processMedicationReminderMessage(RemoteMessage message) async {
    try {
      print('📋 Processing medication reminder: ${message.data}');

      // Extract reminder data
      final reminderId = message.data['reminderId'] ?? 'unknown';
      final title = message.notification?.title ?? 'Medication Reminder';
      final body = message.notification?.body ?? 'Time to take your medication';

      // Generate a safe notification ID (32-bit integer)
      final notificationId =
          reminderId.hashCode & 0x7FFFFFFF; // Ensure positive 32-bit int

      // Show local notification with sound
      await _localNotifications.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Reminders for medication times',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: true,
            ongoing: false,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        payload: jsonEncode(message.data),
      );

      print(
        '✅ Medication reminder notification shown locally with ID: $notificationId',
      );
      AppLogger.info('Medication reminder processed: $reminderId');
    } catch (e) {
      AppLogger.error('Error processing medication reminder message', e);
      print('❌ Failed to process medication reminder: $e');
    }
  }

  Future<void> _scheduleMedicationReminders(
    PrescriptionData prescription,
  ) async {
    AppLogger.info(
      'Starting to schedule medication reminders for prescription: ${prescription.id}',
    );
    int totalScheduled = 0;

    // For each medication in the prescription
    for (final medication in prescription.medications) {
      AppLogger.info('Processing medication: ${medication.name}');

      // For each schedule of the medication
      for (final schedule in medication.schedules) {
        AppLogger.info(
          'Processing schedule from ${schedule.startDate} to ${schedule.endDate}',
        );

        // Get the date range for the medication
        final startDate = schedule.startDate;
        final endDate = schedule.endDate;

        // For each time in the schedule
        for (final timeString in schedule.times) {
          AppLogger.info('Processing time: $timeString');

          try {
            // Parse the time string (e.g., "3:06 PM")
            final timeParts = timeString.split(':');
            int hour = int.parse(timeParts[0]);
            final minuteSecondParts = timeParts[1].split(' ');
            int minute = int.parse(minuteSecondParts[0]);
            final amPm = minuteSecondParts[1];

            // Convert to 24-hour format if needed
            if (amPm.toUpperCase() == 'PM' && hour < 12) {
              hour += 12;
            } else if (amPm.toUpperCase() == 'AM' && hour == 12) {
              hour = 0;
            }

            // Calculate the current date
            DateTime currentDate = DateTime.now();

            // Iterate through each day from start date to end date
            for (
              DateTime date = startDate;
              date.isBefore(endDate.add(const Duration(days: 1)));
              date = date.add(const Duration(days: 1))
            ) {
              // Skip dates in the past
              if (date.isBefore(currentDate) &&
                  (date.day != currentDate.day ||
                      date.month != currentDate.month ||
                      date.year != currentDate.year)) {
                continue;
              }

              // Create a DateTime for this specific reminder in local timezone
              final reminderDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                hour,
                minute,
              );

              // Skip times that have already passed today
              if (reminderDateTime.isBefore(currentDate)) {
                continue;
              }

              // Generate unique ID for this notification
              final notificationId =
                  '${medication.id}_${schedule.id}_${date.day}_${date.month}_${date.year}_$hour$minute'
                      .hashCode;

              // Format time for 12-hour display
              final timeDisplay = _formatTo12Hour(hour, minute);

              AppLogger.info(
                'Scheduling for local time: $reminderDateTime ($timeDisplay) (UTC offset: ${DateTime.now().timeZoneOffset})',
              );
              print('Local reminder time: $reminderDateTime ($timeDisplay)');

              // Schedule the notification
              await _scheduleNotification(
                id: notificationId,
                title: '💊 MedAssist Reminder',
                body:
                    'Time to take ${medication.name} (${schedule.dosage}) at $timeDisplay - ${medication.beforeAfterFood} food',
                scheduledDate: reminderDateTime,
                payload: jsonEncode({
                  'type': 'medication_reminder',
                  'medicationId': medication.id,
                  'medicationName': medication.name,
                  'dosage': schedule.dosage,
                  'scheduleId': schedule.id,
                  'prescriptionId': prescription.id,
                  'beforeAfterFood': medication.beforeAfterFood,
                }),
              );

              totalScheduled++;
              AppLogger.info(
                'Scheduled notification $notificationId for ${medication.name} at $timeDisplay ($reminderDateTime)',
              );
            }
          } catch (e) {
            AppLogger.error('Error parsing time string: $timeString', e);
          }
        }
      }
    }

    AppLogger.info('Total notifications scheduled: $totalScheduled');
    print('Scheduled $totalScheduled medication reminders');
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      // Use the same proven configuration as the working sound test
      const androidDetails = AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'Notifications for medication reminders',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        ongoing: false,
        category: AndroidNotificationCategory.reminder,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Ensure timezone is initialized for India Standard Time
      try {
        final _ = tz.local.name;
        if (tz.local.name != 'Asia/Kolkata') {
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
          AppLogger.info('Set timezone to Asia/Kolkata (GMT+5:30)');
        }
      } catch (e) {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        AppLogger.info('Initialized timezone to Asia/Kolkata (GMT+5:30)');
      }

      // Convert to timezone-aware datetime (India Standard Time)
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      AppLogger.info('Original DateTime: $scheduledDate');
      AppLogger.info(
        'TZDateTime for notification: $tzDateTime (timezone: ${tz.local.name})',
      );

      AppLogger.info('Scheduling notification $id for $tzDateTime');
      print('Scheduling notification $id: $title at $tzDateTime');

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      AppLogger.info('Successfully scheduled notification $id');
    } catch (e) {
      AppLogger.error('Failed to schedule notification $id', e);
      print('Failed to schedule notification $id: $e');

      // Fallback: try scheduling without timezone conversion
      try {
        const simpleAndroidDetails = AndroidNotificationDetails(
          'medication_reminders',
          'Medication Reminders',
          channelDescription: 'Notifications for medication reminders',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          autoCancel: true,
          ongoing: false,
          category: AndroidNotificationCategory.reminder,
        );

        const simpleIosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        );

        const simpleNotificationDetails = NotificationDetails(
          android: simpleAndroidDetails,
          iOS: simpleIosDetails,
        );

        // Use simple scheduling as fallback
        final duration = scheduledDate.difference(DateTime.now());
        if (duration.isNegative) return; // Don't schedule past times

        await _localNotifications.show(
          id,
          title,
          body,
          simpleNotificationDetails,
          payload: payload,
        );

        AppLogger.info('Fallback: Immediately showed notification $id');
        print('Fallback: Immediately showed notification $id');
      } catch (fallbackError) {
        AppLogger.error(
          'Fallback notification also failed for $id',
          fallbackError,
        );
        print('Fallback notification also failed for $id: $fallbackError');
      }
    }
  }

  // Method to test notification scheduling (for debugging)
  Future<void> scheduleTestNotification() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(
        const Duration(seconds: 30),
      ); // Changed to 30 seconds

      AppLogger.info('Original DateTime: $now');
      AppLogger.info(
        'TZDateTime for notification: $scheduledTime (timezone: ${tz.local.name})',
      );
      AppLogger.info('Scheduling notification 999999 for $scheduledTime');

      print(
        'Scheduling notification 999999: 🧪 MedAssist Test at $scheduledTime',
      );

      await _scheduleNotification(
        id: 999999,
        title: '🧪 MedAssist Test - 30s',
        body: 'This test notification was scheduled 30 seconds ago!',
        scheduledDate: scheduledTime.toLocal(),
        payload: jsonEncode({
          'type': 'test',
          'timestamp': scheduledTime.toIso8601String(),
        }),
      );

      AppLogger.info('Successfully scheduled notification 999999');

      final timeRemaining = scheduledTime.difference(now).inSeconds;
      print(
        'Test notification scheduled for ${scheduledTime.toIso8601String()} (in $timeRemaining seconds)',
      );
      AppLogger.info(
        'Test notification scheduled for ${scheduledTime.toIso8601String()}',
      );

      // Check pending notifications to verify it was scheduled
      final pendingNotifications =
          await _localNotifications.pendingNotificationRequests();
      final testNotification =
          pendingNotifications.where((n) => n.id == 999999).firstOrNull;
      if (testNotification != null) {
        print('✅ Test notification 999999 confirmed in pending list');
        AppLogger.info('Test notification 999999 confirmed in pending list');
      } else {
        print('❌ Test notification 999999 NOT found in pending list!');
        AppLogger.error('Test notification 999999 NOT found in pending list');
      }
    } catch (e) {
      AppLogger.error('Failed to schedule test notification', e);
      print('Failed to schedule test notification: $e');
    }
  }

  // Method to immediately show notification with sound (for testing)
  Future<void> showImmediateTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications with sound',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = DateTime.now();
    final currentTime = _formatTo12Hour(now.hour, now.minute);

    await _localNotifications.show(
      888888,
      '🔊 Sound Test',
      'This notification should play sound immediately! Current time: $currentTime',
      notificationDetails,
      payload: jsonEncode({
        'type': 'sound_test',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    print('Immediate sound test notification shown');
    AppLogger.info('Immediate sound test notification shown');
  }

  // Method to get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pendingNotifications =
          await _localNotifications.pendingNotificationRequests();
      AppLogger.info(
        'Found ${pendingNotifications.length} pending notifications',
      );
      return pendingNotifications;
    } catch (e) {
      AppLogger.error('Failed to get pending notifications', e);
      return [];
    }
  }

  // Method to cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      AppLogger.info('All notifications cancelled');
      print('All notifications cancelled');
    } catch (e) {
      AppLogger.error('Failed to cancel notifications', e);
    }
  }

  // Method to get detailed pending notifications info (for debugging)
  Future<void> showPendingNotificationsDebug() async {
    try {
      final pendingNotifications =
          await _localNotifications.pendingNotificationRequests();
      print('📋 PENDING NOTIFICATIONS DEBUG:');
      print('   Total pending: ${pendingNotifications.length}');

      for (final notification in pendingNotifications.take(10)) {
        // Show first 10
        print('   - ID: ${notification.id}');
        print('     Title: ${notification.title}');
        print('     Body: ${notification.body}');
        print('     Payload: ${notification.payload}');
        print('   ---');
      }

      if (pendingNotifications.length > 10) {
        print('   ... and ${pendingNotifications.length - 10} more');
      }

      AppLogger.info(
        'Pending notifications count: ${pendingNotifications.length}',
      );
    } catch (e) {
      AppLogger.error('Failed to get pending notifications debug', e);
      print('Failed to get pending notifications: $e');
    }
  }

  // Method to check exact alarm permission (Android 12+)
  Future<void> checkExactAlarmPermission() async {
    try {
      // For Android API 31+ (Android 12+), we need to check if we can schedule exact alarms
      print('🔍 Checking exact alarm permissions...');
      print(
        '💡 Note: On Android 12+, apps need special permission to schedule exact alarms',
      );
      print(
        '💡 If notifications aren\'t working, check Settings > Apps > MedAssist > Special app access > Alarms & reminders',
      );

      // Let's also try to schedule a test notification right now to see if basic scheduling works
      print('🧪 Testing immediate notification scheduling...');

      await showImmediateTestNotification();
      print('✅ Immediate notification test completed');

      AppLogger.info('Exact alarm permission check completed');
    } catch (e) {
      AppLogger.error('Failed to check exact alarm permission', e);
      print('Failed to check exact alarm permission: $e');
    }
  }

  // Method to test if ANY notification scheduling works at all
  Future<void> testBasicScheduling() async {
    try {
      print('� BASIC SCHEDULING TEST STARTING...');

      // Try scheduling for just 5 seconds from now
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(seconds: 5));

      print('⏰ Current time: $now');
      print('⏰ Scheduling for: $scheduledTime (5 seconds from now)');

      await _scheduleNotification(
        id: 777777,
        title: '⚡ 5-Second Test',
        body: 'If you see this, basic scheduling works!',
        scheduledDate: scheduledTime.toLocal(),
        payload: jsonEncode({
          'type': 'basic_test',
          'timestamp': scheduledTime.toIso8601String(),
        }),
      );

      print('✅ 5-second test notification scheduled');
      print('⏰ Wait 5 seconds to see if it appears...');

      AppLogger.info('Basic scheduling test completed - wait 5 seconds');
    } catch (e) {
      AppLogger.error('Basic scheduling test failed', e);
      print('❌ Basic scheduling test failed: $e');
    }
  }
}

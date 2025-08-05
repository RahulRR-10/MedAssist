const admin = require("firebase-admin");

// Try to use the service account file if it exists, otherwise skip admin features
let serviceAccount;
try {
  serviceAccount = require("./medassist-f675c-firebase-adminsdk-fbsvc-4a4975b192.json");
} catch (e) {
  console.log(
    "⚠️ Firebase Admin SDK file not found. Please download it from Firebase Console."
  );
  console.log("   1. Go to https://console.firebase.google.com/");
  console.log("   2. Select your project (medassist-f675c)");
  console.log("   3. Settings → Service accounts → Generate new private key");
  console.log(
    "   4. Save as: medassist-f675c-firebase-adminsdk-fbsvc-e3add6c3c3.json"
  );
  console.log("   5. Place it in this directory");
  process.exit(1);
}

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// FCM token - replace with actual token from your app
const FCM_TOKEN =
  "ftRZSedhQve3-4L8KDgXwt:APA91bFYP7AyzbqNr1My5C_7SA0tZg3pcq1s8iR3YVCPNvCRuSOIJ6hBuZUg2V2TyKv45Zz3t4l5cm15kGjRFLHDoNEZHVWDSIx_qAfJQWFs6TEHQpftsCA";

class FCMReminderScheduler {
  constructor() {
    this.scheduledReminders = new Map();
  }

  // Schedule a reminder to be sent at a specific time
  scheduleReminder(id, title, body, scheduledTime, medicationData = null) {
    const now = new Date();
    const delay = scheduledTime.getTime() - now.getTime();

    if (delay <= 0) {
      console.log(`⚠️ Reminder ${id} is scheduled in the past, skipping...`);
      return false;
    }

    console.log(
      `📅 Scheduling reminder ${id} for ${scheduledTime.toLocaleString()}`
    );
    console.log(`⏰ Will fire in ${Math.round(delay / 1000)} seconds`);

    const timeoutId = setTimeout(async () => {
      await this.sendReminder(id, title, body, medicationData);
      this.scheduledReminders.delete(id);
    }, delay);

    this.scheduledReminders.set(id, {
      timeoutId,
      scheduledTime,
      title,
      body,
      medicationData,
    });

    return true;
  }

  // Send an immediate FCM notification
  async sendReminder(id, title, body, medicationData = null) {
    try {
      console.log(`🔔 Sending reminder ${id}: ${title}`);

      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: "medication_reminder",
          reminderId: id.toString(),
          timestamp: new Date().toISOString(),
          ...(medicationData && {
            medicationData: JSON.stringify(medicationData),
          }),
        },
        android: {
          priority: "high",
          notification: {
            channel_id: "medication_reminders",
            sound: "default",
            priority: "high",
            visibility: "public",
            icon: "ic_medication",
            color: "#2196F3",
            tag: `medication_${id}`,
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
              badge: 1,
            },
          },
        },
        token: FCM_TOKEN,
      };

      const response = await admin.messaging().send(message);
      console.log(`✅ Reminder ${id} sent successfully! Response: ${response}`);
      return true;
    } catch (error) {
      console.error(`❌ Failed to send reminder ${id}:`, error.message);
      return false;
    }
  }

  // Cancel a scheduled reminder
  cancelReminder(id) {
    const reminder = this.scheduledReminders.get(id);
    if (reminder) {
      clearTimeout(reminder.timeoutId);
      this.scheduledReminders.delete(id);
      console.log(`🚫 Cancelled reminder ${id}`);
      return true;
    }
    return false;
  }

  // Send a prescription notification (different from medication reminder)
  async sendPrescriptionNotification(title, body, prescriptionData) {
    try {
      console.log(`📋 Sending prescription notification: ${title}`);

      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: "prescription",
          timestamp: new Date().toISOString(),
          prescriptionData: JSON.stringify(prescriptionData),
          prescriptionId: prescriptionData._id,
          patientId: prescriptionData.patientId,
          diagnosis: prescriptionData.diagnosis,
          medicationCount: prescriptionData.medications.length.toString(),
        },
        android: {
          priority: "high",
          notification: {
            channel_id: "prescription_confirmations",
            sound: "default",
            priority: "high",
            visibility: "public",
            icon: "ic_prescription",
            color: "#4CAF50",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
              badge: 1,
            },
          },
        },
        token: FCM_TOKEN,
      };

      const response = await admin.messaging().send(message);
      console.log(
        `✅ Prescription notification sent successfully! Response: ${response}`
      );
      return true;
    } catch (error) {
      console.error(
        `❌ Failed to send prescription notification:`,
        error.message
      );
      return false;
    }
  }

  // Get all scheduled reminders
  getScheduledReminders() {
    const reminders = [];
    for (const [id, reminder] of this.scheduledReminders) {
      reminders.push({
        id,
        title: reminder.title,
        scheduledTime: reminder.scheduledTime,
        timeUntilFire: reminder.scheduledTime.getTime() - new Date().getTime(),
      });
    }
    return reminders;
  }

  // Schedule medication reminders from prescription data
  scheduleMedicationReminders(prescriptionData) {
    let totalScheduled = 0;

    prescriptionData.medications.forEach((medication) => {
      medication.schedules.forEach((schedule) => {
        const startDate = new Date(schedule.startDate);
        const endDate = new Date(schedule.endDate);

        // Schedule for today and tomorrow (you can extend this)
        for (
          let date = new Date(startDate);
          date <= endDate;
          date.setDate(date.getDate() + 1)
        ) {
          schedule.times.forEach((timeString) => {
            const reminderTime = this.parseTimeString(
              timeString,
              new Date(date)
            );
            const reminderId = `${medication._id}_${
              schedule._id
            }_${reminderTime.getTime()}`;

            const success = this.scheduleReminder(
              reminderId,
              `💊 ${medication.name}`,
              `Time to take ${schedule.dosage} - ${medication.beforeAfterFood} food`,
              reminderTime,
              {
                medicationName: medication.name,
                dosage: schedule.dosage,
                beforeAfterFood: medication.beforeAfterFood,
                time: timeString,
              }
            );

            if (success) {
              totalScheduled++;
            }
          });
        }
      });
    });

    console.log(`📋 Scheduled ${totalScheduled} medication reminders via FCM`);
    return totalScheduled;
  }

  // Parse time string (e.g., "11:30 PM") into a Date object for today
  parseTimeString(timeString, baseDate = new Date()) {
    const [time, ampm] = timeString.split(" ");
    const [hours, minutes] = time.split(":");

    let hour24 = parseInt(hours);
    if (ampm === "PM" && hour24 !== 12) hour24 += 12;
    if (ampm === "AM" && hour24 === 12) hour24 = 0;

    const result = new Date(baseDate);
    result.setHours(hour24, parseInt(minutes), 0, 0);

    return result;
  }
}

// Export for use in other scripts
module.exports = FCMReminderScheduler;

// If running directly, start a demo
if (require.main === module) {
  const scheduler = new FCMReminderScheduler();

  console.log("🚀 FCM Reminder Scheduler Demo");
  console.log("📱 Target FCM Token:", FCM_TOKEN);

  // Schedule a test reminder for 10 seconds from now
  const testTime = new Date(Date.now() + 10000);
  scheduler.scheduleReminder(
    "test_001",
    "🧪 FCM Test Reminder",
    "This reminder was sent via FCM (not local scheduling)!",
    testTime
  );

  console.log("⏰ Test reminder scheduled for 10 seconds from now...");
  console.log("📱 Keep your Flutter app running to receive it!");

  // Keep the process alive
  setInterval(() => {
    const pending = scheduler.getScheduledReminders();
    if (pending.length === 0) {
      console.log("✅ All reminders sent. Exiting...");
      process.exit(0);
    }
  }, 1000);
}

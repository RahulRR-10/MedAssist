const admin = require("firebase-admin");
const mongoose = require("mongoose");

// Firebase service account configuration
const serviceAccount = require("./medassist-f675c-firebase-adminsdk-fbsvc-4a4975b192.json");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// Patient Schema for getting FCM tokens
const PatientSchema = new mongoose.Schema({
  firstName: String,
  lastName: String,
  username: String,
  password: String,
  fcmToken: String,
  // ... other fields
});

const Patient = mongoose.model("Patient", PatientSchema);

class MedAssistNotificationService {
  constructor() {
    this.scheduledReminders = new Map();
  }

  // Get FCM token for a patient from MongoDB
  async getFCMToken(patientId) {
    try {
      const patient = await Patient.findById(patientId);
      if (patient && patient.fcmToken) {
        console.log(
          `📱 Found FCM token for patient ${patientId}: ${patient.fcmToken.substring(
            0,
            20
          )}...`
        );
        return patient.fcmToken;
      } else {
        console.log(`⚠️ No FCM token found for patient ${patientId}`);
        return null;
      }
    } catch (error) {
      console.error(
        `❌ Error getting FCM token for patient ${patientId}:`,
        error.message
      );
      return null;
    }
  }

  // Send prescription received notification (immediate)
  async sendPrescriptionNotification(prescriptionData) {
    try {
      console.log(
        `📋 Sending prescription notification for: ${prescriptionData.diagnosis}`
      );

      // Get FCM token for this patient
      const fcmToken = await this.getFCMToken(prescriptionData.patientId);
      if (!fcmToken) {
        console.log(
          `⚠️ Cannot send notification - no FCM token for patient ${prescriptionData.patientId}`
        );
        return false;
      }

      const message = {
        notification: {
          title: "📋 New Prescription Received!",
          body: `Dr. prescribed ${prescriptionData.medications[0].name} for ${prescriptionData.diagnosis}`,
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
              alert: {
                title: "📋 New Prescription Received!",
                body: `Dr. prescribed ${prescriptionData.medications[0].name} for ${prescriptionData.diagnosis}`,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
        token: fcmToken,
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

  // Schedule a medication reminder for a specific time
  scheduleReminder(id, title, body, scheduledTime, medicationData = null) {
    const now = new Date();
    const delay = scheduledTime.getTime() - now.getTime();

    if (delay <= 0) {
      console.log(`⏰ Reminder ${id} is in the past, skipping`);
      return false;
    }

    console.log(
      `⏰ Scheduling reminder ${id} for ${scheduledTime.toLocaleString()}`
    );
    console.log(`⏰ Will fire in ${Math.round(delay / 1000)} seconds`);

    const timeoutId = setTimeout(async () => {
      await this.sendMedicationReminder(id, title, body, medicationData);
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

  // Send a medication reminder notification
  async sendMedicationReminder(id, title, body, medicationData = null) {
    try {
      console.log(`🔔 Sending medication reminder ${id}: ${title}`);

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
        token: this.fcmToken,
      };

      const response = await admin.messaging().send(message);
      console.log(
        `✅ Medication reminder ${id} sent successfully! Response: ${response}`
      );
      return true;
    } catch (error) {
      console.error(
        `❌ Failed to send medication reminder ${id}:`,
        error.message
      );
      return false;
    }
  }

  // Process a complete prescription from your web app
  async processPrescription(prescriptionData) {
    console.log("🚀 Processing complete prescription workflow...");
    console.log(`📋 Patient: ${prescriptionData.patientId}`);
    console.log(`📋 Diagnosis: ${prescriptionData.diagnosis}`);
    console.log(`📋 Medications: ${prescriptionData.medications.length}`);

    try {
      // Make each prescription unique by adding timestamp to ID
      const uniquePrescription = {
        ...prescriptionData,
        _id: `${prescriptionData._id}_${Date.now()}`, // Make ID unique with timestamp
        createdAt: new Date().toISOString(), // Update creation time
        updatedAt: new Date().toISOString(), // Update modification time
      };

      console.log(`📋 Unique Prescription ID: ${uniquePrescription._id}`);

      // Step 1: Send immediate prescription received notification
      console.log("\n📬 Step 1: Sending prescription received notification...");
      const prescriptionSent = await this.sendPrescriptionNotification(
        uniquePrescription
      );

      if (!prescriptionSent) {
        console.log("❌ Failed to send prescription notification");
        return { success: false, scheduled: 0 };
      }

      console.log("✅ Prescription notification sent!");

      // Step 2: Schedule all medication reminders using unique prescription
      console.log("\n⏰ Step 2: Scheduling medication reminders...");
      let totalScheduled = 0;

      uniquePrescription.medications.forEach((medication, medIndex) => {
        console.log(
          `\n💊 Processing medication ${medIndex + 1}: ${medication.name}`
        );

        medication.schedules.forEach((schedule, schedIndex) => {
          console.log(`   📅 Schedule ${schedIndex + 1}: ${schedule.dosage}`);

          const startDate = new Date(schedule.startDate);
          const endDate = new Date(schedule.endDate);

          // Schedule for each day in the range
          for (
            let date = new Date(startDate);
            date <= endDate;
            date.setDate(date.getDate() + 1)
          ) {
            schedule.times.forEach((timeString, timeIndex) => {
              const reminderTime = this.parseTimeString(
                timeString,
                new Date(date)
              );

              // Skip times that have already passed
              if (reminderTime <= new Date()) {
                console.log(
                  `     ⏰ ${timeString} on ${date.toDateString()} - SKIPPED (past time)`
                );
                return;
              }

              const reminderId = `${medication._id}_${
                schedule._id
              }_${reminderTime.getTime()}_${Date.now()}`;

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
                  prescriptionId: uniquePrescription._id, // Use unique prescription ID
                  diagnosis: uniquePrescription.diagnosis,
                }
              );

              if (success) {
                totalScheduled++;
                console.log(
                  `     ⏰ ${timeString} on ${date.toDateString()} - SCHEDULED`
                );
              }
            });
          }
        });
      });

      console.log(`\n✅ Prescription workflow completed successfully!`);
      console.log(`   📬 Prescription notification: SENT`);
      console.log(`   ⏰ Medication reminders scheduled: ${totalScheduled}`);
      console.log(`   🆔 Unique Prescription ID: ${uniquePrescription._id}`);

      return {
        success: true,
        scheduled: totalScheduled,
        prescriptionId: uniquePrescription._id,
      };
    } catch (error) {
      console.error("❌ Error processing prescription:", error);
      return { success: false, scheduled: 0, error: error.message };
    }
  }

  // Parse time string (e.g., "11:30 PM") into a Date object for a specific date
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

  // Get status of all scheduled reminders
  getScheduledReminders() {
    return Array.from(this.scheduledReminders.entries()).map(
      ([id, reminder]) => ({
        id,
        scheduledTime: reminder.scheduledTime,
        title: reminder.title,
        body: reminder.body,
      })
    );
  }

  // Cancel all reminders for a prescription
  cancelPrescriptionReminders(prescriptionId) {
    const reminders = Array.from(this.scheduledReminders.keys());
    let cancelled = 0;

    reminders.forEach((id) => {
      if (id.includes(prescriptionId)) {
        const reminder = this.scheduledReminders.get(id);
        if (reminder) {
          clearTimeout(reminder.timeoutId);
          this.scheduledReminders.delete(id);
          cancelled++;
        }
      }
    });

    console.log(
      `🚫 Cancelled ${cancelled} reminders for prescription ${prescriptionId}`
    );
    return cancelled;
  }

  // Update FCM token when app cache is cleared
  updateFCMToken(newToken) {
    this.fcmToken = newToken;
    console.log("📱 FCM token updated:", newToken);
  }

  // Test FCM connectivity
  async testConnection() {
    try {
      const message = {
        notification: {
          title: "🧪 Connection Test",
          body: "MedAssist notification service is working!",
        },
        data: {
          type: "test",
          timestamp: new Date().toISOString(),
        },
        token: this.fcmToken,
      };

      const response = await admin.messaging().send(message);
      console.log("✅ Connection test successful! Response:", response);
      return true;
    } catch (error) {
      console.error("❌ Connection test failed:", error.message);
      return false;
    }
  }
}

// Export for use in your web app
module.exports = MedAssistNotificationService;

// Example usage (remove this section when integrating into your web app)
if (require.main === module) {
  console.log("🚀 MedAssist Notification Service - Example Usage");

  // Example prescription data
  const examplePrescription = {
    patientId: "688133fd94b4c63ce43c5fd7",
    diagnosis: "Test Prescription22",
    symptom: "headache",
    medications: [
      {
        name: "Sample Medicine",
        beforeAfterFood: "Before",
        schedules: [
          {
            startDate: new Date().toISOString(),
            endDate: new Date(
              Date.now() + 2 * 24 * 60 * 60 * 1000
            ).toISOString(),
            dosage: "250mg",
            times: [
              new Date(Date.now() + 2 * 60 * 1000).toLocaleTimeString("en-US", {
                hour: "numeric",
                minute: "2-digit",
                hour12: true,
              }),
            ],
            _id: "sample_schedule_id",
          },
        ],
        _id: "sample_medication_id",
      },
    ],
    followUpDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    notes: "",
    _id: "sample_prescription_id",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    __v: 0,
  };

  // Initialize service
  const notificationService = new MedAssistNotificationService();

  // Process the prescription
  notificationService
    .processPrescription(examplePrescription)
    .then((result) => {
      if (result.success) {
        console.log(
          `\n🎉 Example completed! ${result.scheduled} reminders scheduled.`
        );

        // Keep process alive to send scheduled reminders
        setInterval(() => {
          const pending = notificationService.getScheduledReminders();
          if (pending.length === 0) {
            console.log("✅ All reminders sent. Example completed!");
            process.exit(0);
          } else {
            console.log(`⏳ ${pending.length} reminders pending...`);
          }
        }, 30000);
      } else {
        console.log("❌ Example failed:", result.error);
        process.exit(1);
      }
    });
}

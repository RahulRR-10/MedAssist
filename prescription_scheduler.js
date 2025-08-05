const FCMReminderScheduler = require("./fcm_reminder_scheduler");

// FCM token from your Flutter app
const FCM_TOKEN =
  "ftRZSedhQve3-4L8KDgXwt:APA91bFYP7AyzbqNr1My5C_7SA0tZg3pcq1s8iR3YVCPNvCRuSOIJ6hBuZUg2V2TyKv45Zz3t4l5cm15kGjRFLHDoNEZHVWDSIx_qAfJQWFs6TEHQpftsCA";

class PrescriptionScheduler {
  constructor() {
    this.scheduler = new FCMReminderScheduler();
    // Override the FCM token in the scheduler
    this.scheduler.FCM_TOKEN = FCM_TOKEN;
  }

  // Process a prescription from your web app and schedule all reminders
  schedulePrescriptionReminders(prescriptionData) {
    console.log("📋 Processing prescription from web app...");
    console.log(`   Diagnosis: ${prescriptionData.diagnosis}`);
    console.log(`   Medications: ${prescriptionData.medications.length}`);

    let totalScheduled = 0;

    prescriptionData.medications.forEach((medication, medIndex) => {
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
            }_${reminderTime.getTime()}`;

            const success = this.scheduler.scheduleReminder(
              reminderId,
              `💊 ${medication.name}`,
              `Time to take ${schedule.dosage} - ${medication.beforeAfterFood} food`,
              reminderTime,
              {
                medicationName: medication.name,
                dosage: schedule.dosage,
                beforeAfterFood: medication.beforeAfterFood,
                time: timeString,
                prescriptionId: prescriptionData._id,
                diagnosis: prescriptionData.diagnosis,
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

    console.log(
      `\n✅ Successfully scheduled ${totalScheduled} medication reminders via FCM`
    );
    return totalScheduled;
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
    return this.scheduler.getScheduledReminders();
  }

  // Cancel all reminders for a prescription
  cancelPrescriptionReminders(prescriptionId) {
    const reminders = this.scheduler.getScheduledReminders();
    let cancelled = 0;

    reminders.forEach((reminder) => {
      if (reminder.id.includes(prescriptionId)) {
        this.scheduler.cancelReminder(reminder.id);
        cancelled++;
      }
    });

    console.log(
      `🚫 Cancelled ${cancelled} reminders for prescription ${prescriptionId}`
    );
    return cancelled;
  }
}

// Export for use in other scripts
module.exports = PrescriptionScheduler;

// If running directly, demonstrate with sample prescription
if (require.main === module) {
  const prescriptionScheduler = new PrescriptionScheduler();

  // Sample prescription data (like what your web app sends)
  const samplePrescription = {
    _id: "sample_prescription_" + Date.now(),
    patientId: "patient123",
    diagnosis: "Sample Medication Test",
    symptom: "Testing FCM scheduling",
    medications: [
      {
        _id: "med_" + Date.now(),
        name: "Sample Medicine",
        beforeAfterFood: "Before",
        schedules: [
          {
            _id: "schedule_" + Date.now(),
            startDate: new Date().toISOString(),
            endDate: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // Tomorrow
            dosage: "1 tablet",
            times: [
              // Schedule for 2 minutes and 4 minutes from now for testing
              new Date(Date.now() + 2 * 60 * 1000).toLocaleTimeString("en-US", {
                hour: "numeric",
                minute: "2-digit",
                hour12: true,
              }),
              new Date(Date.now() + 4 * 60 * 1000).toLocaleTimeString("en-US", {
                hour: "numeric",
                minute: "2-digit",
                hour12: true,
              }),
            ],
          },
        ],
      },
    ],
    followUpDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    notes: "Sample prescription for FCM testing",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  console.log("🚀 Testing Prescription Scheduler");
  console.log("📱 Target FCM Token:", FCM_TOKEN);

  const scheduled =
    prescriptionScheduler.schedulePrescriptionReminders(samplePrescription);

  if (scheduled > 0) {
    console.log(
      "\n⏰ Scheduled reminders will fire in the next few minutes..."
    );
    console.log("📱 Keep your Flutter app running to receive them!");

    // Keep the process alive to send the scheduled reminders
    console.log("\n🔄 Scheduler is running... Press Ctrl+C to stop");

    // Show status every 30 seconds
    setInterval(() => {
      const pending = prescriptionScheduler.getScheduledReminders();
      if (pending.length === 0) {
        console.log("✅ All reminders sent. Exiting...");
        process.exit(0);
      } else {
        console.log(`⏳ ${pending.length} reminders pending...`);
      }
    }, 30000);
  } else {
    console.log(
      "❌ No reminders were scheduled (all times may be in the past)"
    );
    process.exit(1);
  }
}

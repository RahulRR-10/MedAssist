const PrescriptionScheduler = require("./prescription_scheduler");
const FCMReminderScheduler = require("./fcm_reminder_scheduler");

// This is the exact prescription data format your web app will send
const prescriptionData = {
  patientId: "688133fd94b4c63ce43c5fd7",
  diagnosis: "Boooooodyache",
  symptom: "headache",
  medications: [
    {
      name: "Calpol",
      beforeAfterFood: "Before",
      schedules: [
        {
          startDate: "2025-08-05T00:00:00.000Z", // Today's date
          endDate: "2025-08-07T00:00:00.000Z", // Next 2 days
          dosage: "250mg",
          times: ["11:21 AM", "11:35 AM"],
          _id: "68827347482b8b0f79683e85",
        },
      ],
      _id: "68827347482b8b0f79683e84",
    },
  ],
  followUpDate: "2025-07-30T00:00:00.000Z",
  notes: "",
  _id: "68827347482b8b0f79683e83",
  createdAt: "2025-07-24T17:54:15.111Z",
  updatedAt: "2025-07-24T17:54:15.111Z",
  __v: 0,
};

async function testPrescriptionWorkflow() {
  console.log("🚀 Testing Complete Prescription Workflow");
  console.log("📋 Processing prescription from web app...");

  // Step 1: Send prescription received notification (immediate)
  console.log(
    "\n📬 Step 1: Sending 'New Prescription Received' notification..."
  );
  const fcmScheduler = new FCMReminderScheduler();

  const prescriptionReceived = await fcmScheduler.sendPrescriptionNotification(
    "📋 New Prescription Received!",
    `Dr. prescribed ${prescriptionData.medications[0].name} for ${prescriptionData.diagnosis}`,
    prescriptionData
  );

  if (prescriptionReceived) {
    console.log("✅ Prescription received notification sent!");
    console.log(
      "📱 Check your app - prescription should appear on home screen"
    );
  } else {
    console.log("❌ Failed to send prescription received notification");
  }

  // Step 2: Schedule medication reminders for specified times
  console.log("\n⏰ Step 2: Scheduling medication reminders...");
  const prescriptionScheduler = new PrescriptionScheduler();
  const scheduled =
    prescriptionScheduler.schedulePrescriptionReminders(prescriptionData);

  if (scheduled > 0) {
    console.log(`\n✅ Complete workflow successful!`);
    console.log(`   📬 Prescription notification sent immediately`);
    console.log(`   ⏰ ${scheduled} medication reminders scheduled`);
    console.log("📱 Your Flutter app should now show:");
    console.log("   - New prescription on home screen");
    console.log("   - Medication reminders at scheduled times");
    console.log("\n🔄 Scheduler running... Press Ctrl+C to stop\n");

    // Show status every 30 seconds
    setInterval(() => {
      const pending = prescriptionScheduler.getScheduledReminders();
      if (pending.length === 0) {
        console.log("✅ All reminders sent successfully!");
        process.exit(0);
      } else {
        console.log(`⏳ ${pending.length} reminders pending...`);
      }
    }, 30000);
  } else {
    console.log("❌ No reminders scheduled (times may be in the past)");
  }
}

// Run the complete workflow
testPrescriptionWorkflow().catch(console.error);

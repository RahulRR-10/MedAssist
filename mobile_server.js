const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const admin = require("firebase-admin");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 5001;

// Middleware
app.use(cors());
app.use(express.json());

// Firebase service account configuration
const serviceAccount = require("./medassist-f675c-firebase-adminsdk-fbsvc-4a4975b192.json");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// MongoDB Schema
const medicationSchema = new mongoose.Schema({
  name: { type: String, required: true },
  beforeAfterFood: { type: String, enum: ["Before", "After"], required: true },
  schedules: [
    {
      startDate: { type: Date, required: true },
      endDate: { type: Date, required: true },
      dosage: { type: String, required: true },
      times: [{ type: String, required: true }],
    },
  ],
});

// Patient schema for authentication (test.patients collection)
const patientSchema = new mongoose.Schema(
  {
    username: { type: String, unique: true, required: true },
    password: { type: String, required: true },
    fcmToken: { type: String }, // FCM token stored in patients collection
    // Add other patient fields as needed
    name: { type: String },
    email: { type: String },
    phone: { type: String },
  },
  {
    timestamps: true,
  }
);

const prescriptionMobileSchema = new mongoose.Schema(
  {
    username: { type: String, unique: true, required: true },
    password: { type: String, required: true },
    prescriptions: [medicationSchema],
    fcmToken: { type: String },
    lastProcessed: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  }
);

const Patient = mongoose.model("Patient", patientSchema);
const PrescriptionMobile = mongoose.model(
  "PrescriptionMobile",
  prescriptionMobileSchema
);

// Notification Service Class
class MobileNotificationService {
  constructor() {
    this.scheduledReminders = new Map();
    this.monitoringUsers = new Set();
    this.pollInterval = null;
  }

  // Start monitoring prescriptions for a specific user
  async startMonitoringUser(username, fcmToken) {
    try {
      // Update user's FCM token in Patient collection
      await Patient.findOneAndUpdate(
        { username },
        { fcmToken },
        { upsert: false }
      );

      // Also update in PrescriptionMobile collection for backward compatibility
      await PrescriptionMobile.findOneAndUpdate(
        { username },
        {
          fcmToken,
          lastProcessed: new Date(),
        },
        { upsert: false }
      );

      this.monitoringUsers.add(username);
      console.log(`👤 Started monitoring prescriptions for user: ${username}`);

      // Start polling if not already running
      if (!this.pollInterval) {
        this.startPolling();
      }

      // Process any existing unprocessed prescriptions
      await this.processUserPrescriptions(username);

      return true;
    } catch (error) {
      console.error(
        `❌ Failed to start monitoring user ${username}:`,
        error.message
      );
      return false;
    }
  }

  // Stop monitoring a user
  stopMonitoringUser(username) {
    this.monitoringUsers.delete(username);
    console.log(`👤 Stopped monitoring prescriptions for user: ${username}`);

    // Stop polling if no users are being monitored
    if (this.monitoringUsers.size === 0 && this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
      console.log("⏹️ Stopped prescription polling");
    }
  }

  // Start polling for new prescriptions
  startPolling() {
    console.log("🔄 Started polling for new prescriptions every 30 seconds");
    this.pollInterval = setInterval(async () => {
      for (const username of this.monitoringUsers) {
        await this.processUserPrescriptions(username);
      }
    }, 30000); // Poll every 30 seconds
  }

  // Process prescriptions for a specific user
  async processUserPrescriptions(username) {
    try {
      const user = await PrescriptionMobile.findOne({ username });
      if (!user) {
        console.log(`⚠️ User ${username} not found in database`);
        return { success: false, processed: 0 };
      }

      if (!user.fcmToken) {
        console.log(`⚠️ No FCM token found for user ${username}`);
        return { success: false, processed: 0 };
      }

      // Get prescriptions that haven't been processed yet
      const unprocessedPrescriptions = user.prescriptions.filter(
        (prescription) => {
          return (
            prescription._id &&
            (!user.lastProcessed ||
              prescription._id.getTimestamp() > user.lastProcessed)
          );
        }
      );

      if (unprocessedPrescriptions.length === 0) {
        return { success: true, processed: 0 };
      }

      console.log(
        `📋 Processing ${unprocessedPrescriptions.length} new prescriptions for ${username}`
      );

      let totalScheduled = 0;
      for (const prescription of unprocessedPrescriptions) {
        const result = await this.processPrescriptionForUser(
          prescription,
          user.fcmToken,
          username
        );
        if (result.success) {
          totalScheduled += result.scheduled;
        }
      }

      // Update last processed timestamp
      await PrescriptionMobile.findOneAndUpdate(
        { username },
        { lastProcessed: new Date() }
      );

      console.log(
        `✅ Processed ${unprocessedPrescriptions.length} prescriptions for ${username}, scheduled ${totalScheduled} reminders`
      );
      return {
        success: true,
        processed: unprocessedPrescriptions.length,
        scheduled: totalScheduled,
      };
    } catch (error) {
      console.error(
        `❌ Error processing prescriptions for ${username}:`,
        error.message
      );
      return { success: false, processed: 0, error: error.message };
    }
  }

  // Get all prescriptions for a user
  async getUserPrescriptions(username) {
    try {
      const user = await PrescriptionMobile.findOne({ username });
      if (!user) {
        return { success: false, prescriptions: [], error: "User not found" };
      }

      return {
        success: true,
        prescriptions: user.prescriptions,
        lastUpdated: user.updatedAt,
      };
    } catch (error) {
      console.error(
        `❌ Error getting prescriptions for ${username}:`,
        error.message
      );
      return { success: false, prescriptions: [], error: error.message };
    }
  }

  // Send prescription received notification
  async sendPrescriptionNotification(prescriptionData, fcmToken, username) {
    try {
      console.log(
        `📋 Sending prescription notification to ${username} for: ${prescriptionData.name}`
      );

      const message = {
        notification: {
          title: "📋 New Prescription Received!",
          body: `New medication: ${prescriptionData.name} - ${prescriptionData.beforeAfterFood} food`,
        },
        data: {
          type: "prescription",
          timestamp: new Date().toISOString(),
          prescriptionData: JSON.stringify(prescriptionData),
          prescriptionId: prescriptionData._id.toString(),
          username: username,
          medicationName: prescriptionData.name,
          beforeAfterFood: prescriptionData.beforeAfterFood,
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
                body: `New medication: ${prescriptionData.name} - ${prescriptionData.beforeAfterFood} food`,
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
        `✅ Prescription notification sent to ${username}! Response: ${response}`
      );
      return true;
    } catch (error) {
      console.error(
        `❌ Failed to send prescription notification to ${username}:`,
        error.message
      );
      return false;
    }
  }

  // Process a prescription for a specific user
  async processPrescriptionForUser(prescriptionData, fcmToken, username) {
    console.log(`🚀 Processing prescription for user: ${username}`);
    console.log(`💊 Medication: ${prescriptionData.name}`);
    console.log(`📅 Schedules: ${prescriptionData.schedules.length}`);

    try {
      // Step 1: Send immediate prescription received notification
      console.log("\n📬 Step 1: Sending prescription received notification...");
      const prescriptionSent = await this.sendPrescriptionNotification(
        prescriptionData,
        fcmToken,
        username
      );

      if (!prescriptionSent) {
        console.log("❌ Failed to send prescription notification");
        return { success: false, scheduled: 0 };
      }

      console.log("✅ Prescription notification sent!");

      // Step 2: Schedule all medication reminders
      console.log("\n⏰ Step 2: Scheduling medication reminders...");
      let totalScheduled = 0;

      prescriptionData.schedules.forEach((schedule, schedIndex) => {
        console.log(
          `\n📅 Processing schedule ${schedIndex + 1}: ${schedule.dosage}`
        );

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

            const reminderId = `${username}_${prescriptionData._id}_${
              schedule._id
            }_${reminderTime.getTime()}`;

            const success = this.scheduleReminder(
              reminderId,
              `💊 ${prescriptionData.name}`,
              `Time to take ${schedule.dosage} - ${prescriptionData.beforeAfterFood} food`,
              reminderTime,
              fcmToken,
              {
                medicationName: prescriptionData.name,
                dosage: schedule.dosage,
                beforeAfterFood: prescriptionData.beforeAfterFood,
                time: timeString,
                prescriptionId: prescriptionData._id.toString(),
                username: username,
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

      console.log(`\n✅ Prescription processing completed for ${username}!`);
      console.log(`   📬 Prescription notification: SENT`);
      console.log(`   ⏰ Medication reminders scheduled: ${totalScheduled}`);

      return {
        success: true,
        scheduled: totalScheduled,
        prescriptionId: prescriptionData._id.toString(),
      };
    } catch (error) {
      console.error(`❌ Error processing prescription for ${username}:`, error);
      return { success: false, scheduled: 0, error: error.message };
    }
  }

  // Schedule a medication reminder for a specific time
  scheduleReminder(
    id,
    title,
    body,
    scheduledTime,
    fcmToken,
    medicationData = null
  ) {
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
      await this.sendMedicationReminder(
        id,
        title,
        body,
        fcmToken,
        medicationData
      );
      this.scheduledReminders.delete(id);
    }, delay);

    this.scheduledReminders.set(id, {
      timeoutId,
      scheduledTime,
      title,
      body,
      fcmToken,
      medicationData,
    });

    return true;
  }

  // Send a medication reminder notification
  async sendMedicationReminder(
    id,
    title,
    body,
    fcmToken,
    medicationData = null
  ) {
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
            username: medicationData.username,
            medicationName: medicationData.medicationName,
            dosage: medicationData.dosage,
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
        token: fcmToken,
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

  // Test FCM connectivity
  async testConnection(fcmToken) {
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
        token: fcmToken,
      };

      const response = await admin.messaging().send(message);
      console.log("✅ Connection test successful! Response:", response);
      return true;
    } catch (error) {
      console.error("❌ Connection test failed:", error.message);
      return false;
    }
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
}

// Initialize notification service
const notificationService = new MobileNotificationService();

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  dbName: "test",
});

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: "Invalid or expired token" });
    }
    req.user = user;
    next();
  });
};

// =============================================================================
// API ROUTES
// =============================================================================

// Auth endpoints
app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res
        .status(400)
        .json({ error: "Username and password are required" });
    }

    // Find user in Patient collection for authentication
    const patient = await Patient.findOne({ username });
    if (!patient) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Check password
    if (patient.password !== password) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Also check/create prescription mobile record for this user
    let prescriptionUser = await PrescriptionMobile.findOne({ username });
    if (!prescriptionUser) {
      // Create prescription mobile record if it doesn't exist
      prescriptionUser = new PrescriptionMobile({
        username: patient.username,
        password: patient.password, // Keep same password for consistency
        prescriptions: [],
        fcmToken: null,
        lastProcessed: new Date(),
      });
      await prescriptionUser.save();
      console.log(`📋 Created prescription record for new user: ${username}`);
    }

    // Generate JWT token
    const token = jwt.sign(
      { username: patient.username, userId: patient._id },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // Return user data and token
    res.json({
      token,
      user: {
        username: patient.username,
        id: patient._id,
        name: patient.name,
        email: patient.email,
        phone: patient.phone,
        prescriptions: prescriptionUser.prescriptions,
        lastUpdated: prescriptionUser.updatedAt,
      },
    });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Update FCM token
app.post("/api/auth/update-fcm-token", authenticateToken, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    const { username } = req.user;

    if (!fcmToken) {
      return res.status(400).json({ error: "FCM token is required" });
    }

    // Update user's FCM token in database and start monitoring
    await notificationService.startMonitoringUser(username, fcmToken);

    res.json({ message: "FCM token updated successfully" });
  } catch (error) {
    console.error("FCM token update error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Get user profile
app.get("/api/auth/profile", authenticateToken, async (req, res) => {
  try {
    const { username } = req.user;

    // Find user in Patient collection
    const patient = await Patient.findOne({ username }).select("-password");
    if (!patient) {
      return res.status(404).json({ error: "User not found" });
    }

    // Get prescription data
    const prescriptionUser = await PrescriptionMobile.findOne({ username });

    res.json({
      user: {
        username: patient.username,
        id: patient._id,
        name: patient.name,
        email: patient.email,
        phone: patient.phone,
        fcmToken: patient.fcmToken,
        prescriptions: prescriptionUser ? prescriptionUser.prescriptions : [],
        lastUpdated: patient.updatedAt,
        createdAt: patient.createdAt,
      },
    });
  } catch (error) {
    console.error("Profile error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Get user prescriptions
app.get("/api/prescriptions", authenticateToken, async (req, res) => {
  try {
    const { username } = req.user;

    const result = await notificationService.getUserPrescriptions(username);

    if (result.success) {
      res.json({
        prescriptions: result.prescriptions,
        lastUpdated: result.lastUpdated,
      });
    } else {
      res.status(404).json({ error: result.error });
    }
  } catch (error) {
    console.error("Get prescriptions error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Sync prescriptions (force check for new prescriptions)
app.post("/api/prescriptions/sync", authenticateToken, async (req, res) => {
  try {
    const { username } = req.user;

    // Get user's current FCM token
    const user = await PrescriptionMobile.findOne({ username });
    if (!user || !user.fcmToken) {
      return res
        .status(400)
        .json({ error: "User not found or FCM token not set" });
    }

    // Process any new prescriptions
    const result = await notificationService.processUserPrescriptions(username);

    if (result.success) {
      // Get updated prescriptions
      const prescriptionsResult =
        await notificationService.getUserPrescriptions(username);

      res.json({
        message: "Prescriptions synced successfully",
        processed: result.processed,
        scheduled: result.scheduled,
        prescriptions: prescriptionsResult.prescriptions,
      });
    } else {
      res.status(500).json({ error: result.error });
    }
  } catch (error) {
    console.error("Sync prescriptions error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Admin endpoint to add prescriptions (for web app integration)
app.post("/api/admin/prescriptions", async (req, res) => {
  try {
    const { username, prescription } = req.body;

    if (!username || !prescription) {
      return res
        .status(400)
        .json({ error: "Username and prescription data are required" });
    }

    // Add prescription to user's account WITHOUT updating lastProcessed
    // This allows the new prescription to be detected and processed
    const user = await PrescriptionMobile.findOneAndUpdate(
      { username },
      {
        $push: { prescriptions: prescription },
        // Removed: $set: { lastProcessed: new Date() }
      },
      { new: true, upsert: false }
    );

    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    console.log(
      `📋 Admin: Added prescription "${prescription.name}" for user ${username}`
    );

    // Process the new prescription if user has FCM token
    if (user.fcmToken) {
      console.log(`📋 Admin: Processing prescriptions for user ${username}...`);
      const result = await notificationService.processUserPrescriptions(
        username
      );
      console.log(`📋 Admin: Processing result:`, result);

      res.json({
        message: "Prescription added and processed successfully",
        prescriptionId: prescription._id,
        scheduled: result.scheduled || 0,
      });
    } else {
      res.json({
        message:
          "Prescription added successfully (no FCM token for notifications)",
        prescriptionId: prescription._id,
      });
    }
  } catch (error) {
    console.error("Add prescription error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Health check endpoint
app.get("/api/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    mongoConnected: mongoose.connection.readyState === 1,
    monitoringUsers: notificationService.monitoringUsers.size,
    scheduledReminders: notificationService.scheduledReminders.size,
  });
});

// Test notification endpoint
app.post("/api/test/notification", authenticateToken, async (req, res) => {
  try {
    const { username } = req.user;

    const user = await PrescriptionMobile.findOne({ username });
    if (!user || !user.fcmToken) {
      return res
        .status(400)
        .json({ error: "User not found or FCM token not set" });
    }

    // Send test notification
    const success = await notificationService.testConnection(user.fcmToken);

    if (success) {
      res.json({ message: "Test notification sent successfully" });
    } else {
      res.status(500).json({ error: "Failed to send test notification" });
    }
  } catch (error) {
    console.error("Test notification error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Get scheduled reminders endpoint
app.get("/api/admin/scheduled-reminders", (req, res) => {
  try {
    const reminders = notificationService.getScheduledReminders();
    res.json({
      count: reminders.length,
      reminders: reminders,
    });
  } catch (error) {
    console.error("Get scheduled reminders error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Force process prescriptions for a user (admin endpoint)
app.post("/api/admin/force-process", async (req, res) => {
  try {
    const { username } = req.body;

    if (!username) {
      return res.status(400).json({ error: "Username is required" });
    }

    console.log(
      `🔧 Admin: Force processing prescriptions for user: ${username}`
    );

    // Reset lastProcessed to force reprocessing
    await PrescriptionMobile.findOneAndUpdate(
      { username },
      { lastProcessed: new Date(0) } // Set to epoch to force all prescriptions to be considered new
    );

    // Get user's FCM token
    const user = await PrescriptionMobile.findOne({ username });
    if (!user || !user.fcmToken) {
      return res.status(400).json({ error: "User not found or no FCM token" });
    }

    // Force process
    const result = await notificationService.processUserPrescriptions(username);

    console.log(`🔧 Admin: Force processing result:`, result);

    res.json({
      message: "Force processing completed",
      result: result,
    });
  } catch (error) {
    console.error("Force process error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 MedAssist Mobile Server running on port ${PORT}`);
  console.log(
    `📊 MongoDB URI: ${process.env.MONGO_URI ? "Configured" : "Missing"}`
  );
  console.log(
    `🔐 JWT Secret: ${process.env.JWT_SECRET ? "Configured" : "Missing"}`
  );
  console.log(
    `📱 Firebase Admin: ${
      admin.apps.length > 0 ? "Initialized" : "Not initialized"
    }`
  );
  console.log(`🔗 Health check: http://localhost:${PORT}/api/health`);
});

module.exports = app;

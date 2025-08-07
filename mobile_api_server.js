const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");
const { PrescriptionMobile } = require("./models/prescription_mobile");
const MedAssistNotificationService = require("./medassist_notification_service");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 5001;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize notification service
const notificationService = new MedAssistNotificationService();

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

// Auth endpoints
app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res
        .status(400)
        .json({ error: "Username and password are required" });
    }

    // Find user in database
    const user = await PrescriptionMobile.findOne({ username });
    if (!user) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Check password (assuming plain text for now, but should be hashed)
    if (user.password !== password) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Generate JWT token
    const token = jwt.sign(
      { username: user.username, userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // Return user data and token
    res.json({
      token,
      user: {
        username: user.username,
        id: user._id,
        prescriptions: user.prescriptions,
        lastUpdated: user.updatedAt,
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

    // Update user's FCM token in database
    await PrescriptionMobile.findOneAndUpdate(
      { username },
      { fcmToken },
      { new: true }
    );

    // Start monitoring this user for new prescriptions
    await notificationService.startMonitoringUser(username, fcmToken);

    res.json({ message: "FCM token updated successfully" });
  } catch (error) {
    console.error("FCM token update error:", error);
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

    // Add prescription to user's account
    const user = await PrescriptionMobile.findOneAndUpdate(
      { username },
      {
        $push: { prescriptions: prescription },
        $set: { lastProcessed: new Date() },
      },
      { new: true, upsert: false }
    );

    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    // Process the new prescription if user has FCM token
    if (user.fcmToken) {
      const result = await notificationService.processUserPrescriptions(
        username
      );
      res.json({
        message: "Prescription added and processed successfully",
        prescriptionId: prescription._id,
        scheduled: result.scheduled,
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
    mongoConnected: notificationService.mongoConnected,
    monitoringUsers: notificationService.monitoringUsers.size,
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

// Start server
app.listen(PORT, () => {
  console.log(`🚀 MedAssist Mobile API Server running on port ${PORT}`);
  console.log(
    `📊 MongoDB URI: ${process.env.MONGO_URI ? "Configured" : "Missing"}`
  );
  console.log(
    `🔐 JWT Secret: ${process.env.JWT_SECRET ? "Configured" : "Missing"}`
  );

  // Connect to MongoDB and initialize notification service
  notificationService
    .connectToMongoDB()
    .then(() => {
      console.log("✅ Notification service ready");
    })
    .catch((err) => {
      console.error("❌ Failed to initialize notification service:", err);
    });
});

module.exports = app;

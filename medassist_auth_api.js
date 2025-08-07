const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const connectDB = require("./config/db");
const cron = require("node-cron");
const jwt = require("jsonwebtoken");
const Patient = require("./models/patientModel");

// Load environment variables
dotenv.config();

// Connect to database
connectDB();

const app = express();

// Middleware
app.use(
  cors({
    origin: process.env.CORS_ORIGIN || "http://localhost:3000",
    credentials: true,
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use("/api/patients", require("./routes/patientRoutes"));
app.use("/api/prescriptions", require("./routes/prescriptionRoutes"));
app.use("/api/billing", require("./routes/billingRoutes"));
app.use("/api/reminders", require("./routes/reminderRoutes"));
const fcmRoutes = require("./routes/fcmRoutes");
app.use("/api/fcm", fcmRoutes);

const reminderRoutes = require("./routes/reminderRoutes");
app.use("/api/reminders", reminderRoutes);

// JWT secret
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key-here";

// ============ MOBILE APP AUTHENTICATION ROUTES ============

// Mobile App Login endpoint
app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    console.log(`📱 Mobile login attempt for username: ${username}`);

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required",
      });
    }

    // Find patient by username
    const patient = await Patient.findOne({ username: username.trim() });

    if (!patient) {
      console.log(`📱 Patient not found for username: ${username}`);
      return res.status(401).json({
        success: false,
        message: "Invalid username or password",
      });
    }

    // Check password (plain text comparison for now - in production, use bcrypt)
    if (patient.password !== password) {
      console.log(`📱 Invalid password for username: ${username}`);
      return res.status(401).json({
        success: false,
        message: "Invalid username or password",
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        patientId: patient._id,
        username: patient.username,
        type: "mobile", // distinguish from web app tokens
      },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    console.log(`📱 Mobile login successful for username: ${username}`);

    // Return user data without password
    const userResponse = {
      _id: patient._id,
      name: patient.name,
      email: patient.email,
      phone: patient.phone,
      dateOfBirth: patient.dateOfBirth,
      gender: patient.gender,
      address: patient.address,
      emergencyContact: patient.emergencyContact,
      medicalHistory: patient.medicalHistory,
      currentIllness: patient.currentIllness,
      lastVisit: patient.lastVisit,
      notes: patient.notes,
      fcmToken: patient.fcmToken,
      username: patient.username,
    };

    res.json({
      success: true,
      message: "Login successful",
      user: userResponse,
      token: token,
    });
  } catch (error) {
    console.error("📱 Mobile login error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Update FCM token endpoint
app.post("/api/auth/update-fcm-token", async (req, res) => {
  try {
    const { authorization } = req.headers;
    const { fcmToken } = req.body;

    if (!authorization || !authorization.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authorization token required",
      });
    }

    const token = authorization.substring(7); // Remove 'Bearer ' prefix

    // Verify JWT token
    const decoded = jwt.verify(token, JWT_SECRET);
    const patientId = decoded.patientId;

    // Update FCM token
    await Patient.findByIdAndUpdate(patientId, { fcmToken });

    console.log(`📱 FCM token updated for patient: ${patientId}`);

    res.json({
      success: true,
      message: "FCM token updated successfully",
    });
  } catch (error) {
    console.error("📱 Update FCM token error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update FCM token",
    });
  }
});

// Get user profile endpoint
app.get("/api/auth/profile", async (req, res) => {
  try {
    const { authorization } = req.headers;

    if (!authorization || !authorization.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authorization token required",
      });
    }

    const token = authorization.substring(7); // Remove 'Bearer ' prefix

    // Verify JWT token
    const decoded = jwt.verify(token, JWT_SECRET);
    const patient = await Patient.findById(decoded.patientId).select(
      "-password"
    );

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      success: true,
      user: patient,
    });
  } catch (error) {
    console.error("📱 Get profile error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get user profile",
    });
  }
});

// List all patients with credentials (for development/testing)
app.get("/api/auth/patients-list", async (req, res) => {
  try {
    const patients = await Patient.find(
      {},
      "name username password email phone gender currentIllness"
    );
    res.json({
      success: true,
      patients: patients.map((p) => ({
        name: p.name,
        username: p.username,
        password: p.password,
        email: p.email,
        phone: p.phone,
        gender: p.gender,
        currentIllness: p.currentIllness,
      })),
      count: patients.length,
    });
  } catch (error) {
    console.error("📱 Get patients error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get patients",
    });
  }
});

// ============ END MOBILE APP AUTHENTICATION ROUTES ============

// Health check route
app.get("/api/health", (req, res) => {
  res.status(200).json({
    message: "MedAssist API is running",
    timestamp: new Date().toISOString(),
    endpoints: {
      web: "Web app routes available",
      mobile: "Mobile auth routes available at /api/auth/*",
    },
  });
});

// Scheduled job: Delete patients 7+ days after lastVisit
cron.schedule("0 2 * * *", async () => {
  try {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const result = await Patient.deleteMany({
      lastVisit: { $lt: sevenDaysAgo },
    });
    if (result.deletedCount > 0) {
      console.log(
        `[CRON] Deleted ${result.deletedCount} patient(s) with lastVisit older than 7 days.`
      );
    }
  } catch (err) {
    console.error("[CRON] Error deleting old patients:", err);
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res
    .status(500)
    .json({ message: "Something went wrong!", error: err.message });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({ message: "Route not found" });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`🚀 MedAssist Server running on port ${PORT}`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
  console.log(
    `👥 Patients list: http://localhost:${PORT}/api/auth/patients-list`
  );
  console.log(`🔐 Mobile login: http://localhost:${PORT}/api/auth/login`);
});

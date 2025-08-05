const admin = require("firebase-admin");
const serviceAccount = require("./medassist-f675c-firebase-adminsdk-fbsvc-4a4975b192.json");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// Test FCM token from prescription_scheduler.js
const FCM_TOKEN =
  "ftRZSedhQve3-4L8KDgXwt:APA91bFYP7AyzbqNr1My5C_7SA0tZg3pcq1s8iR3YVCPNvCRuSOIJ6hBuZUg2V2TyKv45Zz3t4l5cm15kGjRFLHDoNEZHVWDSIx_qAfJQWFs6TEHQpftsCA";

async function testFCMToken() {
  try {
    console.log("🧪 Testing FCM Token...");
    console.log("Token:", FCM_TOKEN);

    const message = {
      notification: {
        title: "🧪 Token Test",
        body: "Testing if FCM token is valid",
      },
      data: {
        type: "test",
        timestamp: new Date().toISOString(),
      },
      token: FCM_TOKEN,
    };

    const response = await admin.messaging().send(message);
    console.log("✅ FCM Token is valid! Response:", response);
    console.log("📱 Check your Flutter app for the test notification");
  } catch (error) {
    console.error("❌ FCM Token test failed:");
    console.error("Error code:", error.code);
    console.error("Error message:", error.message);

    if (error.code === "messaging/registration-token-not-registered") {
      console.log(
        "💡 The token is not registered. Get a fresh token from your Flutter app."
      );
    } else if (error.code === "messaging/invalid-registration-token") {
      console.log(
        "💡 The token format is invalid. Get a fresh token from your Flutter app."
      );
    } else {
      console.log(
        "💡 Check your Firebase project configuration and service account."
      );
    }
  }
}

testFCMToken();

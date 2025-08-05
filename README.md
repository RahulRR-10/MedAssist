# 💊 MedAssist - Smart Prescription Reminder App

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)

MedAssist is a comprehensive Flutter-based mobile application that helps patients manage their prescriptions and medication schedules. The app provides smart notifications and integrates with healthcare provider systems to ensure patients never miss their medications.

## ✨ Features

### 📱 Mobile App Features
- **📋 Digital Prescriptions**: Receive and view digital prescriptions from healthcare providers
- **⏰ Smart Reminders**: Automated medication reminders with customizable timing
- **🔔 Push Notifications**: Real-time notifications for new prescriptions and medication times
- **📊 Medication Tracking**: Track medication schedules and follow-up appointments
- **🎨 Clean UI/UX**: Minimalistic blue-white design for easy navigation
- **🗑️ Prescription Management**: Add, view, and delete prescriptions with confirmation
- **🔄 Real-time Sync**: Instant updates when new prescriptions are received

### 🌐 Web Integration Features
- **🚀 Firebase Cloud Messaging (FCM)**: Reliable push notification delivery
- **⚡ Real-time Scheduling**: Dynamic medication reminder scheduling
- **🔒 Secure Communication**: Encrypted data transmission between web app and mobile
- **📡 Background Processing**: Notifications work even when app is closed
- **🌍 Timezone Support**: Proper handling of different time zones (GMT+5:30)
- **⏰ 12-hour Format**: User-friendly time display format

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: Version 3.7.2 or higher
- **Dart SDK**: Version 3.0.0 or higher
- **Node.js**: Version 16.0 or higher (for notification service)
- **Firebase Project**: With Cloud Messaging enabled
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)

### 🔧 Installation

#### 1. Clone the Repository
```bash
git clone https://github.com/RahulRR-10/MedAssist.git
cd MedAssist
```

#### 2. Install Flutter Dependencies
```bash
flutter pub get
```

#### 3. Install Node.js Dependencies
```bash
npm install firebase-admin
```

#### 4. Firebase Setup

1. **Create a Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project named "medassist-f675c" (or your preferred name)
   - Enable Cloud Messaging

2. **Download Configuration Files**:
   - **Android**: Download `google-services.json` and place in `android/app/`
   - **iOS**: Download `GoogleService-Info.plist` and place in `ios/Runner/`

3. **Download Service Account Key**:
   - Go to Project Settings → Service Accounts
   - Generate new private key
   - Save as `medassist-f675c-firebase-adminsdk-[xxx].json` in project root

4. **Update Configuration**:
   ```javascript
   // In medassist_notification_service.js
   const serviceAccount = require("./your-firebase-adminsdk-file.json");
   ```

#### 5. Update FCM Token
```javascript
// In medassist_notification_service.js, update with your device's FCM token
const FCM_TOKEN = "your_device_fcm_token_here";
```

#### 6. Run the Application
```bash
# For Android
flutter run

# For iOS
flutter run --device ios
```

## 📚 Project Structure

```
lib/
├── main.dart                     # App entry point
├── models/
│   └── prescription_model.dart   # Data models for prescriptions
├── screens/
│   ├── home_screen.dart         # Main prescription list screen
│   └── prescription_details_screen.dart  # Detailed prescription view
├── services/
│   ├── notification_service.dart    # FCM & local notifications
│   └── storage_service.dart        # Local data persistence
└── utils/
    └── logger.dart              # Logging utilities

Root Files:
├── medassist_notification_service.js  # Node.js notification service
├── pubspec.yaml                       # Flutter dependencies
└── README.md                         # This file
```

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the project root:
```env
FIREBASE_PROJECT_ID=medassist-f675c
FIREBASE_STORAGE_BUCKET=medassist-f675c.appspot.com
```

### Notification Channels
The app creates the following notification channels:
- **Prescription Confirmations**: For new prescription notifications
- **Medication Reminders**: For scheduled medication alerts

## 🌐 Web App Integration

### Basic Usage
```javascript
const MedAssistNotificationService = require('./medassist_notification_service');

// Initialize the service
const notificationService = new MedAssistNotificationService();

// Send prescription to mobile app
app.post('/api/prescriptions', async (req, res) => {
  const prescriptionData = req.body;
  
  const result = await notificationService.processPrescription(prescriptionData);
  
  if (result.success) {
    res.json({
      success: true,
      message: `Prescription sent! ${result.scheduled} reminders scheduled.`,
      prescriptionId: result.prescriptionId
    });
  } else {
    res.status(500).json({
      success: false, 
      error: result.error
    });
  }
});
```

### Prescription Data Format
```javascript
const prescriptionData = {
  patientId: "patient_unique_id",
  diagnosis: "Patient Condition",
  symptom: "Reported symptoms",
  medications: [{
    name: "Medication Name",
    beforeAfterFood: "Before", // or "After"
    schedules: [{
      startDate: "2025-08-05T00:00:00.000Z",
      endDate: "2025-08-07T00:00:00.000Z",
      dosage: "250mg",
      times: ["8:00 AM", "2:00 PM", "8:00 PM"],
      _id: "schedule_id"
    }],
    _id: "medication_id"
  }],
  followUpDate: "2025-08-10T00:00:00.000Z",
  notes: "Additional instructions",
  _id: "prescription_id"
};
```

## 🧪 Testing

### Run Flutter Tests
```bash
flutter test
```

### Test Notification Service
```bash
# Test FCM connectivity
node medassist_notification_service.js

# Test with custom prescription
node -e "
const Service = require('./medassist_notification_service');
const service = new Service();
service.testConnection();
"
```

### Debug Commands
```bash
# Check FCM token
flutter run --debug

# View Flutter logs
flutter logs

# Check notification permissions
adb shell dumpsys notification
```

## 📱 Platform Support

| Platform | Status | Min Version |
|----------|--------|-------------|
| Android  | ✅ Supported | API 21+ (Android 5.0) |
| iOS      | ✅ Supported | iOS 12.0+ |
| Web      | ⚠️ Limited | Chrome 70+ |
| Windows  | ⚠️ Limited | Windows 10+ |
| macOS    | ⚠️ Limited | macOS 10.15+ |
| Linux    | ⚠️ Limited | Ubuntu 18.04+ |

## 🔒 Security & Privacy

- **🔐 End-to-End Encryption**: All prescription data is encrypted in transit
- **🔒 Secure Storage**: Local data encrypted using Flutter Secure Storage
- **🛡️ Firebase Security**: Authenticated API calls only
- **🔑 Token Management**: FCM tokens securely managed and refreshed
- **📝 Privacy Compliance**: HIPAA-ready architecture
- **🚫 No Data Mining**: No user data collection for advertising

## 🔧 Troubleshooting

### Common Issues

#### 1. **Notifications Not Received**
```bash
# Check FCM token
flutter run --debug
# Look for: "FCM TOKEN: ..." in console

# Update token in notification service
const FCM_TOKEN = "your_new_token_here";
```

#### 2. **App Crashes on Prescription**
```bash
# Clear app data
flutter clean
flutter pub get
flutter run

# Check for null pointer exceptions in logs
flutter logs
```

#### 3. **Firebase Connection Issues**
```bash
# Verify google-services.json exists
ls android/app/google-services.json

# Check Firebase project ID
grep project_id android/app/google-services.json
```

#### 4. **Background Notifications Not Working**
- Ensure battery optimization is disabled for the app
- Check notification permissions in system settings
- Verify FCM service account has correct permissions

### Debug Mode
```bash
# Enable debug logging
flutter run --debug --verbose

# For production builds
flutter build apk --release
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create your feature branch**: `git checkout -b feature/AmazingFeature`
3. **Commit your changes**: `git commit -m 'Add some AmazingFeature'`
4. **Push to the branch**: `git push origin feature/AmazingFeature`
5. **Open a Pull Request**

### Development Guidelines
- Follow [Flutter style guide](https://dart.dev/guides/language/effective-dart/style)
- Write tests for new features
- Update documentation for API changes
- Use meaningful commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter Team** for the amazing framework
- **Firebase Team** for reliable backend services
- **Material Design** for UI/UX guidelines
- **Community Contributors** for feedback and improvements

## 📞 Support

- **📧 Email**: support@medassist.app
- **🐛 Issues**: [GitHub Issues](https://github.com/RahulRR-10/MedAssist/issues)
- **📖 Documentation**: [Wiki](https://github.com/RahulRR-10/MedAssist/wiki)
- **💬 Discussions**: [GitHub Discussions](https://github.com/RahulRR-10/MedAssist/discussions)

---

**Made with ❤️ for better healthcare management**

*Last updated: August 5, 2025*

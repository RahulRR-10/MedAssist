# 💊 MedAssist - Smart Prescription Management System

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-4EA94B?style=for-the-badge&logo=mongodb&logoColor=white)

A complete healthcare solution combining Flutter mobile app with Node.js backend for prescription management, medication reminders, and real-time notifications.

## 🌟 Features

### 📱 Mobile App (Flutter)

- ✅ **Secure Authentication** - JWT-based login system
- ✅ **Prescription Sync** - Real-time sync with backend server
- ✅ **Offline Storage** - View prescriptions without internet
- ✅ **Push Notifications** - FCM-powered medication reminders
- ✅ **Duplicate Prevention** - Smart sync without duplicates
- ✅ **User Profiles** - Complete patient information management

### 🖥️ Backend Server (Node.js)

- ✅ **Consolidated API** - Single server for all functionality
- ✅ **MongoDB Integration** - Robust data storage
- ✅ **Automatic Reminders** - Intelligent medication scheduling
- ✅ **FCM Notifications** - Real-time push notifications
- ✅ **Web App Integration** - Easy prescription addition from web
- ✅ **Background Monitoring** - 24/7 prescription processing

### 🔔 Notification System

- ✅ **Prescription Alerts** - Immediate notification when new prescription added
- ✅ **Medication Reminders** - Precise timing based on prescription schedules
- ✅ **Smart Scheduling** - Skips past times, handles time zones
- ✅ **Persistent Reminders** - Continues working even after server restart

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** (3.0+)
- **Node.js** (16+)
- **MongoDB** (Cloud or local)
- **Firebase Project** (for FCM)
- **Android Studio** or **VS Code**

### 1. Clone Repository

```bash
git clone https://github.com/YourUsername/MedAssist.git
cd MedAssist
```

### 2. Backend Setup

```bash
# Install Node.js dependencies
npm install

# Create environment file
cp .env.example .env
# Edit .env with your MongoDB URI and JWT secret

# Start the server
npm start
# OR use the batch file on Windows
.\start_mobile_api.bat
```

### 3. Mobile App Setup

```bash
# Install Flutter dependencies
flutter pub get

# Configure Firebase
# 1. Add your google-services.json to android/app/
# 2. Add your service account JSON to root directory

# Run the app
flutter run
```

## 🛠️ Configuration

### Environment Variables (.env)

Create a `.env` file in the root directory:

```env
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/database
JWT_SECRET=your-super-secret-jwt-key-here
NODE_ENV=development
PORT=5000
```

### Firebase Setup

1. Create Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Cloud Messaging
3. Download service account key
4. Add `google-services.json` to `android/app/`
5. Place service account JSON in project root (will be gitignored)

## 📊 System Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Web App   │───▶│  MongoDB    │◀───│ Mobile API  │
│             │    │             │    │   Server    │
└─────────────┘    └─────────────┘    └─────────────┘
                                              │
                                              ▼
                                      ┌─────────────┐
                                      │   Firebase  │
                                      │     FCM     │
                                      └─────────────┘
                                              │
                                              ▼
                                      ┌─────────────┐
                                      │ Flutter App │
                                      │   Mobile    │
                                      └─────────────┘
```

## 🔧 API Endpoints

### Authentication

- `POST /api/auth/login` - User login
- `POST /api/auth/update-fcm-token` - Update FCM token

### Prescriptions

- `GET /api/prescriptions` - Get user prescriptions
- `POST /api/prescriptions/sync` - Sync prescriptions
- `POST /api/admin/prescriptions` - Add prescription (admin)

### System

- `GET /api/health` - Server health check
- `POST /api/test/notification` - Test FCM connectivity
- `GET /api/admin/scheduled-reminders` - View scheduled reminders

## 📋 Database Schema

### Users Collection (`test.patients`)

```javascript
{
  username: "patient123",
  password: "hashedPassword",
  fcmToken: "fcm-token-string",
  name: "John Doe",
  email: "john@example.com",
  phone: "+1234567890"
}
```

### Prescriptions Collection (`test.prescriptionmobiles`)

```javascript
{
  username: "patient123",
  prescriptions: [
    {
      name: "Aspirin",
      beforeAfterFood: "Before",
      schedules: [
        {
          startDate: "2025-08-07T00:00:00.000Z",
          endDate: "2025-08-14T00:00:00.000Z",
          dosage: "100mg",
          times: ["8:00 AM", "8:00 PM"]
        }
      ]
    }
  ],
  fcmToken: "fcm-token-string",
  lastProcessed: "2025-08-07T10:00:00.000Z"
}
```

## 🧪 Testing

### Create Test Users in MongoDB

Before testing, create user accounts in your MongoDB `test.patients` collection:

```javascript
// Example user creation
{
  username: "testuser",
  password: "testpass", // Use hashing in production
  name: "Test User",
  email: "test@example.com",
  phone: "+1234567890"
}
```

### Test Prescription Addition

```bash
curl -X POST http://localhost:5000/api/admin/prescriptions \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "prescription": {
      "name": "Test Medicine",
      "beforeAfterFood": "Before",
      "schedules": [{
        "startDate": "2025-08-07T00:00:00.000Z",
        "endDate": "2025-08-10T00:00:00.000Z",
        "dosage": "250mg",
        "times": ["9:00 AM", "9:00 PM"]
      }]
    }
  }'
```

## 🔧 Development

### Project Structure

```
MedAssist/
├── lib/                    # Flutter app source code
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # API services
│   └── utils/             # Utilities
├── mobile_server.js       # Consolidated Node.js server
├── package.json           # Node.js dependencies
├── pubspec.yaml          # Flutter dependencies
└── README.md             # This file
```

### Building for Production

```bash
# Android APK
flutter build apk --release

# iOS IPA (macOS only)
flutter build ios --release

# Server deployment
npm start
```

## 👥 Multi-User Support

This app is designed to work with any number of users:

### User Registration

- Users can be added directly to the MongoDB `test.patients` collection
- Each user gets their own prescription data in `test.prescriptionmobiles`
- FCM tokens are managed per user for personalized notifications

### User Authentication

- JWT-based authentication works for any valid username/password
- No hardcoded user credentials in the app
- Secure login flow with token-based sessions

### Data Isolation

- Each user's prescriptions are stored separately
- Notifications are sent only to the intended user
- Complete privacy between different users

## 🚨 Security Notes

- ⚠️ **Never commit** `.env` files
- ⚠️ **Never commit** Firebase service account keys
- ⚠️ **Use strong JWT secrets** in production
- ⚠️ **Enable MongoDB authentication** in production
- ⚠️ **Use HTTPS** in production
- ⚠️ **Hash passwords** properly in production

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for reliable push notifications
- MongoDB for robust data storage
- Node.js community for excellent libraries

## 📞 Support

For support, open an issue on GitHub or check the [Mobile API Documentation](README_MOBILE_API.md).

---

**Built with ❤️ using Flutter, Node.js, MongoDB, and Firebase**

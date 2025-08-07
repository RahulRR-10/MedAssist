# MedAssist Mobile Server - Complete Prescription Management System

## Overview

This is a single, consolidated server that handles everything for the mobile app:

1. **Authentication** - User login with JWT tokens
2. **Prescription Management** - MongoDB integration for prescription storage
3. **FCM Notifications** - Immediate prescription alerts and scheduled medication reminders
4. **Automatic Monitoring** - Polls MongoDB every 30 seconds for new prescriptions

## System Architecture

```
Web App → MongoDB (test.prescriptionmobiles) ← Mobile Server (Port 5000)
                                                      ↓
Mobile Server ← MongoDB (test.patients) ← Authentication & FCM Tokens
                                                      ↓
                                               FCM Notifications
                                                      ↓
                                               Mobile App (Flutter)
```

## Quick Start

### 1. Start the Server

**Windows:**

```cmd
start_mobile_api.bat
```

**Manual:**

```bash
npm install
npm start
```

**Server will run on:** http://localhost:5000

### 2. Health Check

Visit: http://localhost:5000/api/health

### 3. Available Endpoints

- **Login:** `POST /api/auth/login`
- **Update FCM Token:** `POST /api/auth/update-fcm-token`
- **Get Prescriptions:** `GET /api/prescriptions`
- **Sync Prescriptions:** `POST /api/prescriptions/sync`
- **Add Prescription (Admin):** `POST /api/admin/prescriptions`
- **Test Notification:** `POST /api/test/notification`

## MongoDB Schema

### Collection: `test.patients` (Authentication)

```javascript
{
  username: "patient123",
  password: "hashedPassword",
  fcmToken: "fcm-token-here",
  name: "Patient Name",
  email: "patient@example.com",
  phone: "+1234567890"
}
```

### Collection: `test.prescriptionmobiles` (Prescription Data)

```javascript
{
  username: "patient123",
  password: "hashedPassword", // Synced with patients collection
  prescriptions: [
    {
      name: "Aspirin",
      beforeAfterFood: "Before", // "Before" or "After"
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
  fcmToken: "fcm-token-here", // Synced with patients collection
  lastProcessed: "2025-08-07T10:00:00.000Z"
}
```

## Setup Instructions

### 1. Environment Setup

Create `.env` file:

```
MONGO_URI=mongodb+srv://amisha:1234@cluster0.5ohdhbh.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0
JWT_SECRET=your-super-secret-jwt-key-here-change-in-production
NODE_ENV=development
PORT=5000
```

### 2. Start Mobile API Server

**Windows:**

```cmd
start_mobile_api.bat
```

**Linux/Mac:**

```bash
chmod +x start_mobile_api.sh
./start_mobile_api.sh
```

**Manual:**

```bash
npm install
npm start
```

### 3. API Endpoints

- **Health Check:** `GET http://localhost:5001/api/health`
- **Login:** `POST http://localhost:5001/api/auth/login`
- **Update FCM Token:** `POST http://localhost:5001/api/auth/update-fcm-token`
- **Get Prescriptions:** `GET http://localhost:5001/api/prescriptions`
- **Sync Prescriptions:** `POST http://localhost:5001/api/prescriptions/sync`
- **Add Prescription (Admin):** `POST http://localhost:5001/api/admin/prescriptions`

## How It Works

### 1. User Login (Mobile App)

```
Mobile App → POST /api/auth/login → Returns JWT token
```

### 2. FCM Token Registration

```
Mobile App → POST /api/auth/update-fcm-token → Server starts monitoring user
```

### 3. Prescription Addition (Web App)

```
Web App → MongoDB.prescriptionmobiles.insert({username, prescriptions})
```

### 4. Automatic Processing

```
Mobile API Server → Polls MongoDB every 30 seconds
                  → Detects new prescriptions
                  → Sends immediate notification
                  → Schedules medication reminders
```

### 5. Mobile App Sync

```
Mobile App → POST /api/prescriptions/sync → Downloads new prescriptions
           → Stores locally for offline access
```

## Notification Types

### 1. Prescription Received

- **Trigger:** New prescription added to user's account
- **Content:** "📋 New Prescription Received! New medication: [MedicationName]"

### 2. Medication Reminders

- **Trigger:** Scheduled times based on prescription schedules
- **Content:** "💊 [MedicationName] - Time to take [dosage] - [beforeAfterFood] food"

## Testing

### 1. Test Server Health

```bash
curl http://localhost:5000/api/health
```

### 2. Test Login

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"your_password"}'
```

### 3. Test Add Prescription

```bash
curl -X POST http://localhost:5000/api/admin/prescriptions \
  -H "Content-Type: application/json" \
  -d '{
    "username": "your_username",
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

## Mobile App Features

1. **Automatic Login** - Remembers user credentials
2. **FCM Token Sync** - Updates server when token changes
3. **Prescription Sync** - Downloads new prescriptions from server
4. **Manual Sync** - Sync button in app bar
5. **Offline Storage** - Prescriptions stored locally
6. **Push Notifications** - Immediate and scheduled reminders

## Integration with Web App

To integrate with your existing web app, simply insert prescriptions into the MongoDB collection:

```javascript
// Example: Adding prescription from web app
await db.prescriptionmobiles.updateOne(
  { username: "patient_username" },
  {
    $push: {
      prescriptions: {
        name: "Medicine Name",
        beforeAfterFood: "Before",
        schedules: [
          {
            startDate: new Date(),
            endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
            dosage: "100mg",
            times: ["8:00 AM", "8:00 PM"],
          },
        ],
      },
    },
  }
);
```

The mobile API server will automatically detect and process the new prescription within 30 seconds.

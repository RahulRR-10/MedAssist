# Prescription Reminder App

## Overview

This Flutter application receives prescription details via Firebase Cloud Messaging (FCM) and automatically schedules medication reminders using local notifications. The app stores prescription data locally and creates time-based reminders that work even when the device is offline.

## Features

- Receive prescription details via FCM
- Parse and store prescription data locally
- Schedule medication reminders based on prescription schedules
- Display prescription details in a user-friendly interface
- Support for multiple medications and complex schedules
- Offline reminder functionality using Flutter Local Notifications

## Technical Implementation

### FCM Message Handling

The app processes FCM messages containing prescription data in the following format:

```json
{
  "notification": {
    "title": "💊 New Prescription Details",
    "body": "You have new prescription details available. Tap to view."
  },
  "data": {
    "type": "prescription",
    "prescription": "{ ... prescription JSON ... }",
    "timestamp": "2023-07-24T17:54:15.111Z"
  }
}
```

### Prescription Data Model

The app parses the prescription JSON into a structured data model with the following components:

- `PrescriptionData`: Contains diagnosis, symptoms, follow-up date, and medications
- `Medication`: Contains medication name, timing (before/after food), and schedules
- `Schedule`: Contains dosage, start/end dates, and specific times for taking the medication

### Local Notifications

The app uses the `flutter_local_notifications` package to schedule reminders based on the medication schedules. It:

1. Parses time strings (e.g., "3:06 PM") into DateTime objects
2. Creates a notification for each medication dose within the date range
3. Uses timezone-aware scheduling to ensure reminders work correctly across time zones

## Testing

The app includes a test utility to simulate receiving an FCM message. Tap the floating action button to trigger a test notification and see the prescription details.

## Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase for your project
4. Run the app on your device or emulator

## Dependencies

- firebase_core: ^4.0.0
- firebase_messaging: ^16.0.0
- flutter_local_notifications: ^19.4.0
- timezone: ^0.10.1
- shared_preferences: ^2.5.3

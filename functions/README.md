# Energy Smart Cloud Functions

This directory contains Cloud Functions for the Energy Smart app that handle data aggregation, notifications, and automated tasks.

## Functions Overview

### 1. Daily Aggregation (`dailyAggregation`)
- **Schedule**: Runs daily at 23:59 (Asia/Manila timezone)
- **Purpose**: Aggregates daily usage data from Realtime Database to Firestore
- **Actions**:
  - Reads today's usage from `users/{uid}/todayUsage`
  - Calculates total cost using current rate
  - Saves to `users/{uid}/energy_trends/daily/data/{date}`
  - Updates weekly and monthly aggregations
  - Resets today's usage for next day

### 2. Threshold Notification (`thresholdNotification`)
- **Trigger**: When daily usage document is created
- **Purpose**: Sends push notifications when usage exceeds 80% of target
- **Actions**:
  - Checks if daily cost exceeds threshold
  - Sends FCM notification to user's devices
  - Records notification in Firestore
  - Adds activity to recent activity feed

### 3. Monthly Reset (`monthlyReset`)
- **Schedule**: Runs on the 1st of every month at 00:00
- **Purpose**: Resets all appliance usage data for new month
- **Actions**:
  - Resets `totalUsageTime` and `kwh` for all appliances
  - Turns off all appliances
  - Resets today's usage totals

### 4. Rate Update Notification (`rateUpdateNotification`)
- **Trigger**: When admin updates current rate
- **Purpose**: Notifies all users when power rate changes
- **Actions**:
  - Detects rate changes in `admin/current_rate`
  - Sends FCM notification to all users
  - Records activity in user's recent activity

## Setup Instructions

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Configure Firebase
```bash
firebase login
firebase init functions
```

### 3. Deploy Functions
```bash
npm run deploy
```

### 4. Test Functions Locally
```bash
npm run serve
```

## Environment Variables

Make sure to set up the following in Firebase Console:

1. **FCM Server Key**: For sending push notifications
2. **Firebase Project ID**: Should be automatically configured
3. **Timezone**: Functions use Asia/Manila timezone

## Database Structure

### Realtime Database
```
users/{uid}/
├── appliances/{applianceId}/
│   ├── name: string
│   ├── isOn: boolean
│   ├── watts: number
│   ├── totalUsageTime: number (cumulative)
│   ├── kwh: number (cumulative)
│   └── startTime: ISO8601 string
└── todayUsage/
    ├── totalKwh: number
    ├── totalCost: number
    └── totalUsageTime: number
```

### Firestore
```
users/{uid}/
├── energyTarget/currentTarget/
│   ├── target_cost: number
│   ├── target_kwh: number
│   └── alert_threshold: number
├── energy_trends/
│   ├── daily/data/{date}/
│   ├── weekly/data/{week}/
│   └── monthly/data/{month}/
├── recent_activity/{activityId}/
├── fcmTokens/{token}/
└── notifications/{notificationId}/

admin/
└── current_rate/
    ├── rate_per_kwh: number
    ├── last_updated: timestamp
    └── updated_by: string
```

## Monitoring

### View Function Logs
```bash
npm run logs
```

### Check Function Status
```bash
firebase functions:list
```

## Troubleshooting

### Common Issues

1. **Functions not triggering**: Check Firebase project configuration
2. **FCM notifications not sending**: Verify FCM tokens are stored correctly
3. **Aggregation errors**: Check Firestore security rules
4. **Timezone issues**: Ensure functions use Asia/Manila timezone

### Debug Mode
Enable debug logging by setting environment variable:
```bash
firebase functions:config:set debug.enabled=true
```

## Security Rules

Ensure the following Firestore security rules are in place:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Admin data is read-only for users
    match /admin/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

## Performance Considerations

1. **Batch Operations**: Functions use batch writes for efficiency
2. **Error Handling**: All functions include comprehensive error handling
3. **Rate Limiting**: FCM notifications are batched to avoid rate limits
4. **Memory Usage**: Functions are optimized for minimal memory usage

## Cost Optimization

1. **Function Execution Time**: Keep functions under 60 seconds
2. **Database Reads**: Minimize unnecessary database reads
3. **FCM Usage**: Only send notifications when necessary
4. **Storage**: Clean up old data periodically

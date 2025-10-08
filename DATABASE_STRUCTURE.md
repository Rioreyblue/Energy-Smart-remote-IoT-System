# EnergySmart Database Structure Documentation

## Overview

The EnergySmart system uses a hybrid database architecture combining **Firestore** for structured data and **Firebase Realtime Database** for real-time IoT data. This design ensures optimal performance, scalability, and real-time capabilities.

## Database Architecture

### Firestore (Structured Data)
- **Purpose**: User profiles, billing, logs, configuration, and analytics
- **Location**: Asia-Southeast1
- **Collections**: 7 main collections with subcollections

### Realtime Database (IoT Data)
- **Purpose**: Real-time device monitoring, live data, and alerts
- **Location**: Asia-Southeast1
- **Structure**: Hierarchical JSON structure under `energySmart/`

## Firestore Collections

### 1. Users Collection (`users/{userId}`)

**Purpose**: Store user profiles and general information

**Document Structure**:
```json
{
  "name": "string",
  "email": "string",
  "mobile": "string",
  "energyProvider": "string",
  "role": "user|admin",
  "isApproved": "boolean",
  "adminNotes": "string",
  "dateJoined": "timestamp",
  "userType": "residential|commercial|admin",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Subcollections**:
- `goals/{goalId}` - User energy goals and thresholds
- `estimatedBill/{billId}` - Monthly bill estimates
- `energy_usage_logs/{logId}` - Detailed usage logs

### 2. Power Rates Collection (`power_rates/{rateId}`)

**Purpose**: Admin-managed energy rates

**Document Structure**:
```json
{
  "ratePerKwh": "number",
  "effectiveDate": "timestamp",
  "endDate": "timestamp",
  "notes": "string",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "createdBy": "string"
}
```

### 3. Support Chats Collection (`support_chats/{chatId}`)

**Purpose**: User-admin communication

**Document Structure**:
```json
{
  "userId": "string",
  "adminId": "string",
  "status": "open|closed|pending",
  "subject": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "messages": [
    {
      "messageId": "string",
      "senderId": "string",
      "senderType": "user|admin",
      "message": "string",
      "timestamp": "timestamp",
      "isRead": "boolean"
    }
  ]
}
```

### 4. Tips Collection (`tips/{tipId}`)

**Purpose**: Energy-saving tips and advice

**Document Structure**:
```json
{
  "title": "string",
  "content": "string",
  "category": "lighting|heating_cooling|appliances|general",
  "imageUrl": "string",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "createdBy": "string"
}
```

### 5. Notifications Collection (`notifications/{notificationId}`)

**Purpose**: User alerts and system notices

**Document Structure**:
```json
{
  "userId": "string",
  "title": "string",
  "message": "string",
  "type": "threshold_alert|bill_ready|system_notice",
  "isRead": "boolean",
  "createdAt": "timestamp"
}
```

### 6. Device Control Collection (`device_control/{deviceId}`)

**Purpose**: IoT device configuration and control

**Document Structure**:
```json
{
  "userId": "string",
  "deviceName": "string",
  "deviceType": "air_conditioner|appliance|lighting|sensor",
  "pin": "number",
  "status": "ON|OFF",
  "isOnline": "boolean",
  "lastSeen": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 7. Admins Collection (`admins/{adminId}`)

**Purpose**: Admin user management

**Document Structure**:
```json
{
  "name": "string",
  "email": "string",
  "role": "admin|super_admin",
  "permissions": ["read_all", "write_all", "manage_users", "manage_rates"],
  "createdAt": "timestamp",
  "isActive": "boolean"
}
```

## Realtime Database Structure

### Root Path: `energySmart/`

#### 1. Devices (`energySmart/devices/{deviceId}`)

**Purpose**: Real-time IoT device data

**Structure**:
```json
{
  "status": "ON|OFF",
  "voltage": "number",
  "current": "number",
  "power": "number",
  "energy_kwh": "number",
  "relay_state": "boolean",
  "userId": "string",
  "deviceName": "string",
  "deviceType": "string",
  "last_updated": "ISO8601_timestamp",
  "isOnline": "boolean",
  "temperature": "number (optional)",
  "humidity": "number (optional)",
  "brightness": "number (optional)",
  "color": "string (optional)"
}
```

#### 2. User Usage Summary (`energySmart/user_usage_summary/{userId}`)

**Purpose**: Real-time usage statistics

**Structure**:
```json
{
  "total_energy_today": "number",
  "total_energy_week": "number",
  "total_energy_month": "number",
  "peak_usage_hour": "number",
  "average_daily_usage": "number",
  "cost_today": "number",
  "cost_week": "number",
  "cost_month": "number",
  "last_update": "ISO8601_timestamp",
  "devices_count": "number",
  "online_devices": "number",
  "savings_percentage": "number"
}
```

#### 3. Alerts (`energySmart/alerts/{userId}`)

**Purpose**: Real-time alert system

**Structure**:
```json
{
  "high_usage": "boolean",
  "last_triggered": "ISO8601_timestamp",
  "current_consumption": "number",
  "threshold": "number",
  "threshold_percentage": "number",
  "energy_threshold": "number",
  "threshold_alert_enabled": "boolean",
  "last_updated": "ISO8601_timestamp",
  "alert_history": [
    {
      "timestamp": "ISO8601_timestamp",
      "type": "threshold_alert|device_offline|system_notice",
      "message": "string",
      "consumption": "number (optional)",
      "threshold": "number (optional)",
      "deviceId": "string (optional)",
      "deviceName": "string (optional)"
    }
  ]
}
```

#### 4. System Status (`energySmart/system_status`)

**Purpose**: System-wide monitoring

**Structure**:
```json
{
  "total_devices": "number",
  "online_devices": "number",
  "offline_devices": "number",
  "total_users": "number",
  "active_alerts": "number",
  "system_uptime": "string",
  "last_maintenance": "ISO8601_timestamp",
  "next_maintenance": "ISO8601_timestamp",
  "version": "string",
  "last_updated": "ISO8601_timestamp"
}
```

#### 5. Energy Rates (`energySmart/energy_rates`)

**Purpose**: Real-time rate information

**Structure**:
```json
{
  "current": {
    "residential": "number",
    "commercial": "number",
    "peak_hours": {
      "start": "HH:MM",
      "end": "HH:MM",
      "rate": "number"
    },
    "off_peak_hours": {
      "start": "HH:MM",
      "end": "HH:MM",
      "rate": "number"
    },
    "last_updated": "ISO8601_timestamp"
  },
  "historical": {
    "YYYY-MM": {
      "residential": "number",
      "commercial": "number",
      "effective_date": "ISO8601_timestamp"
    }
  }
}
```

#### 6. Weather Data (`energySmart/weather_data`)

**Purpose**: Weather information for energy optimization

**Structure**:
```json
{
  "current": {
    "temperature": "number",
    "humidity": "number",
    "condition": "sunny|cloudy|rainy|partly_cloudy",
    "last_updated": "ISO8601_timestamp"
  },
  "forecast": [
    {
      "date": "YYYY-MM-DD",
      "high": "number",
      "low": "number",
      "condition": "string",
      "humidity": "number"
    }
  ]
}
```

## Security Rules

### Firestore Rules
- Users can only access their own data
- Admins have read access to all data
- Proper validation for data types and required fields
- Role-based access control

### Realtime Database Rules
- Authenticated users only
- Users can only access their own data
- Device data is readable by all authenticated users
- Admins have full access

## Data Synchronization

### Firestore → Realtime Database
- User goals → Alert thresholds
- Device configuration → Device control
- Usage logs → Usage summaries

### Realtime Database → Firestore
- Device status changes → Usage logs
- Alert triggers → Notifications
- Usage summaries → Analytics

## Performance Optimizations

### Firestore
- Composite indexes for complex queries
- Subcollections for data organization
- Batch operations for multiple writes
- Pagination for large datasets

### Realtime Database
- Shallow reads for specific data
- Listeners for real-time updates
- Offline persistence
- Data validation rules

## Monitoring and Analytics

### Key Metrics
- Device online/offline status
- Energy consumption trends
- User engagement
- System performance

### Alerts
- High energy usage
- Device offline
- System maintenance
- Security events

## Backup and Recovery

### Firestore
- Automatic daily backups
- Point-in-time recovery
- Cross-region replication

### Realtime Database
- Real-time data replication
- Offline data persistence
- Automatic failover

## Migration Strategy

### Phase 1: Setup
1. Deploy Firestore rules
2. Deploy Realtime Database rules
3. Import initial data

### Phase 2: Integration
1. Update service classes
2. Test data synchronization
3. Validate security rules

### Phase 3: Production
1. Deploy to production
2. Monitor performance
3. Optimize based on usage

## Testing

### Unit Tests
- Service class methods
- Data validation
- Error handling

### Integration Tests
- Database operations
- Real-time updates
- Security rules

### Load Tests
- Concurrent users
- Data volume
- Performance metrics

## Maintenance

### Regular Tasks
- Monitor database usage
- Update security rules
- Optimize queries
- Clean up old data

### Emergency Procedures
- Database failover
- Data recovery
- Security incidents
- Performance issues


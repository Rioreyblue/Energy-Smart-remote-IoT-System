# Settings Page - EnergySmart System

## Overview
The Settings page provides comprehensive configuration options for the EnergySmart energy management system. The page is organized into logical sections with clear visual hierarchy and follows the existing design system for consistency.

## Features

### 🔐 Account Section
- **Edit Profile**: Update name, email, mobile, and address
- **Change Password**: Reset password and security settings
- **User Type Display**: Shows selected user type (Household/Small Business) as read-only

### 🔔 Notifications Section
- **Push Notifications**: Toggle to enable/disable alerts and updates
- **Alert Threshold**: Set custom alert threshold (75%, 80%, 90%)
- **Quiet Hours**: Schedule time ranges to mute alerts

### ⚡ Energy Settings Section
- **Default Rate per kWh**: Save user's power provider rate
- **Threshold Settings**: Quick navigation to update energy goals
- **Auto-Sync Data**: Toggle automatic saving of meter readings

### 🎨 Appearance & Personalization Section
- **Theme Mode**: Light, dark, or system default
- **Accent Color**: Preset gradient or color palette options
- **Language Selection**: English, Filipino, etc.

### 🛡️ Privacy & Data Section
- **Manage Data**: Clear history such as meter readings and thresholds
- **Data Export**: Export usage history to PDF/CSV
- **Permissions**: Background updates and app data access controls

### 🔌 Integrations & Devices Section
- **IoT Device Management**: Add/remove smart plugs, sensors, relays
- **Cloud Sync**: Toggle Firestore/Realtime DB synchronization
- **Backup & Restore**: Local or cloud data backup options

### 🆘 Support & General Section
- **About App**: Version, developer info, terms of service
- **Feedback & Support**: Link to in-app chat system
- **Logout**: Sign-out functionality

## Technical Implementation

### File Structure
```
lib/pages/settings/
├── settings_page.dart          # Main Settings page UI
├── README.md                   # This documentation
└── (future components)

lib/services/
└── settings_service.dart       # Service layer for settings persistence
```

### Design System Integration
The Settings page inherits all design elements from the existing app:

- **Colors**: Uses `AppColor` constants (accentGreen, primary, surface, etc.)
- **Typography**: Uses `ResponsiveText` classes for consistent text styling
- **Spacing**: Uses `Insets` constants for consistent spacing
- **Icons**: Uses `Iconsax` icon library for consistency
- **Components**: Follows the same card-based layout pattern
- **Shadows**: Consistent card shadows and elevation
- **Border Radius**: 8px, 12px, and 16px radius for consistency

### State Management
- **Local State**: Uses `StatefulWidget` with local state management
- **Service Integration**: Integrates with `SettingsService` for persistence
- **Loading States**: Loading indicators for async operations
- **Real-time Updates**: Settings changes are immediately reflected in UI

### Settings Service
The `SettingsService` provides comprehensive settings management:

#### Core Methods
```dart
// Individual settings
Future<bool> saveSetting(String key, dynamic value)
T getSetting<T>(String key, T defaultValue)

// Bulk operations
Future<bool> saveSettings(Map<String, dynamic> settings)
Future<Map<String, dynamic>> loadSettings()

// Specific settings
Future<bool> setPushNotifications(bool enabled)
Future<bool> setAlertThreshold(double threshold)
Future<bool> setThemeMode(String mode)
Future<bool> setAccentColor(String color)
```

#### Settings Data Structure
```dart
Map<String, dynamic> settings = {
  'pushNotifications': true,
  'alertThreshold': 80.0,
  'quietHoursEnabled': false,
  'quietHoursStart': '22:00',
  'quietHoursEnd': '07:00',
  'defaultRate': 12.50,
  'autoSync': true,
  'themeMode': 'system',
  'accentColor': 'green',
  'language': 'english',
  'backgroundUpdates': true,
  'cloudSync': true,
};
```

### UI Components

#### Section Headers
- **Visual Hierarchy**: Clear section titles with icons
- **Color Coding**: Green accent color for section headers
- **Consistent Spacing**: Proper margins and padding

#### List Tiles
- **Icon Containers**: Colored background containers for icons
- **Title & Subtitle**: Clear hierarchy with proper typography
- **Trailing Icons**: Arrow indicators for navigation
- **Read-only Indicators**: Lock icons for non-editable items
- **Destructive Actions**: Red color for dangerous actions

#### Switch Tiles
- **Toggle Functionality**: Real-time toggle switches
- **Visual Feedback**: Immediate UI updates
- **Persistence**: Automatic saving to service layer

#### Dividers
- **Visual Separation**: Subtle dividers between items
- **Consistent Spacing**: Proper margins for visual balance

### Database Integration (Placeholders)
The implementation includes comprehensive placeholders for future Firestore integration:

#### Firestore Collections
```dart
// User settings collection
'user_settings' -> {
  'settings': {
    'pushNotifications': true,
    'alertThreshold': 80.0,
    // ... other settings
  }
}
```

#### Service Methods (Placeholders)
```dart
// TODO: Implement Firestore operations
// await FirebaseFirestore.instance
//     .collection('user_settings')
//     .doc('settings')
//     .set(settings, SetOptions(merge: true));
```

### Key Features Implementation

#### 1. Settings Persistence
```dart
Future<void> _updatePushNotifications(bool value) async {
  setState(() => _pushNotifications = value);
  await _settingsService.setPushNotifications(value);
}
```

#### 2. Loading States
```dart
Future<void> _loadSettings() async {
  setState(() => _isLoading = true);
  try {
    // Load settings from service
    await _settingsService.loadSettings();
    // Update UI state
  } finally {
    setState(() => _isLoading = false);
  }
}
```

#### 3. User Type Integration
```dart
// Load user type from GoalsService
final userType = await _goalsService.getUserType();
setState(() => _userType = userType);
```

## Future Enhancements

### Database Integration
1. **Firestore Setup**: Uncomment and implement Firestore operations
2. **Real-time Sync**: Implement real-time settings synchronization
3. **Offline Support**: Add offline data persistence
4. **User Authentication**: Integrate with existing auth system

### Advanced Features
1. **Profile Management**: Complete profile editing functionality
2. **Theme Customization**: Advanced theme and color customization
3. **Data Analytics**: Settings usage analytics
4. **Backup/Restore**: Complete backup and restore functionality
5. **Device Management**: IoT device integration and management

### UI/UX Improvements
1. **Dark Mode**: Full dark mode support
2. **Accessibility**: Screen reader support and accessibility features
3. **Animations**: Smooth transitions and micro-interactions
4. **Responsive Design**: Better tablet and desktop layouts
5. **Search**: Settings search functionality

## Usage

### Basic Usage
1. Navigate to the Settings page
2. Browse different sections
3. Toggle switches for immediate changes
4. Tap list items for detailed configuration
5. Changes are automatically saved

### Advanced Usage
1. Configure notification preferences
2. Set up quiet hours for alerts
3. Customize appearance and theme
4. Manage data and privacy settings
5. Configure device integrations

## Dependencies
- `flutter/material.dart` - UI components
- `iconsax/iconsax.dart` - Icon library
- `exercise_app/constants/constant.dart` - Design system constants
- `exercise_app/components/header.dart` - Header component
- `exercise_app/services/settings_service.dart` - Settings service
- `exercise_app/services/goals_service.dart` - Goals service

## Testing
The Settings page is designed for easy testing:
- All user interactions are handled through methods
- Service layer is abstracted for easy mocking
- State management is predictable and testable
- UI components are modular and testable

## Performance Considerations
- Efficient state management with minimal rebuilds
- Lazy loading of settings data
- Optimized list rendering for settings items
- Proper disposal of resources and controllers


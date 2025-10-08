# Goals Page - Energy Management System

## Overview
The Goals page provides comprehensive energy management features including energy threshold setting, meter reading input, and consumption tracking. This page is designed as a static UI that can easily transition to dynamic functionality with database integration.

## Features

### 1. Energy Threshold Setting
- **Target Price Input**: Users can set energy consumption targets in pesos (₱)
- **Alert Toggle**: Enable/disable 80% threshold alerts
- **Real-time Validation**: Input validation for threshold values
- **Save Functionality**: Persist threshold settings (with database integration placeholders)

### 2. Meter Reading Input
- **Rate per kWh**: Input field for electricity rate
- **Date Range Selection**: Start and end date pickers for reading period
- **Previous/Present Readings**: Input fields for meter readings
- **Calculate Button**: Compute energy consumption and estimated bill
- **Reset Button**: Clear all input fields

### 3. Calculation Results
- **Energy Consumption**: Display calculated kWh consumption
- **Estimated Bill**: Show calculated cost in pesos
- **Save Reading**: Persist meter reading data
- **Visual Feedback**: Color-coded results with icons

### 4. Reading History
- **Recent Readings**: Display last 5 meter readings
- **Consumption Details**: Show consumption, rate, and bill for each reading
- **Date Range**: Display reading period for each entry

## Technical Implementation

### File Structure
```
lib/pages/goals/
├── goals_page.dart          # Main Goals page UI
├── README.md               # This documentation
└── (future components)

lib/models/
└── goals_model.dart        # Data models for goals and meter readings

lib/services/
└── goals_service.dart      # Service layer for data operations
```

### Design System Integration
The Goals page inherits all design elements from the existing app:

- **Colors**: Uses `AppColor` constants (primary, accentGreen, etc.)
- **Typography**: Uses `ResponsiveText` classes for consistent text styling
- **Spacing**: Uses `Insets` constants for consistent spacing
- **Components**: Follows the same card-based layout pattern
- **Icons**: Uses `Iconsax` icon library for consistency

### State Management
- **Local State**: Uses `StatefulWidget` with local state management
- **Form Controllers**: TextEditingController for all input fields
- **Loading States**: Loading indicators for async operations
- **Validation**: Input validation with user feedback

### Database Integration (Placeholders)
The implementation includes comprehensive placeholders for future Firestore integration:

#### Models
- `GoalsModel`: Energy threshold and alert settings
- `MeterReadingModel`: Meter reading data with calculations
- `GoalsService`: Service layer for database operations

#### Service Methods (Placeholders)
```dart
// Energy threshold operations
Future<bool> saveEnergyThreshold({required double threshold, required bool alertEnabled})
Future<GoalsModel?> getEnergyThreshold()

// Meter reading operations  
Future<bool> saveMeterReading({...})
Future<List<MeterReadingModel>> getMeterReadingsHistory()

// Alert system
Future<void> sendThresholdAlert(BuildContext context, double currentConsumption)
```

### Key Features Implementation

#### 1. Energy Threshold Alert System
```dart
// Check if consumption exceeds 80% of threshold
Future<void> _checkThresholdAlert() async {
  if (_energyThreshold > 0) {
    final threshold80Percent = _energyThreshold * 0.8;
    if (_consumption >= threshold80Percent) {
      await _goalsService.sendThresholdAlert(context, _consumption);
    }
  }
}
```

#### 2. Consumption Calculation
```dart
void _calculateConsumption() {
  final previous = double.tryParse(_previousReadingController.text) ?? 0.0;
  final present = double.tryParse(_presentReadingController.text) ?? 0.0;
  final rate = double.tryParse(_rateController.text) ?? 0.0;

  if (previous >= 0 && present >= 0 && rate > 0 && present >= previous) {
    setState(() {
      _consumption = present - previous;
      _estimatedBill = _consumption * rate;
      _showResults = true;
    });
  }
}
```

#### 3. Data Persistence
```dart
// Save energy threshold
Future<void> _saveEnergyThreshold() async {
  final success = await _goalsService.saveEnergyThreshold(
    threshold: _energyThreshold,
    alertEnabled: _thresholdAlertEnabled,
  );
  // Handle success/failure with user feedback
}
```

## Future Enhancements

### Database Integration
1. **Firestore Setup**: Uncomment and implement Firestore operations in `GoalsService`
2. **User Authentication**: Integrate with existing auth system
3. **Real-time Updates**: Implement real-time data synchronization
4. **Offline Support**: Add offline data persistence

### Advanced Features
1. **Energy Efficiency Tips**: Generate tips based on consumption trends
2. **Consumption Analytics**: Advanced charts and insights
3. **Goal Tracking**: Visual progress indicators for energy goals
4. **Export Functionality**: Export reading history to CSV/PDF
5. **Notification System**: Push notifications for threshold alerts

### UI/UX Improvements
1. **Dark Mode**: Full dark mode support
2. **Accessibility**: Screen reader support and accessibility features
3. **Animations**: Smooth transitions and micro-interactions
4. **Responsive Design**: Better tablet and desktop layouts

## Usage

### Basic Usage
1. Navigate to the Goals page
2. Set energy threshold and enable alerts
3. Enter meter readings with date range
4. Calculate consumption and save results
5. View reading history

### Advanced Usage
1. Monitor consumption trends in history
2. Adjust threshold based on usage patterns
3. Use alerts to manage energy consumption
4. Track savings over time

## Dependencies
- `flutter/material.dart` - UI components
- `iconsax/iconsax.dart` - Icon library
- `exercise_app/constants/constant.dart` - Design system constants
- `exercise_app/components/header.dart` - Header component
- `exercise_app/services/goals_service.dart` - Service layer
- `exercise_app/models/goals_model.dart` - Data models

## Testing
The Goals page is designed for easy testing:
- All user interactions are handled through methods
- Service layer is abstracted for easy mocking
- State management is predictable and testable
- UI components are modular and testable

## Performance Considerations
- Lazy loading of reading history
- Efficient state management
- Minimal rebuilds with proper setState usage
- Optimized list rendering for history items


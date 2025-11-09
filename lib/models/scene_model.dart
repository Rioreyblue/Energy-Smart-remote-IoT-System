import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for customizable scenes and modes
class SceneModel {
  final String id;
  final String name;
  final String icon;
  final Map<String, DeviceState> deviceStates;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDefault;

  const SceneModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.deviceStates,
    this.createdAt,
    this.updatedAt,
    this.isDefault = false,
  });

  /// Create from Firestore document
  factory SceneModel.fromFirestore(String id, Map<String, dynamic> data) {
    final deviceStatesData =
        data['deviceStates'] as Map<String, dynamic>? ?? {};
    final deviceStates = deviceStatesData.map(
      (key, value) =>
          MapEntry(key, DeviceState.fromMap(Map<String, dynamic>.from(value))),
    );

    return SceneModel(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? 'Iconsax.home',
      deviceStates: deviceStates,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
      isDefault: data['isDefault'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon': icon,
      'deviceStates': deviceStates.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isDefault': isDefault,
    };
  }

  /// Create a copy with updated values
  SceneModel copyWith({
    String? id,
    String? name,
    String? icon,
    Map<String, DeviceState>? deviceStates,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return SceneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      deviceStates: deviceStates ?? this.deviceStates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() {
    return 'SceneModel(id: $id, name: $name, icon: $icon, deviceStates: $deviceStates, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneModel &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        icon.hashCode ^
        deviceStates.hashCode ^
        isDefault.hashCode;
  }
}

/// Model for device state within a scene
class DeviceState {
  final bool isOn;
  final double value; // For dimmable devices (0.0 to 1.0)

  const DeviceState({required this.isOn, this.value = 1.0});

  /// Create from map
  factory DeviceState.fromMap(Map<String, dynamic> data) {
    return DeviceState(
      isOn: data['isOn'] ?? false,
      value: (data['value'] ?? 1.0).toDouble(),
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {'isOn': isOn, 'value': value};
  }

  /// Create a copy with updated values
  DeviceState copyWith({bool? isOn, double? value}) {
    return DeviceState(isOn: isOn ?? this.isOn, value: value ?? this.value);
  }

  @override
  String toString() {
    return 'DeviceState(isOn: $isOn, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceState && other.isOn == isOn && other.value == value;
  }

  @override
  int get hashCode {
    return isOn.hashCode ^ value.hashCode;
  }
}

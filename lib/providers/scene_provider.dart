import 'package:flutter/material.dart';
import 'package:exercise_app/components/scene_modes.dart';

class SceneProvider extends ChangeNotifier {
  List<ScenePreset> _presets;

  SceneProvider(List<ScenePreset> initialPresets)
    : _presets = List.from(initialPresets);

  List<ScenePreset> get presets => List.unmodifiable(_presets);

  ScenePreset? getScenePresetByName(String name) {
    try {
      return _presets.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  void updateScenePreset(ScenePreset updated) {
    final idx = _presets.indexWhere((p) => p.name == updated.name);
    if (idx != -1) {
      _presets[idx] = updated;
      notifyListeners();
    }
  }

  void addScenePreset(ScenePreset preset) {
    _presets.add(preset);
    notifyListeners();
  }

  void removeScenePreset(String name) {
    _presets.removeWhere((p) => p.name == name);
    notifyListeners();
  }
}

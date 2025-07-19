import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:exercise_app/widgets/scene_modes.dart';
import 'package:exercise_app/providers/scene_provider.dart';
import 'package:exercise_app/widgets/app_snackbar.dart';
import 'package:exercise_app/constants/constant.dart';

class SceneEditPage extends StatefulWidget {
  final String sceneName;
  const SceneEditPage({required this.sceneName, super.key});

  @override
  State<SceneEditPage> createState() => _SceneEditPageState();
}

class _SceneEditPageState extends State<SceneEditPage> {
  late Map<String, bool> _switchStates;
  late ScenePreset _preset;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SceneProvider>(context, listen: false);
    final preset = provider.getScenePresetByName(widget.sceneName);
    if (preset == null) {
      _switchStates = {};
      _preset = ScenePreset(
        name: widget.sceneName,
        icon: Icons.help,
        deviceStates: {},
      );
    } else {
      _preset = preset;
      _switchStates = {
        for (final entry in preset.deviceStates.entries)
          entry.key: entry.value.isOn,
      };
    }
  }

  void _onSwitchChanged(String device, bool value) {
    setState(() {
      _switchStates[device] = value;
      _changed = true;
    });
  }

  void _saveChanges() {
    final provider = Provider.of<SceneProvider>(context, listen: false);
    final newPreset = ScenePreset(
      name: _preset.name,
      icon: _preset.icon,
      deviceStates: {
        for (final entry in _preset.deviceStates.entries)
          entry.key: entry.value.copyWith(
            isOn: _switchStates[entry.key] ?? entry.value.isOn,
          ),
      },
    );
    provider.updateScenePreset(newPreset);
    setState(() => _changed = false);
    AppSnackbar.show(
      context,
      "${_preset.name} preset updated",
      type: SnackbarType.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${_preset.name}'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure devices for this scene:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ..._preset.deviceStates.keys.map((device) {
              final isOn = _switchStates[device] ?? false;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        device,
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: isOn,
                      onChanged: (val) => _onSwitchChanged(device, val),
                      activeColor: AppColor.accentGreen,
                      trackColor: colorScheme.onSurface.withAlpha(
                        (0.1 * 255).toInt(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changed ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Insets.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

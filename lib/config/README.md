# OneSignal Configuration

This directory contains configuration for OneSignal push notifications.

## Configuration File

`onesignal_config.dart` contains:
- **App ID**: `741790af-bbf1-4480-9c92-18352b884ea3` (Energy Smart)
- **REST API Key**: Configured with fallback value for development

## Security Note

⚠️ **IMPORTANT**: The REST API key in `onesignal_config.dart` is currently set as a fallback for development. 

For production builds, it's recommended to:
1. Use `--dart-define` when building:
   ```bash
   flutter build apk --dart-define=ONESIGNAL_REST_API_KEY=your_production_key
   ```

2. Or remove the fallback and always require the environment variable

3. Consider adding `onesignal_config.dart` to `.gitignore` if it contains production keys

## Cloud Functions Configuration

The Cloud Functions also need the REST API key configured:

```bash
firebase functions:config:set onesignal.rest_api_key="m43csqdcaulf4m3xigbvnnujd"
firebase deploy --only functions
```

## Verification

After configuration, check the app logs on startup. You should see:
```
[NotificationService] Initializing OneSignal | App ID: 741790af... | REST API Key: ✓ Configured
```

If you see "✗ Missing", the REST API key is not properly configured.


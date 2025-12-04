# How to Get SHA-1 and SHA-256 Fingerprints for Google Sign-In

Google Sign-In error code 7 (NETWORK_ERROR) is often caused by missing SHA-1/SHA-256 fingerprints in Firebase Console.

## Method 1: Using Gradle (Recommended)

Run this command in the project root:

```bash
cd android
./gradlew signingReport
```

Look for the output under "Variant: debug" and copy:
- **SHA1**: The SHA-1 fingerprint
- **SHA-256**: The SHA-256 fingerprint

## Method 2: Using keytool (Manual)

### For Debug Keystore (Default):
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

On Windows:
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### For Release Keystore:
```bash
keytool -list -v -keystore path/to/your/keystore.jks -alias your-key-alias
```

## Add to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `capstonefinal593`
3. Go to **Project Settings** (gear icon)
4. Scroll down to **Your apps** section
5. Select your Android app: `com.example.exercise_app`
6. Click **Add fingerprint**
7. Paste your **SHA-1** fingerprint
8. Click **Add fingerprint** again and paste your **SHA-256** fingerprint
9. Download the updated `google-services.json` and replace the one in `android/app/`

## After Adding Fingerprints

1. Wait a few minutes for Firebase to process the changes
2. Rebuild your app: `flutter clean && flutter build apk`
3. Try Google Sign-In again

## Additional Troubleshooting

If the error persists:
- Ensure Google Play Services is updated on your device
- Check internet connection
- Verify the `serverClientId` in `auth_service.dart` matches your Web client ID in Firebase Console
- Make sure the package name matches exactly: `com.example.exercise_app`



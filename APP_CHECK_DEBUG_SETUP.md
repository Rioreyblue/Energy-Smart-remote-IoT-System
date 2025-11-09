# App Check Debug Token Setup Guide

## Problem
Firebase App Check is being throttled ("Too many attempts" error), preventing SMS verification from working. This occurs because Play Integrity API has rate limits during development.

## Solution
Use App Check debug mode for development to bypass throttling while maintaining security. Configure proper debug tokens in Firebase Console.

## Implementation Status

✅ **Code Changes Completed**

### Changes Made:
1. ✅ Updated `_initializeFirebase()` in `lib/main.dart` to use `AndroidProvider.debug` in debug mode
2. ✅ Added `kDebugMode` check with logging to show debug mode status
3. ✅ Added comprehensive logging for debug token retrieval
4. ✅ Added instructions in logs for finding debug token in Android Logcat
5. ✅ Fixed TextEditingController disposal issue in `verification_page.dart`
6. ✅ Added `mounted` checks to prevent widget disposal errors

## How to Find and Register Debug Token

### Step 1: Ensure You're Running in DEBUG Mode

**Important:** The debug provider only works in debug builds, not release builds.

- Use `flutter run` (not `flutter run --release`)
- Or click the debug button in your IDE (not the release/profile button)
- Check your logs for: `🔍 Debug mode check: kDebugMode = true`
  - If it shows `false`, you're in release mode - switch to debug!

### Step 2: Find the Debug Token in Android Logcat

**The debug token is automatically logged to Android Logcat by Firebase SDK, NOT in Flutter console logs.**

1. Open **Android Studio**
2. Go to **Logcat** tab (bottom panel)
3. Filter by: `AppCheck` or `Firebase`
4. Look for a line containing: `AppCheck debug token: <your-token-here>`
5. Copy the token (the string after the colon)

**Example Logcat Output:**
```
I/FirebaseAppCheck: AppCheck debug token: 12345678-1234-1234-1234-123456789012
```

**Note:** The token is a UUID format (e.g., `12345678-1234-1234-1234-123456789012`)

### Step 3: Register the Debug Token in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to: **Build** → **App Check** → **Apps**
4. Select your Android app
5. Click on the **"Debug tokens"** tab
6. Click **"Add debug token"**
7. Enter a descriptive name (e.g., "Development Device" or "Emulator")
8. Paste the debug token from Logcat
9. Click **"Save"**

### Step 4: Test SMS Verification

1. Restart your app (to ensure App Check uses the registered debug token)
2. Try SMS verification
3. The "Too many attempts" error should be resolved

## Expected Log Output

When running in debug mode, you should see in Flutter logs:
```
[Firebase] 🔍 Debug mode check: kDebugMode = true
[Firebase] 🔧 Activating Android Debug Provider...
[Firebase] ✅ App Check initialized (Android: Debug Mode)
[Firebase] 📱 IMPORTANT: Check Android Logcat for debug token!
[Firebase] 📱 Look for: "AppCheck debug token:" in logcat output
```

And in Android Logcat (filter by "AppCheck"):
```
I/FirebaseAppCheck: AppCheck debug token: <your-token-here>
```

## Troubleshooting

### Debug Token Not Appearing in Logcat

1. **Ensure you're in debug mode:**
   - Check logs for `kDebugMode = true`
   - If false, rebuild in debug mode

2. **Check App Check initialization:**
   - Look for `✅ App Check initialized (Android: Debug Mode)` in logs
   - If you see `PlayIntegrity` instead, you're in release mode

3. **Wait a few seconds:**
   - The debug token may take a few seconds to appear after app startup

4. **Clear filters in Logcat:**
   - Remove any filters and search for "AppCheck" manually

### Still Getting "Too many attempts" Error

1. **Verify debug token is registered:**
   - Check Firebase Console → App Check → Apps → Debug tokens
   - Ensure the token is listed and active

2. **Restart the app:**
   - App Check needs to be reinitialized after registering the token

3. **Check if you're using the correct token:**
   - Each device/emulator has a unique debug token
   - Register the token for each device you test on

4. **Verify App Check is using debug provider:**
   - Check logs for "Debug Mode" not "PlayIntegrity"

## Important Notes

- **Security:** Debug tokens should only be used in development. Never commit them to public repositories.
- **Device-specific:** Each device/emulator has its own debug token. Register tokens for each device you test on.
- **Production:** Production builds automatically use PlayIntegrity (no debug tokens needed).
- **Token Management:** If a token is compromised, revoke it immediately in Firebase Console.

## Files Modified

- `lib/main.dart` - Updated App Check initialization with debug mode support
- `lib/pages/auth/verification_page.dart` - Fixed TextEditingController disposal issue

## Next Steps

1. ✅ Run app in debug mode
2. ✅ Find debug token in Android Logcat
3. ⏳ Register debug token in Firebase Console
4. ⏳ Test SMS verification to confirm throttling is resolved



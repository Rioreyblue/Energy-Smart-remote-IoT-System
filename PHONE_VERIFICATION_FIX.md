# Phone Verification Issue Fix

## Problem
Phone verification SMS is not being received after sign-in and going to phone verification screen.

## Root Causes

### 1. **Firebase Test Phone Numbers Required**
Firebase requires you to configure test phone numbers in the Firebase Console during development. Without this, SMS messages won't be sent to avoid charges.

### 2. **SafetyNet/App Check Not Configured**
For production, you need to enable Firebase App Check to prevent abuse.

### 3. **Phone Number Format**
The phone number must be in international format (+63XXXXXXXXXX for Philippines).

## Solutions

### Solution 1: Configure Test Phone Numbers (Recommended for Development)

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to **Authentication** → **Sign-in method**
4. Scroll down to **Phone** and click it
5. Scroll down to **Phone numbers for testing**
6. Add test phone numbers with their verification codes:
   ```
   Phone Number: +639123456789
   Verification Code: 123456
   ```
7. Click **Add**
8. Now when you test with this number, it will automatically verify with the code `123456`

### Solution 2: Enable Firebase App Check (For Production)

1. Go to Firebase Console
2. Select your project
3. Go to **App Check**
4. Click **Register** for your Android app
5. Choose **Play Integrity** (recommended) or **SafetyNet**
6. Follow the setup instructions
7. Enable enforcement for Authentication

### Solution 3: Update Phone Number Formatting

The code already handles this correctly in `auth_service.dart`:

```dart
phoneNumber: '+63${phoneNumber.substring(1)}', // Convert to international format
```

This converts `09123456789` to `+639123456789`.

### Solution 4: Add Required Permissions to AndroidManifest.xml

Ensure these permissions are in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

### Solution 5: Verify SHA-1 and SHA-256 Keys

You mentioned you've added your SHA key, but verify both SHA-1 and SHA-256:

1. Get your SHA keys:
   ```bash
   cd android
   ./gradlew signingReport
   ```

2. Look for the debug SHA-1 and SHA-256 fingerprints

3. Add both to Firebase Console:
   - Go to Project Settings → Your App
   - Scroll to **SHA certificate fingerprints**
   - Add both SHA-1 and SHA-256

4. Download the updated `google-services.json`

5. Replace the file in `android/app/google-services.json`

### Solution 6: Enable Phone Authentication in Firebase Console

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable **Phone** as a sign-in provider
3. Save changes

### Solution 7: Test with Firebase Test Mode

For immediate testing without waiting for SMS:

1. Use the test phone numbers configured in Solution 1
2. The verification will work instantly without actual SMS

### Solution 8: Check Firebase Quotas

1. Go to Firebase Console → Authentication → Usage
2. Check if you've exceeded the free tier limits:
   - Free: 10,000 verifications/month
   - Paid: Unlimited

3. If exceeded, upgrade to Blaze plan

## Testing Checklist

- [ ] Test phone numbers configured in Firebase Console
- [ ] Phone authentication enabled in Firebase Console
- [ ] SHA-1 and SHA-256 keys added to Firebase
- [ ] google-services.json updated
- [ ] App rebuilt after updating google-services.json
- [ ] Tested with configured test phone number
- [ ] Internet permission granted
- [ ] App installed from the same signing key as SHA fingerprint

## Quick Test

Use this test phone number in your Firebase Console:

```
Phone: +639123456789
Code: 123456
```

Then in your app, enter:
```
09123456789
```

And use verification code: `123456`

## Production Deployment

Before going to production:

1. Enable App Check
2. Remove test phone numbers
3. Set up billing in Firebase (required for production phone auth)
4. Test with real phone numbers
5. Monitor usage in Firebase Console

## Common Errors and Fixes

### Error: "Invalid phone number"
**Fix:** Ensure number starts with +63 for Philippines

### Error: "This app is not authorized to use Firebase Authentication"
**Fix:** Verify SHA keys are correct and google-services.json is updated

### Error: "Network error"
**Fix:** Check internet permissions and connectivity

### Error: "Too many requests"
**Fix:** Wait a few minutes or use test phone numbers

## Updated Code

The `auth_service.dart` already has the correct implementation. No code changes needed.

If verification still doesn't work, you can add logging:

```dart
await _auth.verifyPhoneNumber(
  phoneNumber: '+63${phoneNumber.substring(1)}',
  timeout: const Duration(seconds: 60),
  verificationCompleted: (PhoneAuthCredential credential) async {
    print('✅ Auto verification completed');
    // Auto-verification completed
  },
  verificationFailed: (FirebaseAuthException e) {
    print('❌ Verification failed: ${e.code} - ${e.message}');
    throw _handleAuthError(e);
  },
  codeSent: (String verificationId, int? resendToken) {
    print('✅ Code sent! Verification ID: $verificationId');
    _verificationId = verificationId;
    _resendToken = resendToken;
  },
  codeAutoRetrievalTimeout: (String verificationId) {
    print('⏱️ Auto retrieval timeout: $verificationId');
    _verificationId = verificationId;
  },
);
```

## Support

If the issue persists after following all steps:

1. Check Firebase Console logs for detailed error messages
2. Enable debug logging in your app
3. Test with multiple different phone numbers
4. Verify your Firebase project is active and not suspended

## References

- [Firebase Phone Authentication Documentation](https://firebase.google.com/docs/auth/android/phone-auth)
- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [Common Phone Auth Issues](https://firebase.google.com/docs/auth/android/phone-auth#phone-auth-common-issues)



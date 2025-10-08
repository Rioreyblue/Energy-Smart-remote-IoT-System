# Quick Start Guide - Dynamic Energy Smart App

## 🚀 Get Started in 5 Minutes

### Step 1: Install Dependencies
```bash
cd "C:\Users\Rey Francisco\Desktop\flutter\revision_apk\energy_smart.apk"
flutter pub get
```

### Step 2: Firebase Console Setup (IMPORTANT!)

#### A. Enable Phone Authentication
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Click **Phone** and enable it
5. Save changes

#### B. Add Test Phone Number (For Testing)
1. In Phone settings, scroll to **Phone numbers for testing**
2. Click **Add phone number**
3. Enter:
   - Phone: `+639123456789`
   - Code: `123456`
4. Click **Add**

#### C. Verify SHA Keys
1. Get your SHA fingerprints:
   ```bash
   cd android
   ./gradlew signingReport
   ```
2. Copy both SHA-1 and SHA-256
3. Go to Firebase Console → Project Settings → Your Android App
4. Add both fingerprints under **SHA certificate fingerprints**
5. Download updated `google-services.json`
6. Replace `android/app/google-services.json` with the new file

### Step 3: Initialize Default Data

The app will automatically:
- Create default appliances on first launch
- Initialize energy metadata for the current month
- Set up database structure

### Step 4: Run the App
```bash
flutter run
```

## 📱 Testing Phone Verification

### Quick Test (No SMS Required)
1. Sign up or log in
2. When prompted for phone verification, enter: `09123456789`
3. Enter code: `123456`
4. ✅ Verification complete!

### Real Phone Test (After Enabling Billing)
1. Use your actual phone number
2. Wait for SMS
3. Enter the received code

## 🎮 Using the App

### Quick Controls
- Toggle switches to turn appliances ON/OFF
- Usage timer starts automatically when ON
- Cost calculated based on watts and duration
- Data syncs to Firebase Realtime Database

### Energy Overview Card
- **Current Usage**: Sum of all active appliances (kWh)
- **Conversion Value**: Real-time cost in ₱
- **Today's Cost**: Accumulated cost for the day
- **Target Cost**: Your monthly budget (set in goals)
- **This Month**: Total monthly consumption

### Scene Modes
- Select a scene to apply pre-configured settings
- All appliances update in the database
- Changes reflect instantly

## 🔧 Common Issues & Fixes

### Issue: "No appliances found"
**Fix**: The app auto-creates 4 default appliances on first launch. If missing:
```dart
// Manually trigger initialization
await ApplianceService().initializeDefaultAppliances();
```

### Issue: Phone verification SMS not received
**Solutions**:
1. Use test phone number (see Step 2B)
2. Check Firebase Console → Usage for quota limits
3. Verify SHA keys are correct
4. Ensure phone authentication is enabled
5. See `PHONE_VERIFICATION_FIX.md` for detailed guide

### Issue: Energy overview shows zeros
**Cause**: No usage data yet
**Fix**: Turn ON some appliances and wait a few seconds

### Issue: Data not syncing
**Fix**: 
1. Check internet connection
2. Verify Firebase rules allow read/write
3. Check Firebase Console for authentication

## 📊 Database Structure Quick Reference

### Realtime Database
```
users/{uid}/appliances/{applianceUid}
  ├── icon: "Iconsax.lamp"
  ├── isOn: false
  ├── kWh: 0.0
  ├── name: "Living Room"
  ├── startTime: ""
  ├── totalUsageTime: 0
  └── watts: 80
```

### Firestore
```
users/{uid}/energy_metadata/{monthId}
  ├── totalConsumption: 0.0
  ├── totalCost: 0.0
  ├── targetCost: 0.0
  ├── timestamp: DateTime
  └── deviceLogs/{deviceId}
      ├── usageDuration: 0
      ├── kWhUsed: 0.0
      ├── cost: 0.0
      └── updatedAt: DateTime
```

## 🎯 Key Features to Test

### 1. Appliance Control
- [ ] Toggle appliance ON → timer starts, startTime recorded
- [ ] Toggle appliance OFF → usage calculated, kWh updated
- [ ] Check Realtime DB for instant updates
- [ ] Verify cost calculation

### 2. Energy Overview
- [ ] Current usage updates in real-time
- [ ] Cost conversion displays correctly
- [ ] Monthly totals accumulate
- [ ] Data persists after app restart

### 3. Monthly Reset
- [ ] Change device date to next month
- [ ] Launch app
- [ ] Verify all usage fields reset to 0
- [ ] Check new month document in Firestore

### 4. Scene Modes
- [ ] Select "Away Mode"
- [ ] All appliances turn OFF in database
- [ ] Select "Home Mode"
- [ ] Appliances turn ON as configured

## 💡 Pro Tips

### Customize Default Appliances
Edit `lib/services/appliance_service.dart`:
```dart
// Around line 184
final appliances = [
  ApplianceModel(
    uid: 'appliance_1',
    icon: 'Iconsax.lamp_1',
    name: 'Your Custom Name',
    watts: 100, // Change wattage
    // ...
  ),
];
```

### Change Default Rate per kWh
Edit `lib/services/energy_overview_service.dart`:
```dart
// Line 24
static const double _defaultRatePerKwh = 12.0; // Change to your rate
```

### Add New Appliances via Code
```dart
final controller = context.read<HomeController>();
await controller.addAppliance(
  ApplianceModel(
    uid: 'appliance_5',
    icon: 'Iconsax.monitor',
    isOn: false,
    kWh: 0.0,
    name: 'TV',
    startTime: '',
    totalUsageTime: 0,
    watts: 150,
  ),
);
```

## 📝 Monitoring & Debugging

### Firebase Console
1. **Realtime Database**: See live appliance states
2. **Firestore**: View monthly energy metadata
3. **Authentication**: Check user sign-ins
4. **Usage**: Monitor API calls and quotas

### App Logs
Look for these messages:
```
✅ Auto verification completed
✅ Code sent! Verification ID: xxx
⏱️ Auto retrieval timeout: xxx
❌ Verification failed: xxx
```

## 🎓 Learning Resources

- `IMPLEMENTATION_SUMMARY.md` - Complete technical overview
- `PHONE_VERIFICATION_FIX.md` - Phone auth troubleshooting
- `DATABASE_STRUCTURE.md` - Database schema details
- `AUTHENTICATION_README.md` - Auth flow documentation

## 🆘 Need Help?

1. Check the documentation files above
2. Review Firebase Console logs
3. Check app logs for error messages
4. Verify all setup steps completed

## ✅ Deployment Checklist

Before going to production:
- [ ] Enable Firebase App Check
- [ ] Remove test phone numbers
- [ ] Upgrade to Blaze plan (required for phone auth production)
- [ ] Set up proper Firebase security rules
- [ ] Test with real phone numbers
- [ ] Configure proper rate limits
- [ ] Add analytics tracking
- [ ] Set up crash reporting

## 🎉 You're All Set!

Your Energy Smart app now has:
- ✅ Real-time appliance control
- ✅ Automatic usage tracking
- ✅ Cost calculations
- ✅ Monthly resets
- ✅ Database synchronization
- ✅ Phone authentication

Happy coding! 🚀



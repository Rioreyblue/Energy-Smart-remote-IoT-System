# Energy Smart – Remote IoT System

A mobile application and IoT platform built with **Flutter**, **Dart**, and custom **IoT Telemetry Protocols** for real-time remote energy monitoring, power analytics, and smart device management.

---

## Features

* 📊 Real-Time Dashboard – Monitor current load, voltage, and live power draw in real time
* 📈 Usage Trends – View daily, weekly, and monthly consumption breakdowns
* 💰 Cost Estimation – Calculate estimated electricity billing based on active utility rates
* 🎛️ Remote Control – Toggle connected appliances and circuit relays remotely
* 🚨 Alerts & Notifications – Automated push notifications for power spikes or threshold breaches
* 🧩 Modular Architecture – Custom reusable Flutter widgets optimized for low memory overhead
* ⚡ Decoupled Navigation – Navigation shell pattern prevents recursive rendering issues

---

## Tech Stack

| Technology | Purpose |
| :--- | :--- |
| Flutter (3.x+) | Cross-platform mobile framework |
| Dart | Programming language |
| Android / iOS | Target deployment platforms |
| IoT Relays / Sensors | Remote hardware telemetry |

---

## Prerequisites

| Tool | Version |
| :--- | :--- |
| Flutter SDK | 3.x + |
| Dart | 3.x + |
| Android Studio / VS Code | Latest |

> ⚠️ **Important Environment Setup:**
> Before attempting to run this application, ensure that **Android Studio** (or your preferred IDE) is fully installed and configured. 
> 
> Verify that all required dependencies, Android SDK components, licenses, and virtual devices (AVD) pass system checks by running:
> ```bash
> flutter doctor
> ```
> Fix any missing checks (such as accepting Android licenses via `flutter doctor --android-licenses`) until all core items display a checkmark (`[✓]`).

---

## Setup Instructions

### 1. Clone the repository

```bash
git clone [https://github.com/Rioreyblue/Energy-Smart-remote-IoT-System.git](https://github.com/Rioreyblue/Energy-Smart-remote-IoT-System.git)

### 2. Install dependencies

Navigate to the project directory and fetch packages:

```bash
cd Energy-Smart-remote-IoT-System
flutter pub get

```

### 3. Launch the application

Run on a connected physical device or emulator:

```bash
flutter run

```

> 💡 Make sure your target device or emulator is running before executing `flutter run`.

---

## Project Structure

```text
Energy-Smart-remote-IoT-System/
├── assets/                         # Static assets (images, icons, fonts)
├── lib/
│   ├── components/                 # Core UI building blocks
│   ├── constants/                  # Colors, dimensions, and app constants
│   ├── controllers/                # Business logic and controller states
│   ├── models/                     # Data schemas and telemetry models
│   ├── pages/                      # Screen views and application pages
│   ├── providers/                  # State management providers
│   ├── services/                   # API calls, Firebase, and IoT communication
│   ├── utils/                      # Helper functions and utilities
│   ├── widgets/                    # Reusable custom widgets
│   ├── debug_auth_test.dart        # Authentication testing utility
│   ├── debug_verification_test.dart# Verification debugging utility
│   ├── firebase_options.dart       # Firebase environment setup configuration
│   ├── home_screen.dart            # Main landing home screen layout
│   └── main.dart                   # Application entry point
├── test/                           # Unit and integration test suites
└── pubspec.yaml                    # Project configuration and dependency tree

```

---


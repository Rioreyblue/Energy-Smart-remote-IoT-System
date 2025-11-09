#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <time.h>

// =================== CONFIGURATION ===================
#define WIFI_SSID "."
#define WIFI_PASSWORD "00017284"

#define API_KEY "AIzaSyBsefGmSWNetHfI6AbADBux1GAD0ZIq1-A"
#define DATABASE_URL "https://capstonefinal593-default-rtdb.asia-southeast1.firebasedatabase.app/"

#define USER_ID "AgG04u8g1rdajV78WyJEryhEiE32"
#define APPLIANCE_BASE "users/" USER_ID "/appliances/"

// Relay pins
const int relayPins[4] = {4, 16, 17, 5};

// Voltage and current sensor pins
const int voltagePins[4] = {32, 25, 27, 12};
const int currentPins[4] = {33, 26, 14, 13};

// Appliance IDs matching Flutter app structure
const char* applianceIds[4] = {
  "appliances_001",
  "appliances_002",
  "appliances_003",
  "appliances_004"
};

// Firebase paths for relay control (isOn state)
String relayPaths[4];

// Firebase paths for power/sensor data updates
String powerPaths[4];

// Sensor constants
#define ADC_RESOLUTION 4095.0
#define ADC_REFERENCE 3.3
#define ZMPT_SENSITIVITY 0.020   // fine-tune per your ZMPT calibration
#define ACS_SENSITIVITY 0.100    // for ACS712 20A module
#define NOMINAL_VOLTAGE 230.0

#define SAMPLES 100
#define SENSOR_READ_INTERVAL 1000
#define FIREBASE_UPDATE_INTERVAL 5000
#define POLL_RELAY_INTERVAL 1000

// Firebase objects
FirebaseData fbdo;
FirebaseData streams[4];
FirebaseAuth auth;
FirebaseConfig config;

// State variables
bool relayStates[4] = {false, false, false, false};
bool lastRelayStates[4] = {false, false, false, false};

float voltageRMS[4] = {0};
float currentRMS[4] = {0};
float powerWatt[4] = {0};
float energykWh[4] = {0};

// Timers
unsigned long lastSensorRead = 0;
unsigned long lastFirebaseUpdate = 0;
unsigned long lastPoll = 0;

// Function declarations
void setupWiFi();
void setupFirebase();
void initializePaths();
void handleRelayStream(int index, FirebaseStream data);
void streamCallback0(FirebaseStream data);
void streamCallback1(FirebaseStream data);
void streamCallback2(FirebaseStream data);
void streamCallback3(FirebaseStream data);
void streamTimeoutCallback(bool timeout);
float readVoltage(int pin);
float readCurrent(int pin);
void updateSensorValues();
void updateFirebase();
void pollRelayStates();
String getISO8601Timestamp();

void setup() {
  Serial.begin(115200);

  for (int i = 0; i < 4; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], LOW);
  }

  analogReadResolution(12);
  
  // Initialize Firebase paths
  initializePaths();
  
  setupWiFi();
  setupFirebase();
}

void loop() {
  unsigned long now = millis();

  if (now - lastSensorRead >= SENSOR_READ_INTERVAL) {
    lastSensorRead = now;
    updateSensorValues();
  }

  if (now - lastFirebaseUpdate >= FIREBASE_UPDATE_INTERVAL) {
    lastFirebaseUpdate = now;
    updateFirebase();
  }

  if (now - lastPoll >= POLL_RELAY_INTERVAL) {
    lastPoll = now;
    pollRelayStates();
  }

  if (Firebase.ready()) {
    for (int i = 0; i < 4; i++) {
      Firebase.RTDB.readStream(&streams[i]);
    }
  }

  delay(10);
}

// =================== SETUP FUNCTIONS ===================
void initializePaths() {
  for (int i = 0; i < 4; i++) {
    // Relay paths: users/{USER_ID}/appliances/{applianceId}/isOn
    relayPaths[i] = String(APPLIANCE_BASE) + String(applianceIds[i]) + "/isOn";
    
    // Power paths: users/{USER_ID}/appliances/{applianceId}
    powerPaths[i] = String(APPLIANCE_BASE) + String(applianceIds[i]);
  }
  
  Serial.println("✅ Paths initialized:");
  for (int i = 0; i < 4; i++) {
    Serial.printf("  Relay %d: %s\n", i + 1, relayPaths[i].c_str());
    Serial.printf("  Power %d: %s\n", i + 1, powerPaths[i].c_str());
  }
}

void setupWiFi() {
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 10000) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ Wi-Fi Connected");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n❌ Wi-Fi Connection Failed!");
  }
}

void setupFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.timeout.serverResponse = 10000;

  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("✅ Firebase anonymous sign-in successful");
  } else {
    Serial.printf("❌ Firebase sign-up failed: %s\n", config.signer.signupError.message.c_str());
    return;
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Initialize streams for each appliance's isOn state
  Firebase.RTDB.beginStream(&streams[0], relayPaths[0].c_str());
  Firebase.RTDB.beginStream(&streams[1], relayPaths[1].c_str());
  Firebase.RTDB.beginStream(&streams[2], relayPaths[2].c_str());
  Firebase.RTDB.beginStream(&streams[3], relayPaths[3].c_str());

  Firebase.RTDB.setStreamCallback(&streams[0], streamCallback0, streamTimeoutCallback);
  Firebase.RTDB.setStreamCallback(&streams[1], streamCallback1, streamTimeoutCallback);
  Firebase.RTDB.setStreamCallback(&streams[2], streamCallback2, streamTimeoutCallback);
  Firebase.RTDB.setStreamCallback(&streams[3], streamCallback3, streamTimeoutCallback);

  // Initialize relay states from Firebase
  for (int i = 0; i < 4; i++) {
    if (Firebase.RTDB.getBool(&fbdo, relayPaths[i].c_str())) {
      relayStates[i] = fbdo.boolData();
      lastRelayStates[i] = relayStates[i];
      digitalWrite(relayPins[i], relayStates[i] ? HIGH : LOW);
      Serial.printf("Relay %d (%s) Initial: %s\n", i + 1, applianceIds[i], relayStates[i] ? "ON" : "OFF");
    }
  }
}

// =================== STREAM CALLBACKS ===================
void handleRelayStream(int index, FirebaseStream data) {
  if (data.dataType() == "boolean") {
    relayStates[index] = data.boolData();
    lastRelayStates[index] = relayStates[index];
    digitalWrite(relayPins[index], relayStates[index] ? HIGH : LOW);
    Serial.printf("Stream Update → Relay %d (%s): %s\n", index + 1, applianceIds[index], relayStates[index] ? "ON" : "OFF");
  }
}

void streamCallback0(FirebaseStream data) { handleRelayStream(0, data); }
void streamCallback1(FirebaseStream data) { handleRelayStream(1, data); }
void streamCallback2(FirebaseStream data) { handleRelayStream(2, data); }
void streamCallback3(FirebaseStream data) { handleRelayStream(3, data); }

void streamTimeoutCallback(bool timeout) {
  if (timeout) Serial.println("⚠️ Stream timeout, reconnecting...");
}

// =================== SENSOR FUNCTIONS ===================
float readVoltage(int pin) {
  float sumSq = 0;
  for (int i = 0; i < SAMPLES; i++) {
    float raw = analogRead(pin);
    float voltage = (raw / ADC_RESOLUTION) * ADC_REFERENCE;
    float acVoltage = voltage - (ADC_REFERENCE / 2);
    sumSq += acVoltage * acVoltage;
  }
  float rms = sqrt(sumSq / SAMPLES) / ZMPT_SENSITIVITY;
  return rms;
}

float readCurrent(int pin) {
  float sumSq = 0;
  for (int i = 0; i < SAMPLES; i++) {
    int raw = analogRead(pin);
    float voltage = (raw * ADC_REFERENCE) / ADC_RESOLUTION;
    float current = (voltage - (ADC_REFERENCE / 2)) / ACS_SENSITIVITY;
    sumSq += current * current;
    delayMicroseconds(200);
  }
  float rms = sqrt(sumSq / SAMPLES);
  return rms < 0.05 ? 0.0 : rms;
}

// =================== TIMESTAMP FUNCTION ===================
String getISO8601Timestamp() {
  // Get current time (you may need to configure NTP for accurate time)
  // For now, using a simple timestamp format
  // Format: YYYY-MM-DDTHH:MM:SSZ
  // Note: This is a simplified version. For production, use NTP to get accurate time
  
  unsigned long now = millis();
  unsigned long seconds = now / 1000;
  unsigned long minutes = seconds / 60;
  unsigned long hours = minutes / 60;
  unsigned long days = hours / 24;
  
  // Simple timestamp (approximate, starts from 2024-01-01)
  unsigned long year = 2024;
  unsigned long month = 1;
  unsigned long day = 1 + (days % 28); // Simplified day calculation
  unsigned long hour = hours % 24;
  unsigned long minute = minutes % 60;
  unsigned long second = seconds % 60;
  
  char timestamp[25];
  snprintf(timestamp, sizeof(timestamp), "%04lu-%02lu-%02luT%02lu:%02lu:%02luZ",
           year, month, day, hour, minute, second);
  
  return String(timestamp);
}

// =================== LOGIC ===================
void pollRelayStates() {
  for (int i = 0; i < 4; i++) {
    if (Firebase.RTDB.getBool(&fbdo, relayPaths[i].c_str())) {
      bool newState = fbdo.boolData();
      if (newState != lastRelayStates[i]) {
        relayStates[i] = newState;
        lastRelayStates[i] = newState;
        digitalWrite(relayPins[i], newState ? HIGH : LOW);
        Serial.printf("Polled → Relay %d (%s) Changed: %s\n", i + 1, applianceIds[i], newState ? "ON" : "OFF");
      }
    }
  }
}

void updateSensorValues() {
  for (int i = 0; i < 4; i++) {
    if (relayStates[i]) {
      voltageRMS[i] = readVoltage(voltagePins[i]);
      currentRMS[i] = readCurrent(currentPins[i]);
      powerWatt[i] = voltageRMS[i] * currentRMS[i];
      energykWh[i] += (powerWatt[i] * (SENSOR_READ_INTERVAL / 1000.0)) / 3600000.0;
    } else {
      voltageRMS[i] = currentRMS[i] = powerWatt[i] = 0;
    }
  }

  Serial.println("--------------------------------------------------");
  for (int i = 0; i < 4; i++) {
    Serial.printf("Appliance %d (%s) | V: %.2f V | I: %.2f A | P: %.2f W | E: %.6f kWh | State: %s\n",
                  i + 1, applianceIds[i], voltageRMS[i], currentRMS[i], powerWatt[i], energykWh[i],
                  relayStates[i] ? "ON" : "OFF");
  }
}

void updateFirebase() {
  if (!Firebase.ready()) return;

  String timestamp = getISO8601Timestamp();

  for (int i = 0; i < 4; i++) {
    FirebaseJson json;
    
    // Update all fields matching Flutter app structure
    json.set("voltage", voltageRMS[i]);
    json.set("current", currentRMS[i]);
    json.set("watts", (int)round(powerWatt[i]));  // Flutter expects int for watts
    json.set("kwh", energykWh[i]);                // Changed from energy_kWh to kwh
    json.set("isOn", relayStates[i]);
    json.set("lastUpdated", timestamp);           // Added ISO8601 timestamp

    // Update the appliance node with all sensor data
    if (!Firebase.RTDB.updateNode(&fbdo, powerPaths[i].c_str(), &json)) {
      Serial.printf("❌ Firebase update failed for appliance %d (%s): %s\n", 
                    i + 1, applianceIds[i], fbdo.errorReason().c_str());
    } else {
      Serial.printf("✅ Firebase updated for appliance %d (%s)\n", i + 1, applianceIds[i]);
    }
  }
}


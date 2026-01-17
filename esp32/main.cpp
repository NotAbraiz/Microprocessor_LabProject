#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <time.h>
#include <Adafruit_Fingerprint.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>
#include <vector>


//FingerprintId vector
std::vector<int> nextAvailableId;


// ----- WiFi Configuration -----
#define WIFI_SSID     "PTCL Fiber 92 - 4G"
#define WIFI_PASSWORD "h92s4p41"

// ----- Firebase Configuration -----
#define API_KEY       "AIzaSyA-hg_JxM6GqlDGw02X2GcJewvNqZ0eeKA"
#define DATABASE_URL  "https://biomark299-default-rtdb.asia-southeast1.firebasedatabase.app/"

// ----- Firebase Objects -----
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ----- Fingerprint, OLED & Buzzer Configuration -----
#define FINGERPRINT_RX 16
#define FINGERPRINT_TX 17
#define OLED_SDA 21
#define OLED_SCL 22
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define BUZZER_PIN 4

HardwareSerial fingerSerial(2);           // Use UART2 for fingerprint
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&fingerSerial);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire);

// ----- Global Constants -----
#define Heartbeat_delay 20000 //10 sec

// Global Variables
#define BEEP_SUCCESS       1
#define BEEP_FAILURE       2
#define BEEP_INTERMEDIATE  3
#define BEEP_WAITING       4
#define BEEP_PROMPT        5
#define BEEP_READY         6

String enrollName;
String enrollRollNo;
String cmdResult;

unsigned long lastHeartbeatTime = 0;
unsigned long lastCommandCheck = 0;
#define CommandCheckDelay 500 
//Enrollment
enum EnrollmentState {
    ENROLL_IDLE,
    ENROLL_SCAN1,
    ENROLL_SCAN2,
    ENROLL_CREATE,
    ENROLL_STORE
};

EnrollmentState enrollState = ENROLL_IDLE;
int enrollFID = 0;
bool enrollActive = false;

//Deletion
enum DeleteState {
    DELETE_IDLE,
    DELETE_VALIDATE,
    DELETE_PROCESS
};

DeleteState deleteState = DELETE_IDLE;
int deleteFID = -1;
bool deleteActive = false;

//Attendance
enum AttendanceState {
    ATT_IDLE,
    ATT_WAIT_FINGER,
    ATT_CAPTURE_IMAGE,
    ATT_CREATE_TEMPLATE,
    ATT_VERIFY_STATUS
};

AttendanceState attState = ATT_IDLE;
bool attActive = false;
int attStudentIndex = 0;
String attClassName;
time_t attStartTime = 0;


// ----- Function Prototypes -----
void buzzerBeep(int type);
void connectWiFi();
void syncTime();
void initFirebase();
void initFingerprint();
void buildNextAvailableId();
void initOLED();
void oledWrite(int count, bool clearDisplay = true, ...);
void sendHeartbeat();
void initFirebaseDB();
void checkCommand();
void configureCommandMode(const String &cmdType);
void resetCommandStatus();
void Enroll(std::vector<int> &nextAvailableId);
bool validateEnrollData(String &name, String &rollNo);
void showEnrollmentSuccess(const String &name, const String &rollNo);
void gotoEnrollmentFailure();
void Delete();
void Attendance();
void showAttendanceSuccess(const String &name, const String &rollNo);
bool validateAttendanceData(String &className);
void clearAS608Storage();

// -------------------- Setup --------------------
void setup() {
  Serial.begin(115200);
  delay(1000);


  // Initialize OLED first
  initOLED();
  oledWrite(1, true, "OLED Initialized");
  buzzerBeep(BEEP_SUCCESS);

  // Initialize Fingerprint sensor
  initFingerprint();
  //clearAS608Storage();

  buildNextAvailableId();

  


  // Connect to WiFi
  oledWrite(1, true,"Connecting WiFi");
  buzzerBeep(BEEP_WAITING);
  connectWiFi();
  oledWrite(1, true,"WiFi Connected");
  buzzerBeep(BEEP_SUCCESS);
  delay(1000);

  // Sync time
  oledWrite(1, true,"Syncing Time");
  buzzerBeep(BEEP_WAITING);
  syncTime();
  oledWrite(1, true,"Time Synced");
  buzzerBeep(BEEP_SUCCESS);
  delay(1000);

  // Initialize Firebase
  oledWrite(1, true,"Initializing Firebase");
  buzzerBeep(BEEP_WAITING);
  initFirebase();
  oledWrite(1, true,"Firebase Initialized");
  buzzerBeep(BEEP_SUCCESS);
  delay(1000);

  // Initialize Firebase Database
  initFirebaseDB();

  oledWrite(2, true,"System Ready\n","Waiting for Command...");
  buzzerBeep(BEEP_READY);

}

// -------------------- Loop --------------------
void loop() {
    //Serial.println("Main loop is busy doing other work...");

    unsigned long currentMillis = millis();

    // Heartbeat logic
    if (currentMillis - lastHeartbeatTime >= Heartbeat_delay) {
        lastHeartbeatTime = currentMillis;
        sendHeartbeat();
    }

    // Command check logic
    if (currentMillis - lastCommandCheck >= CommandCheckDelay) {
        lastCommandCheck = currentMillis;
        checkCommand();
    }

    // Non-blocking enrollment
    Enroll(nextAvailableId);

    // Non-blocking deletion
    Delete();
    Attendance();

    delay(50); // small delay for loop
}

// -------------------- Functions --------------------

void buzzerBeep(int type) {

  switch (type) {

    case BEEP_SUCCESS:
      tone(BUZZER_PIN, 1800);
      delay(150);
      noTone(BUZZER_PIN);
      break;

    case BEEP_FAILURE:
      tone(BUZZER_PIN, 600);
      delay(700);
      noTone(BUZZER_PIN);
      break;

    case BEEP_INTERMEDIATE:
      tone(BUZZER_PIN, 1200);
      delay(120);
      noTone(BUZZER_PIN);
      delay(50);
      tone(BUZZER_PIN, 1200);
      delay(120);
      noTone(BUZZER_PIN);
      break;
      
    case BEEP_WAITING:
      tone(BUZZER_PIN, 800);
      delay(80);
      noTone(BUZZER_PIN);
      delay(100);
      tone(BUZZER_PIN, 800);
      delay(80);
      noTone(BUZZER_PIN);
      break;
      
    case BEEP_PROMPT:
      tone(BUZZER_PIN, 1000);
      delay(100);
      noTone(BUZZER_PIN);
      delay(50);
      tone(BUZZER_PIN, 1500);
      delay(80);
      noTone(BUZZER_PIN);
      break;
      
    case BEEP_READY:
      tone(BUZZER_PIN, 1500);
      delay(100);
      noTone(BUZZER_PIN);
      delay(50);
      tone(BUZZER_PIN, 1800);
      delay(100);
      noTone(BUZZER_PIN);
      delay(50);
      tone(BUZZER_PIN, 2000);
      delay(150);
      noTone(BUZZER_PIN);
      break;
  }
}
// Connect to WiFi
void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi connected");
  buzzerBeep(BEEP_SUCCESS);
}

// Sync NTP Time
void syncTime() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now;
  Serial.print("Syncing time");
  do {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  } while (now < 100000);
  Serial.println("\n✅ Time synced");
  buzzerBeep(BEEP_SUCCESS);
}

// Initialize Firebase
void initFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = "abraizabdurrehman@gmail.com";
  auth.user.password = "esp32password";

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  delay(2000); // Allow Firebase to stabilize
  Serial.println("\n Firebase Initialized");
  buzzerBeep(BEEP_SUCCESS);
}

// Initialize OLED
void initOLED() {
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("❌ SSD1306 allocation failed");
    while (true); // Stop if OLED fails
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0,0);
  display.display();
  buzzerBeep(BEEP_SUCCESS);
}

// OLED write function: clears old content, prints new concatenated message
void oledWrite(int count, bool clearDisplay, ...) {
  display.setTextSize(1);
  if (clearDisplay)
  display.clearDisplay();

  int cursorX = 0;
  int cursorY = 0;
  const int lineHeight = 8;  // for textSize = 1

  display.setCursor(cursorX, cursorY);

  va_list args;
  va_start(args, clearDisplay);

  for (int i = 0; i < count; i++) {
    const char* text = va_arg(args, const char*);

    while (*text) {
      if (*text == '\n') {
        cursorY += lineHeight;
        cursorX = 0;
        display.setCursor(cursorX, cursorY);
      } else {
        display.write(*text);
        cursorX += 8; // approx char width
      }
      text++;
    }
  }

  va_end(args);
  display.display();
}



// Initialize Fingerprint sensor using HardwareSerial
void initFingerprint() {
  fingerSerial.begin(57600, SERIAL_8N1, FINGERPRINT_RX, FINGERPRINT_TX);
  finger.begin(57600);
  delay(1000); // Give sensor time to power up

  oledWrite(2, true,"Initializing ","Fingerprint...");
  Serial.println("Initializing Fingerprint Sensor...");

  // Wake up sensor
  finger.getImage();

  // Verify sensor password
  if (finger.verifyPassword()) {
    Serial.println("✅ Fingerprint sensor detected");
    oledWrite(2, true,"Fingerprint ","Sensor Ready");
    buzzerBeep(BEEP_SUCCESS);
  } else {
    Serial.println("❌ Fingerprint sensor not found");
    oledWrite(2, true,"Fingerprint ","Not Found");
    buzzerBeep(BEEP_FAILURE);
    while (true); // Stop here if sensor not detected
  }
  
}

void buildNextAvailableId() {
    Serial.println("🔍 Scanning AS608 fingerprint database...");
    oledWrite(2, true, "Scanning\n","Fingerprint DB");
    
    nextAvailableId.clear();

    std::vector<bool> used(300, false);
    int highestUsed = -1;

    // Scan all IDs
    for (int id = 0; id <= 299; id++) {
        int p = finger.loadModel(id);
        if (p == FINGERPRINT_OK) {
            used[id] = true;
            highestUsed = id;
            Serial.print("✔ Found fingerprint at ID ");
            Serial.println(id);
        }
        delay(5); // small delay for sensor stability
    }

    // First element = next ID after highest used
    int nextId = highestUsed + 1;
    if (nextId <= 299) {
        nextAvailableId.push_back(nextId);
    } else {
        // Database full edge case
        Serial.println("⚠️ Fingerprint database is FULL");
        oledWrite(2, true, "Database ","FULL!");
        nextAvailableId.push_back(300); // sentinel (you may handle this separately)
    }

    // Add holes (missing IDs) in descending order
    for (int id = highestUsed - 1; id >= 0; id--) {
        if (!used[id]) {
            nextAvailableId.push_back(id);
        }
    }

    // Print result
    Serial.println("📦 nextAvailableId contents:");
    for (size_t i = 0; i < nextAvailableId.size(); i++) {
        Serial.print("  [");
        Serial.print(i);
        Serial.print("] = ");
        Serial.println(nextAvailableId[i]);
    }

    Serial.println("✅ nextAvailableId initialization complete");
    oledWrite(2, true, "DB Scan ","Complete!");
    buzzerBeep(BEEP_SUCCESS);
}


// Heartbeat
void sendHeartbeat() {
  if (!Firebase.ready()) {
    Serial.println("❌ Firebase not ready");
    return;
  }

  time_t now = time(nullptr);
  if (now > 100000) {
    bool ok = Firebase.RTDB.setInt(&fbdo, "/FingerScanner1/Last_Seen", now);
    if (ok) {
      Serial.println("✅ Firebase heartbeat sent");
    } else {
      Serial.println("❌ Firebase write failed");
      Serial.println(fbdo.errorReason());
    }
  }
}

// Initialize Firebase DB
void initFirebaseDB() {
  if (!Firebase.ready()) return;

  FirebaseJson json;

  json.set("Last_Seen", 0);
  json.set("Status", "offline");

  FirebaseJson cmd;
  cmd.set("Type", "none");
  cmd.set("Cancelled", false);
  cmd.set("Data", "{}");
  cmd.set("Status", "idle");
  cmd.set("Result", "none");

  json.set("Command", cmd);

  if (Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1", &json)) {
    Serial.println("✅ Firebase initialized using JSON");
  } else {
    Serial.println("❌ Firebase initialization failed");
    Serial.println(fbdo.errorReason());
  }
}


void checkCommand() {
  if (!Firebase.ready()) return;

  String cmdStatus;
  String cmdType;

  // Read Command/Status and Command/Type from Firebase
  if (Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Status")) {
    cmdStatus = fbdo.stringData();
  } else {
    Serial.println("❌ Failed to read Command/Status");
    return;
  }

  if (Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Type")) {
    cmdType = fbdo.stringData();
  } else {
    Serial.println("❌ Failed to read Command/Type");
    return;
  }

  if (Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Result")) {
    cmdResult = fbdo.stringData();
  } else {
    Serial.println("❌ Failed to read Command/Type");
    return;
  }

  if (cmdStatus == "pending") {
    Serial.print("Command Status: "); Serial.println(cmdStatus);
    Serial.print("Command Type: "); Serial.println(cmdType);
    Serial.println("⚡ Pending command detected. Configuring system...");
    Firebase.RTDB.setString(&fbdo, "/FingerScanner1/Command/Status", "processing");
    
    // Show command type on OLED with beep
    if (cmdType == "enroll") {
      oledWrite(2, true, "Command: ", "ENROLLMENT");
    } else if (cmdType == "delete") {
      oledWrite(2, true, "Command: ", "DELETION");
    } else if (cmdType == "attendance") {
      oledWrite(2, true, "Command: ", "ATTENDANCE");
    } else {
      oledWrite(2, true, "Unknown ", "Command");
    }
    buzzerBeep(BEEP_PROMPT);
    delay(1000);

    configureCommandMode(cmdType);

  }
}

void configureCommandMode(const String &cmdType) {
    Serial.print("Configuring system for command type: "); Serial.println(cmdType);

    if (cmdType == "enroll") {
        Serial.println("Enrollment mode ready.");
        oledWrite(2, true, "Starting ", "Enrollment");
        buzzerBeep(BEEP_INTERMEDIATE);
        enrollActive = true;       // Start enrollment state machine
        enrollState = ENROLL_IDLE; // initialize state
    } else if (cmdType == "delete") {
        Serial.println("Delete mode ready.");
        oledWrite(2, true, "Starting ", "Deletion");
        buzzerBeep(BEEP_INTERMEDIATE);
        deleteActive = true;
        deleteState = DELETE_IDLE;
    } else if (cmdType == "attendance") {
        oledWrite(2, true, "Starting ", "Attendance");
        buzzerBeep(BEEP_INTERMEDIATE);
        Serial.println("Attendance mode ready.");
        attActive = true;
        attState = ATT_IDLE; // Initialize state
    } else {
        Serial.println("Unknown command type.");
    }
}
// -------------------- Helper to reset command --------------------
void resetCommandStatus() {
    if (!Firebase.ready()) return;

    // Retry up to 3 times
    for (int i = 0; i < 3; i++) {
        bool ok1 = Firebase.RTDB.setString(&fbdo, "/FingerScanner1/Command/Type", "none");
        bool ok2 = Firebase.RTDB.setString(&fbdo, "/FingerScanner1/Command/Status", "idle");
        bool ok3 = Firebase.RTDB.setBool(&fbdo, "/FingerScanner1/Command/Cancelled", false);
        bool ok4 = Firebase.RTDB.setString(&fbdo, "/FingerScanner1/Command/Data", "{}");

        if (ok1 && ok2 && ok3 && ok4) {
            Serial.println("✅ Command status reset to idle/none");
            return;
        } else {
            Serial.println("⚠️ Failed to reset command status, retrying...");
            Serial.println(fbdo.errorReason());
            delay(200); // wait a bit before retry
        }
    }

    Serial.println("❌ Could not reset command status after 3 attempts");
}



void Enroll(std::vector<int> &nextAvailableId) {
    if (!enrollActive) return; // Only run if enrollment started

    //Check for Enrollment Result
    if (Firebase.RTDB.getJSON(&fbdo, "/FingerScanner1/Enrollment_Result")){
        Serial.println("❌ Previous Enrollment_Result still exists");
        Firebase.RTDB.setString(&fbdo, "/FingerScanner1/Command/Result", "Previous_Result_Not_Saved");
        resetCommandStatus();
        oledWrite(2, true, "Enrollment ", "Failed");
        buzzerBeep(BEEP_FAILURE);
        enrollActive = false;
        enrollState = ENROLL_IDLE;
        return;
    }

    if (cmdResult != "none"){
        Serial.println("Result entry Not Set to none");
        oledWrite(2, true, "Enrollment ", "Failed");
        buzzerBeep(BEEP_FAILURE);
        resetCommandStatus();
        enrollActive = false;
        enrollState = ENROLL_IDLE;
        return;
    }

    // Check for cancellation
    if (Firebase.RTDB.getBool(&fbdo, "/FingerScanner1/Command/Cancelled") && fbdo.boolData()) {
        Serial.println("⚠️ Enrollment cancelled");
        FirebaseJson cancelResult;
        cancelResult.set("Status", "Cancelled");
        cancelResult.set("Type", "None");
        cancelResult.set("Data", "{}");
        cancelResult.set("ID", "None");
        Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Enrollment_Result", &cancelResult);

        oledWrite(2, true, "Enrollment ", "Cancelled");
        buzzerBeep(BEEP_FAILURE);

        resetCommandStatus();
        enrollState = ENROLL_IDLE;
        enrollActive = false;
        return;
    }

    int p = -1;

    switch (enrollState) {
        case ENROLL_IDLE:
            if (nextAvailableId.empty()) {
                Serial.println("❌ nextAvailableId is empty");
                oledWrite(2, true, "No Available ", "Fingerprint IDs");
                buzzerBeep(BEEP_FAILURE);
                gotoEnrollmentFailure();
                enrollActive = false;
                break;
            }


            if (!validateEnrollData(enrollName, enrollRollNo)) {
                Serial.println("❌ Name or Roll_No missing");
                Firebase.RTDB.setString(&fbdo, "/FingerScanner1/Command/Result", "Data_Not_Found");
                enrollActive = false;
                oledWrite(2, true, "Enrollment ", "Data Missing");
                buzzerBeep(BEEP_FAILURE);
                resetCommandStatus();
                break;
            }

            // Determine which ID to use
            if (nextAvailableId.size() == 1) {
                enrollFID = nextAvailableId[0]; // single ID mode
            } else {
                enrollFID = nextAvailableId.back(); // multi-element mode, use last element
            }
            Serial.print("Using fingerprint ID: "); Serial.println(enrollFID);
            
            oledWrite(2, true, "Enrollment ", "Ready");
            oledWrite(2, false, "\n", "\nID: ");
            display.print(enrollFID);
            display.display();
            buzzerBeep(BEEP_PROMPT);
            
            enrollState = ENROLL_SCAN1;
            break;

        case ENROLL_SCAN1:
            p = finger.getImage();
            oledWrite(2, true, "Scan 1 ", "Place Finger");
            buzzerBeep(BEEP_PROMPT);
            if (p == FINGERPRINT_NOFINGER) break; // keep waiting
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Finger scan error");
                oledWrite(2, true, "Scan Error ", "Retry...");
                buzzerBeep(BEEP_FAILURE);
                gotoEnrollmentFailure();
                enrollActive = false;
                break;
            }
            p = finger.image2Tz(1);
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Image to template failed");
                oledWrite(2, true, "Template Error ", "Retry...");
                buzzerBeep(BEEP_FAILURE);
                gotoEnrollmentFailure();
                enrollActive = false;
                break;
            }
            p = finger.fingerFastSearch();
            if (p == FINGERPRINT_OK) {
                // Duplicate found
                Serial.println("⚠️ Duplicate fingerprint found");
                oledWrite(2, true, "Duplicate ", "Fingerprint");
                buzzerBeep(BEEP_FAILURE);
                FirebaseJson result;
                result.set("Status", "Success");
                result.set("Type", "duplicate");
                result.set("Data", "{}");
                result.set("ID", String(finger.fingerID));
                Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Enrollment_Result", &result);
                resetCommandStatus();
                enrollActive = false;
                break;
            } else if (p != FINGERPRINT_NOTFOUND) {
                Serial.println("❌ Finger search failed");
                gotoEnrollmentFailure();
                oledWrite(2, true, "Scan Failed ", "Place Properly");
                buzzerBeep(BEEP_FAILURE);
                enrollActive = false;
                break;
            }
            oledWrite(2, true, "Scan 1 ", "Complete!");
            buzzerBeep(BEEP_SUCCESS);
            delay(500);
            enrollState = ENROLL_SCAN2;
            break;

        case ENROLL_SCAN2:
            p = finger.getImage();
            oledWrite(2, true, "Scan 2 ", "Place Finger");
            buzzerBeep(BEEP_PROMPT);
            if (p == FINGERPRINT_NOFINGER) break; // keep waiting
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Finger scan error (second scan)");
                gotoEnrollmentFailure();
                oledWrite(2, true, "Scan 2 Error ", "Retry...");
                buzzerBeep(BEEP_FAILURE);
                enrollActive = false;
                break;
            }
            p = finger.image2Tz(2);
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Image to template failed (second scan)");
                gotoEnrollmentFailure();
                oledWrite(2, true, "Template Error ", "Retry...");
                buzzerBeep(BEEP_FAILURE);
                enrollActive = false;
                break;
            }
            oledWrite(2, true, "Scan 2 ", "Complete!");
            buzzerBeep(BEEP_SUCCESS);
            delay(500);
            enrollState = ENROLL_CREATE;
            break;

        case ENROLL_CREATE:
            oledWrite(2, true, "Creating ", "Model...");
            buzzerBeep(BEEP_WAITING);
            p = finger.createModel();
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Create model failed");
                oledWrite(2, true, "Create Model ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                gotoEnrollmentFailure();
                enrollActive = false;
                break;
            }
            oledWrite(2, true, "Model ", "Created!");
            buzzerBeep(BEEP_SUCCESS);
            delay(500);
            enrollState = ENROLL_STORE;
            break;

        case ENROLL_STORE:
            oledWrite(2, true, "Storing ", "Model...");
            buzzerBeep(BEEP_WAITING);
            p = finger.storeModel(enrollFID);
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Store model failed");
                oledWrite(2, true, "Store Model ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                gotoEnrollmentFailure();
                enrollActive = false;
                break;
            }
            Serial.println("✅ Fingerprint enrolled successfully");
            buzzerBeep(BEEP_SUCCESS);

            showEnrollmentSuccess(enrollName, enrollRollNo);
            FirebaseJson dataJson;
            dataJson.set("Name", enrollName);
            dataJson.set("Roll_No", enrollRollNo);

            FirebaseJson result;
            result.set("Status", "Success");
            result.set("Type", "New");
            result.set("Data", dataJson);
            result.set("ID", enrollFID);
            Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Enrollment_Result", &result);

            resetCommandStatus();

            // Update nextAvailableId
            if (nextAvailableId.size() == 1) {
              nextAvailableId[0]++;  
            } else if (nextAvailableId.size() > 1) {
              nextAvailableId.pop_back(); 
            } 
            
            oledWrite(2, true, "Enrollment ", "Complete!");
            buzzerBeep(BEEP_READY);
            
            enrollActive = false;
            enrollState = ENROLL_IDLE;
            break;
    }
}

//Enroll Helper Functions
bool validateEnrollData(String &name, String &rollNo) {
    if (!Firebase.ready()) return false;

    if (!Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Name"))
        return false;

    if (!Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Roll_No"))
        return false;

    Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Name");
    name = fbdo.stringData();

    Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Roll_No");
    rollNo = fbdo.stringData();

    return (name.length() > 0 && rollNo.length() > 0);
}

void showEnrollmentSuccess(const String &name, const String &rollNo) {
    display.clearDisplay();

    int y = 0;

    // Line 1: Enrollment Successful (small)
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print("Enrollment Successful");
    y += 10;

    // Line 2: Name label (small)
    display.setCursor(0, y);
    display.print("Name:");
    y += 10;

    // Line 3: Name value (BIG)
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print(name);
    y += 18;

    // Line 4: Roll No label (small)
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print("Roll No:");
    y += 10;

    // Line 5: Roll No value (BIG)
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print(rollNo);

    display.display();
}


void gotoEnrollmentFailure() {
    Serial.println("❌ Enrollment failed");
    oledWrite(2, true, "Enrollment ", "Failed");
    buzzerBeep(BEEP_FAILURE);

    FirebaseJson failResult;
    failResult.set("Status", "Failure");
    failResult.set("Type", "None");
    failResult.set("Data", "{}");
    failResult.set("ID", "None");

    Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Enrollment_Result", &failResult);
    resetCommandStatus();

}


void Delete() {
    if (!deleteActive) return;

    // Check for cancellation
    if (Firebase.RTDB.getBool(&fbdo, "/FingerScanner1/Command/Cancelled") && fbdo.boolData()) {
        Serial.println("⚠️ Deletion cancelled");
        FirebaseJson cancelResult;
        cancelResult.set("Status", "Cancelled");
        cancelResult.set("Info", "Deletion cancelled by user");
        Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Deletion_Result", &cancelResult);
        
        oledWrite(2, true, "Deletion ", "Cancelled");
        buzzerBeep(BEEP_FAILURE);
        
        deleteActive = false;
        deleteState = DELETE_IDLE;
        resetCommandStatus();
        return;
    }

    switch (deleteState) {
        case DELETE_IDLE:
            // Start deletion
            Serial.println("⚡ Delete command detected");
            oledWrite(2, true, "Deletion ", "Starting...");
            buzzerBeep(BEEP_PROMPT);
            deleteActive = true;
            deleteState = DELETE_VALIDATE; 
            break;

        case DELETE_VALIDATE:
        {
            FirebaseJson cmdData;
            if (Firebase.RTDB.getJSON(&fbdo, "/FingerScanner1/Command/Data")) {
                cmdData = fbdo.jsonObject();
            } else {
                Serial.println("❌ Failed to read Command/Data");
                FirebaseJson failResult;
                failResult.set("Status", "Failure");
                failResult.set("Info", "Cannot read Data");
                Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Deletion_Result", &failResult);
                
                oledWrite(2, true, "Data Read ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                
                deleteActive = false;
                deleteState = DELETE_IDLE;
                resetCommandStatus();
                break;
            }

            // Extract "ID" field
            int fid = -1;
            FirebaseJsonData jsonData;
            if (Firebase.RTDB.getInt(&fbdo, "/FingerScanner1/Command/Data/ID")) {
                fid = fbdo.intData();
            } else {
                Serial.println("❌ Invalid or missing ID field in Data");
                FirebaseJson failResult;
                failResult.set("Status", "Failure");
                failResult.set("Info", "Invalid or missing ID field");
                Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Deletion_Result", &failResult);
                
                oledWrite(2, true, "Invalid ID ", "Field");
                buzzerBeep(BEEP_FAILURE);
                
                deleteActive = false;
                deleteState = DELETE_IDLE;
                resetCommandStatus();
                break;
            }

            // Validate ID range
            if (fid < 0 || fid > 299) {
                Serial.println("❌ Invalid fingerprint ID");
                FirebaseJson failResult;
                failResult.set("Status", "Failure");
                failResult.set("Info", "ID out of range (0-299)");
                Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Deletion_Result", &failResult);
                
                oledWrite(2, true, "ID Out of ", "Range");
                buzzerBeep(BEEP_FAILURE);
                
                deleteActive = false;
                deleteState = DELETE_IDLE;
                resetCommandStatus();
                break;
            }

            deleteFID = fid;
            Serial.print("Validated fingerprint ID to delete: "); Serial.println(deleteFID);
            
            oledWrite(2, true, "Delete ID: ", String(deleteFID).c_str());
            buzzerBeep(BEEP_PROMPT);
            
            deleteState = DELETE_PROCESS;
        }
        break;


        case DELETE_PROCESS:
            {
                oledWrite(2, true, "Deleting ", "ID: ");
                display.setCursor(0, 24);
                display.print(deleteFID);
                display.display();
                buzzerBeep(BEEP_WAITING);
                
                int p = finger.loadModel(deleteFID);
                FirebaseJson result;

                if (p == FINGERPRINT_OK) {
                    finger.deleteModel(deleteFID);
                    Serial.print("✅ Fingerprint deleted at ID "); Serial.println(deleteFID);
                    result.set("Status", "Success");
                    result.set("Info", "Fingerprint deleted at ID " + String(deleteFID));
                    
                    oledWrite(2, true, "Deleted ", "Successfully!");
                    buzzerBeep(BEEP_SUCCESS);

                    // Push deleted ID back to nextAvailableId
                    nextAvailableId.push_back(deleteFID);

                } else if (p == 12) {
                    Serial.print("⚠️ No fingerprint found at ID "); Serial.println(deleteFID);
                    result.set("Status", "Failure");
                    result.set("Info", "No fingerprint at given ID");
                    
                    oledWrite(2, true, "No Print at ", "ID: ");
                    display.setCursor(0, 24);
                    display.print(deleteFID);
                    display.display();
                    buzzerBeep(BEEP_FAILURE);

                } else {
                    Serial.print("❌ Deletion error at ID "); Serial.println(deleteFID);
                    result.set("Status", "Failure");
                    result.set("Info", "Error code: " + String(p));
                    
                    oledWrite(2, true, "Deletion ", "Error");
                    buzzerBeep(BEEP_FAILURE);
                }
                Serial.print(p);
                Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Deletion_Result", &result);

                deleteActive = false;
                deleteState = DELETE_IDLE;
                resetCommandStatus();
            }
            break;
    }
}

void Attendance() {
    if (!attActive) return;  

    // Check for cancellation
    if (Firebase.RTDB.getBool(&fbdo, "/FingerScanner1/Command/Cancelled") && fbdo.boolData()) {
        Serial.println("⚠️ Attendance Stopped");
        if (attStartTime != 0) {
            Firebase.RTDB.setInt(&fbdo, "/FingerScanner1/Attendance_Record/End_Time", time(nullptr));
        }
        
        oledWrite(2, true, "Attendance ", "Stopped");
        buzzerBeep(BEEP_FAILURE);
        
        attActive = false;
        attState = ATT_IDLE;
        resetCommandStatus();
        return;
    }

    int p = -1;

    switch(attState) {
       case ATT_IDLE:
{            {
            // Validate attendance data first
            if (!validateAttendanceData(attClassName)) {
                Serial.println("❌ Attendance start failed due to invalid or missing Class field");
                oledWrite(2, true, "Attendance ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                attActive = false;
                attState = ATT_IDLE;
                resetCommandStatus();
                break;
            }

            // Get section from Firebase if available
            String section = "";
            if (Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Section")) {
                section = fbdo.stringData();
            }

            // Initialize Attendance_Record in Firebase with section
            FirebaseJson attJson;
            attJson.set("Class", attClassName);
            attJson.set("Section", section);  // Add section to RTDB
            attStartTime = time(nullptr);
            attJson.set("Start_Time", attStartTime);
            attJson.set("End_Time", 0);
            FirebaseJson studentsJson;
            attJson.set("Students", studentsJson);

            if(Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Attendance_Record", &attJson)) {
                Serial.println("✅ Attendance session started");
                oledWrite(3, true, "Attendance ", "Started\n", attClassName.c_str());
                buzzerBeep(BEEP_INTERMEDIATE);
            } else {
                Serial.println("❌ Failed to initialize Attendance_Record in Firebase");
                oledWrite(2, true, "Attendance ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                attActive = false;
                attState = ATT_IDLE;
                resetCommandStatus();
                break;
            }

            // Prepare for first student
            attStudentIndex = 0;
            attState = ATT_WAIT_FINGER;
        }
        break;}


        case ATT_WAIT_FINGER:
        {
            oledWrite(2, true, "Waiting for ", "Fingerprint...");
            if (attStudentIndex == 0) {
                buzzerBeep(BEEP_PROMPT);
            }
            
            p = finger.getImage();
            if (p == FINGERPRINT_NOFINGER) break;
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Finger scan error");
                oledWrite(2, true, "Scan Error ", "Retry...");
                buzzerBeep(BEEP_FAILURE);
                break;
            }
            attState = ATT_CAPTURE_IMAGE;
        }
        break;

        case ATT_CAPTURE_IMAGE:
        {
            oledWrite(2, true, "Processing ", "Fingerprint...");
            buzzerBeep(BEEP_WAITING);
            
            p = finger.image2Tz(1);
            if (p != FINGERPRINT_OK) {
                Serial.println("❌ Image to template failed");
                oledWrite(2, true, "Processing ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                attState = ATT_WAIT_FINGER;
                break;
            }

            p = finger.fingerFastSearch();
            String studentID;
            if (p == FINGERPRINT_OK) {
                studentID = String(finger.fingerID);
                oledWrite(2, true, "Found ID: ", studentID.c_str());
                buzzerBeep(BEEP_SUCCESS);
            } else if (p == FINGERPRINT_NOTFOUND) {
                studentID = "Not_Found";
                oledWrite(2, true, "Fingerprint ", "Not Found");
                buzzerBeep(BEEP_FAILURE);
            } else {
                Serial.println("❌ Finger search failed");
                oledWrite(2, true, "Search ", "Failed");
                buzzerBeep(BEEP_FAILURE);
                attState = ATT_WAIT_FINGER;
                break;
            }

            String studentField = "Student" + String(attStudentIndex);
            FirebaseJson studentJson;
            studentJson.set("Status", "pending");
            studentJson.set("ID", studentID);
            studentJson.set("Data", "{}");

            if(Firebase.RTDB.setJSON(&fbdo, "/FingerScanner1/Attendance_Record/Students/" + studentField, &studentJson)) {
                Serial.print("✅ Student entry created: "); Serial.println(studentField);
                oledWrite(2, true, "Recorded ", "Student #");
                display.setCursor(0, 24);
                display.print(attStudentIndex + 1);
                display.display();
                buzzerBeep(BEEP_SUCCESS);
                attState = ATT_VERIFY_STATUS;
            } else {
                Serial.println("❌ Failed to create student entry in Firebase");
                oledWrite(2, true, "Firebase ", "Error");
                buzzerBeep(BEEP_FAILURE);
                attState = ATT_WAIT_FINGER;
            }
        }
        break;

                case ATT_VERIFY_STATUS:
        {
            String studentField = "Student" + String(attStudentIndex);
            String status, dataStr;

            oledWrite(2, true, "Verifying ", "Status...");
            
            if(Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Attendance_Record/Students/" + studentField + "/Status"))
                status = fbdo.stringData();
            else break;

            if(Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Attendance_Record/Students/" + studentField + "/Data"))
                dataStr = fbdo.stringData();
            else break;

            if(status == "pending") break;

            if(status == "Success") {
                FirebaseJson dataJson;
                dataJson.setJsonData(dataStr);
                FirebaseJsonData jsonData;
                dataJson.get(jsonData, "Name");
                String name = jsonData.stringValue;
                dataJson.get(jsonData, "Roll_No");
                String roll = jsonData.stringValue;

                // Show attendance success with student details
                oledWrite(2, true, "Fingerprint ", "Successful");
                buzzerBeep(BEEP_SUCCESS);
                
                // Keep success message for 2.5 seconds
                delay(2500);
                
            } else if(status == "Not_Found") {
                oledWrite(2, true, "Fingerprint ", "Not Found");
                buzzerBeep(BEEP_FAILURE);
            } else if(status == "Not_in_Class") {
                oledWrite(2, true, "Student Not ", "in Class");
                buzzerBeep(BEEP_FAILURE);
            } else {
                oledWrite(2, true, "Status: ", status.c_str());
                buzzerBeep(BEEP_INTERMEDIATE);
            }

            attStudentIndex++;
            
            // Show next student count
            oledWrite(2, true, "Next Student ", "#");
            display.setCursor(0, 24);
            display.print(attStudentIndex + 1);
            display.display();
            
            attState = ATT_WAIT_FINGER;
        }
        break;
    }
}

void showAttendanceSuccess(const String &name, const String &rollNo) {
    display.clearDisplay();

    int y = 0;

    // Line 1: Attendance Successful (small)
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print("Attendance Recorded!");
    y += 10;

    // Line 2: Name label (small)
    display.setCursor(0, y);
    display.print("Name:");
    y += 10;

    // Line 3: Name value
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print(name);
    y += 18;

    // Line 4: Roll No label (small)
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print("Roll No:");
    y += 10;

    // Line 5: Roll No value
    display.setTextSize(1);
    display.setCursor(0, y);
    display.print(rollNo);

    display.display();
}

bool validateAttendanceData(String &className) {
    if (!Firebase.ready()) return false;

    // Check if Class field exists in the Command/Data
    if (!Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Class")) {
        Serial.println("❌ Attendance validation failed: Class field missing");
        return false;
    }

    // Read the Class field
    Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Class");
    className = fbdo.stringData();

    if (className.length() == 0) {
        Serial.println("❌ Attendance validation failed: Class name empty");
        return false;
    }

    // Also read Section field if available (optional)
    if (Firebase.RTDB.getString(&fbdo, "/FingerScanner1/Command/Data/Section")) {
        String section = fbdo.stringData();
        Serial.print("Section: ");
        Serial.println(section);
        // You can store this section info if needed
    }

    Serial.print("✅ Attendance validation success: Class = ");
    Serial.println(className);
    return true;
}


void clearAS608Storage() {
    oledWrite(2, true, "Clearing", "AS608 Storage...");
    buzzerBeep(BEEP_WAITING);
    Serial.println("⚠️ Clearing all fingerprints in AS608 storage...");

    int p = finger.emptyDatabase();  // Clear all stored templates
    if (p == FINGERPRINT_OK) {
        Serial.println("✅ AS608 storage cleared successfully");
        oledWrite(2, true, "Storage", "Cleared!");
        buzzerBeep(BEEP_SUCCESS);
    } else {
        Serial.print("❌ Failed to clear AS608 storage. Error code: ");
        Serial.println(p);
        oledWrite(2, true, "Clear Failed", String(p).c_str());
        buzzerBeep(BEEP_FAILURE);
    }
}
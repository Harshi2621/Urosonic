# Urosonic Backend — REST API & ML Inference Service

The **Urosonic Backend** is a high-performance Python Flask microservice powering the Urosonic clinical acoustic uroflowmetry system. It provides real-time acoustic signal machine learning flow rate inference, patient and clinician portals, urinary and fluid balance diaries, in-app clinical messaging, doctor feedback, hospital surgery logs, and medical inventory tracking.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Directory Structure](#directory-structure)
3. [Prerequisites & System Requirements](#prerequisites--system-requirements)
4. [Step-by-Step Setup Guide](#step-by-step-setup-guide)
   - [Step 1: Navigate to Backend Directory](#step-1-navigate-to-backend-directory)
   - [Step 2: Set Up Python Virtual Environment](#step-2-set-up-python-virtual-environment)
   - [Step 3: Start MySQL Database](#step-3-start-mysql-database)
   - [Step 4: Initialize Database Schema & Seed Data](#step-4-initialize-database-schema--seed-data)
   - [Step 5: Configure Environment Variables (.env)](#step-5-configure-environment-variables-env)
   - [Step 6: Start the Server](#step-6-start-the-server)
   - [Step 7: Verify Server & ML Health](#step-7-verify-server--ml-health)
   - [Step 8: Run Automated Test Suite](#step-8-run-automated-test-suite)
5. [Connecting with the iOS Application](#connecting-with-the-ios-application)
6. [Seed Accounts & Test Credentials](#seed-accounts--test-credentials)
7. [REST API Documentation](#rest-api-documentation)
   - [Health & Diagnostics](#health--diagnostics)
   - [Authentication & Password Reset](#authentication--password-reset)
   - [Acoustic ML Flow Inference](#acoustic-ml-flow-inference)
   - [Measurements & Curves](#measurements--curves)
   - [Fluid Intake & Urine Output Diary](#fluid-intake--urine-output-diary)
   - [Real-Time Messaging & Chat](#real-time-messaging--chat)
   - [Doctor Feedback & Prescriptions](#doctor-feedback--prescriptions)
   - [Hospital Inventory & Catheter Stock](#hospital-inventory--catheter-stock)
   - [Surgery Records & OR Teams](#surgery-records--or-teams)
   - [Follow-up Reminders](#follow-up-reminders)
   - [Profiles & Dashboards](#profiles--dashboards)
8. [Management Scripts (start.sh / stop.sh)](#management-scripts-startsh--stopsh)
9. [Troubleshooting & FAQ](#troubleshooting--faq)

---

## System Architecture

```text
       ┌────────────────────────┐
       │     iOS Client         │
       │ (SwiftUI / AudioEngine)│
       └───────────┬────────────┘
                   │ HTTP / JSON
                   ▼
       ┌────────────────────────┐
       │   Flask REST Server    │  ◄── Port 5001
       │       (app.py)         │
       └─────┬────────────┬─────┘
             │            │
             ▼            ▼
   ┌───────────────┐  ┌─────────────────────────┐
   │  PyMySQL Pool │  │   MLInferenceService    │
   │  (schema.sql) │  │  (GradientBoosting /    │
   └───────┬───────┘  │   Random Forest Model)  │
           │          └─────────────────────────┘
           ▼
   ┌───────────────┐
   │ MySQL / XAMPP │  ◄── Port 3306
   └───────────────┘
```

- **Framework**: Flask 3.0.3 with Flask-CORS for cross-origin mobile client support.
- **Database**: MySQL 5.7+ / MariaDB 10.4+ via PyMySQL (`DictCursor` connection pooling with per-request lifecycle management).
- **Machine Learning**: `scikit-learn` 1.6+, `numpy` 2.0+, `scipy`, and `joblib` running temporal context feature extraction (39-D vector) and non-negative flow curve numerical integration.
- **Security**: `bcrypt` salted password hashing with adaptive cost rounds and cryptographic token generation for password recovery.

---

## Directory Structure

```text
backend/
├── README.md                   # Comprehensive backend step-by-step documentation
├── app.py                      # Application entry point, CORS, blueprint registration & health routes
├── config.py                   # Centralized configuration class loading .env variables
├── db.py                       # PyMySQL per-request connection helper, socket fallback & query wrappers
├── ml_inference_service.py     # Singleton ML inference engine, feature pipeline, and curve computation
├── schema.sql                  # Clean MySQL DDL database schema (tables, foreign keys, constraints)
├── urosonic.sql                # Complete phpMyAdmin SQL dump with schema and seed datasets
├── requirements.txt            # Python dependencies (Flask, PyMySQL, scikit-learn, etc.)
├── start.sh                    # Robust startup script (venv detection, port conflict check, launcher)
├── stop.sh                     # Graceful shutdown script for PID on port 5001
├── .env.example                # Configuration template for local environment variables
├── .env                        # Local environment variables (DB host, port, credentials)
│
├── ml/                         # Local ML models and metadata copy
│   └── models/
│       ├── acoustic_flow_model.joblib   # Trained ML regression model bundle
│       └── model_metadata.json          # Model version, feature columns, metrics & hyperparams
│
├── routes/                     # Modular API Route Blueprints
│   ├── __init__.py
│   ├── ai_flow.py              # POST /api/v1/ai/predict-flow ML inference endpoint
│   ├── auth.py                 # Registration, login, password recovery
│   ├── measurements.py         # Uroflowmetry records, curve serialization & statistics
│   ├── fluid.py                # Fluid intake & urine output balance diary
│   ├── messages.py             # Doctor-patient messaging thread & unread badges
│   ├── feedback.py             # Doctor clinical assessments & prescription publishing
│   ├── stock.py                # Hospital inventory, catheter & consumable stock
│   ├── surgery.py              # Surgical procedure records & surgical team logs
│   ├── followup.py             # Patient appointment recalls & reminders
│   └── profile.py              # User profiles, doctor patient rosters & dashboards
│
└── tests/                      # Automated Test Suite
    ├── __init__.py
    ├── test_ai_flow.py         # 20 ML endpoint, feature extraction & input validation tests
    ├── test_fluid.py           # Fluid intake, urine output & 24h balance tests
    └── test_delete_account.py  # User profile lifecycle & soft-deletion tests
```

---

## Prerequisites & System Requirements

Before setting up the backend, ensure your workstation meets the following requirements:

- **Operating System**: macOS 12+ (Apple Silicon or Intel), Linux (Ubuntu 20.04+), or Windows 10/11 (with WSL or Git Bash).
- **Python**: `Python 3.10` or newer (`python3 --version`).
- **Database Server**: **XAMPP** (recommended on macOS) or standalone **MySQL 5.7+ / MariaDB 10.4+**.
- **Port Availability**:
  - `5001`: Backend API server.
  - `3306`: MySQL database server.
- **Command Line Utilities**: `curl`, `lsof`, `git`.

---

## Step-by-Step Setup Guide

Follow these steps sequentially to install, configure, seed, run, and test the backend.

### Step 1: Navigate to Backend Directory

Open your terminal and change to the `backend` directory inside the repository:

```bash
cd /Users/sail/Downloads/Urosonic/backend
```

Verify your current directory contains `app.py`, `requirements.txt`, and `schema.sql`:

```bash
ls -la
```

---

### Step 2: Set Up Python Virtual Environment

Create an isolated Python virtual environment to prevent package version conflicts with system packages.

1. **Create the virtual environment**:
   ```bash
   python3 -m venv venv
   ```

2. **Activate the virtual environment**:
   - On macOS / Linux:
     ```bash
     source venv/bin/activate
     ```
   - On Windows (PowerShell):
     ```powershell
     .\venv\Scripts\Activate.ps1
     ```
   - On Windows (Command Prompt):
     ```cmd
     .\venv\Scripts\activate.bat
     ```

3. **Upgrade `pip` and install project dependencies**:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Verify package installation**:
   ```bash
   python -c "import flask, pymysql, sklearn, joblib; print('✅ All dependencies imported successfully!')"
   ```

---

### Step 3: Start MySQL Database

The backend requires an active MySQL server listening on port `3306`.

#### Option A: Using XAMPP on macOS (Recommended)
1. Open **XAMPP Control Panel** from Applications and start the **MySQL Database** module.
2. Alternatively, start it via terminal:
   ```bash
   sudo /Applications/XAMPP/xamppfiles/bin/mysql.server start
   ```

#### Option B: Using Homebrew MySQL on macOS
```bash
brew services start mysql
```

#### Option C: Using Native Linux MySQL / MariaDB
```bash
sudo systemctl start mysql
```

---

### Step 4: Initialize Database Schema & Seed Data

You can initialize the database using either the **clean production schema** or the **sample seed database**.

#### Choice 1: Import Full Seed Database (Includes demo doctors, patients, records)
Run the following command to create the database and populate sample records:

```bash
mysql -u root -p urosonic < urosonic.sql
```
*(If prompted for a password in XAMPP, simply press **Enter** as default password is empty).*

If the `urosonic` database does not exist yet, create it first:
```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS urosonic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root urosonic < urosonic.sql
```

#### Choice 2: Import Fresh Empty Schema (Clean install)
```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS urosonic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root urosonic < schema.sql
```

#### Choice 3: Using phpMyAdmin
1. Open `http://localhost/phpmyadmin/` in your browser.
2. Click **New** in the left sidebar and create a database named `urosonic` with collation `utf8mb4_unicode_ci`.
3. Select the `urosonic` database, navigate to the **Import** tab.
4. Click **Choose File**, select `backend/urosonic.sql` (or `backend/schema.sql`), and click **Import** (or **Go**).

---

### Step 5: Configure Environment Variables (.env)

The backend reads configuration settings from the `.env` file located in `backend/.env`.

Inspect and customize `.env` for your environment:

```ini
# Urosonic Backend Environment Configuration
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=
MYSQL_DB=urosonic
SECRET_KEY=urosonic-secret-key-local-dev
DEBUG=True
```

#### Configuration Key Descriptions:
| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `MYSQL_HOST` | `127.0.0.1` | MySQL server host address (`localhost` or IP). |
| `MYSQL_PORT` | `3306` | MySQL port (standard is `3306`). |
| `MYSQL_USER` | `root` | Database username (`root` for default XAMPP). |
| `MYSQL_PASSWORD`| `""` (empty) | Database password (leave blank for XAMPP default). |
| `MYSQL_DB` | `urosonic` | Database name. |
| `SECRET_KEY` | `urosonic-...` | Secret string for session signing & token generation. |
| `DEBUG` | `True` | Enables hot-reloading and detailed tracebacks. |
| `MYSQL_UNIX_SOCKET` | *Optional* | Path to MySQL unix socket (e.g. `/Applications/XAMPP/xamppfiles/var/mysql/mysql.sock`). Handled automatically if TCP socket fails. |

---

### Step 6: Start the Server

You can launch the backend using either the automated script or manual terminal execution.

#### Option A: Using the Automated Startup Script (`start.sh`)
From the `backend/` directory:
```bash
chmod +x start.sh
./start.sh
```

The script will automatically:
1. Detect and activate `venv/`.
2. Check if port `5001` is already in use.
3. Pre-load the Acoustic Machine Learning model.
4. Start the server on `http://0.0.0.0:5001`.

#### Option B: Manual Execution
With the virtual environment activated:
```bash
python app.py
```

Expected startup output:
```text
🚀 Starting Urosonic API Server...
🌐 API running at: http://127.0.0.1:5001
🩺 Health check:   http://127.0.0.1:5001/health
[INFO] Acoustic ML model pre-loaded successfully.
 * Serving Flask app 'app'
 * Debug mode: on
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5001
 * Running on http://<YOUR_LOCAL_IP>:5001
```

---

### Step 7: Verify Server & ML Health

Open a new terminal window to verify server status via `curl`:

1. **Root Status Check**:
   ```bash
   curl http://127.0.0.1:5001/
   ```
   **Response**:
   ```json
   {
     "message": "Urosonic API Server is running",
     "version": "1.0.0"
   }
   ```

2. **System & ML Diagnostics Health Check**:
   ```bash
   curl http://127.0.0.1:5001/health
   ```
   **Expected Response**:
   ```json
   {
     "app": "Urosonic API",
     "db": "connected",
     "ml_model": "loaded (v1.0.0)",
     "status": "ok",
     "version": "1.0.0"
   }
   ```

If `"db"` shows `"connected"` and `"ml_model"` shows `"loaded (v1.0.0)"`, your backend is fully operational and ready for requests.

---

### Step 8: Run Automated Test Suite

The backend includes a comprehensive 32-test unit and integration suite covering ML inference, hydroacoustic validation, fluid logs, user profiles, and API routes.

With the virtual environment activated, run the full test suite:

```bash
python -m unittest discover tests
```

To run individual test modules:
```bash
# Test Machine Learning acoustic inference and boundary checks (20 tests)
python -m unittest tests/test_ai_flow.py

# Test fluid intake and urinary balance diary
python -m unittest tests/test_fluid.py

# Test profile update and user lifecycle
python -m unittest tests/test_delete_account.py
```

---

## Connecting with the iOS Application

The iOS client communicates with this backend over HTTP REST.

### 1. Running on iOS Simulator
The iOS Simulator shares your Mac's network loopback interface. In `Urosonic/Networking/APIClient.swift`, set:

```swift
static let baseURL = "http://127.0.0.1:5001"
```

### 2. Running on Physical iPhone / iPad
When deploying to a physical device over Wi-Fi:
1. Find your Mac's local IP address:
   ```bash
   ipconfig getifaddr en0
   # Example output: 192.168.1.15
   ```
2. Update `APIClient.swift` in Xcode:
   ```swift
   static let baseURL = "http://192.168.1.15:5001"
   ```
3. Ensure both your Mac and iOS device are connected to the same Wi-Fi network and that port `5001` is not blocked by macOS Firewall (**System Settings > Network > Firewall**).

---

## Seed Accounts & Test Credentials

When initialized with `urosonic.sql`, the database includes ready-to-use testing accounts:

| Role | Name | Email | Password | Details |
| :--- | :--- | :--- | :--- | :--- |
| **Doctor** | Dr. Kiran | `kiran@gmail.com` | `Kiran@123` | License: `ABC@123`, Urology Spec |
| **Patient** | Lokesh | `lokesh@gmail.com` | `Lokesh@123` | Linked to Dr. Kiran (ID: 9) |

You can also register fresh accounts via the mobile app or directly via `POST /auth/register`.

---

## REST API Documentation

Base URL: `http://127.0.0.1:5001`  
All JSON request bodies must include `Content-Type: application/json`.

### Health & Diagnostics

#### `GET /`
Basic status ping.

#### `GET /health`
Validates MySQL database connection and ML model readiness.
- **Success Response (200)**:
  ```json
  {
    "app": "Urosonic API",
    "db": "connected",
    "ml_model": "loaded (v1.0.0)",
    "status": "ok",
    "version": "1.0.0"
  }
  ```

---

### Authentication & Password Reset

#### `POST /auth/register`
Creates a new patient or doctor account.
- **Request Body**:
  ```json
  {
    "full_name": "Jane Doe",
    "email": "jane@example.com",
    "phone": "555-0199",
    "password": "SecurePassword123!",
    "role": "patient",
    "age": 42,
    "gender": "Female",
    "condition": "Dysuria",
    "doctor_id": 9
  }
  ```
  *(For doctor registration, set `"role": "doctor"`, `"license_number": "MED-9921"`, `"specialization": "Urology"`)*.
- **Success Response (201)**:
  ```json
  {
    "message": "Registration successful",
    "user": {
      "id": 10,
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "role": "patient",
      "avatar_initials": "JD"
    }
  }
  ```

#### `POST /auth/login`
Authenticates a user via email and password with role validation.
- **Request Body**:
  ```json
  {
    "email": "jane@example.com",
    "password": "SecurePassword123!",
    "role": "patient"
  }
  ```
- **Success Response (200)**:
  ```json
  {
    "message": "Login successful",
    "user": {
      "id": 10,
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "role": "patient",
      "avatar_initials": "JD",
      "doctor_id": 9
    }
  }
  ```

#### `POST /auth/forgot-password`
Generates a secure password reset token.
- **Request Body**:
  ```json
  { "email": "jane@example.com" }
  ```
- **Response (200)**:
  ```json
  {
    "message": "Reset token generated",
    "reset_token": "a1b2c3d4...",
    "expires_at": "2026-10-24T10:30:00"
  }
  ```

#### `POST /auth/reset-password`
Applies a new password using a valid reset token.
- **Request Body**:
  ```json
  {
    "token": "a1b2c3d4...",
    "new_password": "NewSecurePassword456!"
  }
  ```

---

### Acoustic ML Flow Inference

#### `POST /api/v1/ai/predict-flow`
Performs deterministic flow rate prediction from streaming acoustic frames captured by the iOS client at 44.1 kHz. Computes $Q_{\text{max}}$, average flow rate, voided volume (via trapezoidal integration), and time-series curve points.

- **Requirements**:
  - Minimum of 4 chronological frames (`MIN_REQUIRED_FRAMES`).
  - Monotonically increasing timestamps (`timestamp >= prev_timestamp`).
  - Numeric, finite values for all acoustic parameters.

- **Request Body**:
  ```json
  {
    "sample_rate": 44100,
    "features": [
      {
        "timestamp": 0.0,
        "rms": 0.0152,
        "peak": 0.0481,
        "dbfs": -36.3,
        "dominant_frequency": 1420.5,
        "spectral_centroid": 2840.1,
        "spectral_energy": 0.0089
      },
      {
        "timestamp": 0.05,
        "rms": 0.0245,
        "peak": 0.0892,
        "dbfs": -32.1,
        "dominant_frequency": 1680.0,
        "spectral_centroid": 3120.4,
        "spectral_energy": 0.0165
      },
      {
        "timestamp": 0.10,
        "rms": 0.0381,
        "peak": 0.1140,
        "dbfs": -28.4,
        "dominant_frequency": 1850.2,
        "spectral_centroid": 3310.8,
        "spectral_energy": 0.0298
      },
      {
        "timestamp": 0.15,
        "rms": 0.0310,
        "peak": 0.0950,
        "dbfs": -30.2,
        "dominant_frequency": 1710.0,
        "spectral_centroid": 3190.0,
        "spectral_energy": 0.0210
      }
    ]
  }
  ```

- **Success Response (200)**:
  ```json
  {
    "success": true,
    "model_version": "1.0.0",
    "prediction_count": 4,
    "metrics": {
      "qmax": 24.38,
      "average_flow": 15.62,
      "voided_volume": 285.4,
      "voiding_time": 18.25,
      "status": "NORMAL"
    },
    "flow_curve": [
      { "timestamp": 0.0, "flow_ml_s": 0.0 },
      { "timestamp": 0.05, "flow_ml_s": 12.4 },
      { "timestamp": 0.10, "flow_ml_s": 24.38 },
      { "timestamp": 0.15, "flow_ml_s": 19.8 }
    ],
    "volume_curve": [
      { "timestamp": 0.0, "volume_ml": 0.0 },
      { "timestamp": 0.05, "volume_ml": 0.31 },
      { "timestamp": 0.10, "volume_ml": 1.23 },
      { "timestamp": 0.15, "volume_ml": 2.34 }
    ],
    "research_status": "simulated_dataset_model_not_clinically_validated"
  }
  ```

---

### Measurements & Curves

#### `POST /measurements`
Saves an acoustic uroflowmetry test session.
- **Request Body**:
  ```json
  {
    "patient_id": 8,
    "qmax": 22.4,
    "avg_flow": 14.8,
    "volume": 320,
    "void_time": 21,
    "status": "NORMAL",
    "notes": "Morning voiding test",
    "flow_curve_json": [
      { "timestamp": 0.0, "flow_ml_s": 0.0 },
      { "timestamp": 5.0, "flow_ml_s": 22.4 },
      { "timestamp": 21.0, "flow_ml_s": 0.0 }
    ]
  }
  ```

#### `GET /measurements/patient/<patient_id>`
Returns all historical tests for a specific patient, ordered by recording timestamp descending.

#### `GET /measurements/<id>`
Returns details and complete flow curve points for a single test.

#### `GET /measurements/patient/<patient_id>/latest`
Returns the patient's most recent uroflowmetry test record.

#### `GET /measurements/patient/<patient_id>/stats`
Returns aggregate statistics (total tests, mean $Q_{\text{max}}$, average voided volume).

#### `DELETE /measurements/<id>`
Deletes a measurement record.

---

### Fluid Intake & Urine Output Diary

#### `POST /fluid` or `POST /fluid/log`
Logs fluid intake.
- **Request Body**:
  ```json
  {
    "patient_id": 8,
    "drink_type": "Water",
    "volume_ml": 350,
    "logged_at": "09:15 AM",
    "log_date": "2026-10-24"
  }
  ```

#### `GET /fluid/patient/<patient_id>`
Retrieves fluid intake history for the patient.

#### `GET /fluid/patient/<patient_id>/today-summary`
Returns today's total intake volume and breakdown by beverage type.

#### `POST /fluid/output`
Logs urine output volume and clinical quality.
- **Request Body**:
  ```json
  {
    "patient_id": 8,
    "volume_ml": 280,
    "urgency": "Normal",
    "color": "Pale Yellow",
    "source": "Acoustic Test",
    "logged_at": "11:45 AM",
    "log_date": "2026-10-24",
    "notes": "No pain or strain"
  }
  ```

#### `GET /fluid/patient/<patient_id>/output`
Retrieves urine output records.

#### `GET /fluid/patient/<patient_id>/balance`
Calculates net 24-hour hydration balance ($\text{Intake} - \text{Output}$).

#### `DELETE /fluid/<id>` & `DELETE /fluid/output/<id>`
Deletes an intake or output entry.

---

### Real-Time Messaging & Chat

#### `GET /messages/conversations/<user_id>` (also `/chat/conversations/...`)
Lists active conversation threads with latest message previews and unread indicators.

#### `GET /messages/thread/<user_id_1>/<user_id_2>` (also `/chat/thread/...`)
Returns all chat messages exchanged between two users, automatically marking received messages as read.

#### `POST /messages` or `POST /messages/send` (also `/chat/send`)
Sends a message between patient and doctor.
- **Request Body**:
  ```json
  {
    "sender_id": 8,
    "receiver_id": 9,
    "message": "Dr. Kiran, I noticed an improvement in my flow rate this morning."
  }
  ```

#### `GET /messages/unread-count/<user_id>`
Returns total count of unread incoming messages for the notification badge.

---

### Doctor Feedback & Prescriptions

#### `POST /feedback`
Publishes clinical interpretation, diagnosis, and prescription on a measurement test. Auto-creates follow-up reminder if `follow_up_date` is provided.
- **Request Body**:
  ```json
  {
    "measurement_id": 1,
    "doctor_id": 9,
    "patient_id": 8,
    "interpretation": "Normal",
    "clinical_notes": "Symmetric bell-shaped curve with adequate voided volume.",
    "prescription": "Maintain 2.5L daily hydration.",
    "follow_up_date": "2026-11-20"
  }
  ```

#### `GET /feedback/measurement/<measurement_id>`
Fetches clinical feedback attached to a specific test.

#### `GET /feedback/patient/<patient_id>`
Returns all clinical feedback given to a patient across all sessions.

---

### Hospital Inventory & Catheter Stock

#### `GET /stock/<doctor_id>`
Lists supplies, catheter kits, and current stock status (alerts if quantity is below threshold).

#### `POST /stock`
Creates an inventory item.
- **Request Body**:
  ```json
  {
    "doctor_id": 9,
    "name": "Foley Catheter 16Fr",
    "category": "Catheters",
    "current_qty": 35,
    "threshold": 10,
    "unit": "pieces"
  }
  ```

#### `POST /stock/<item_id>/restock`
Quick restock action incrementing available quantity.
- **Request Body**: `{ "quantity": 20 }`

#### `PUT /stock/<item_id>` & `DELETE /stock/<item_id>`
Updates item parameters or removes an item from inventory.

---

### Surgery Records & OR Teams

#### `GET /surgery/doctor/<doctor_id>?search=`
Returns surgeries performed by the doctor with team member details, filtered optionally by search term.

#### `POST /surgery`
Logs an operative procedure, fees, consumables, stent tracking, and surgical team members.
- **Request Body**:
  ```json
  {
    "doctor_id": 9,
    "surgery_date": "2026-10-22",
    "hospital": "City Urology Hospital",
    "my_role": "Primary Surgeon",
    "patient_name": "Lokesh",
    "patient_id_ref": "P-1082",
    "phone_number": "8825489412",
    "surgery_type": "URSL + DJ Stenting",
    "diagnoses": ["Left Lower Ureteric Calculus (8mm)"],
    "professional_fees": 25000,
    "instrument_charges": 5000,
    "payment_status": "Paid",
    "stent_type": "DJ Stent 6Fr 26cm",
    "stent_due_date": "2026-11-15",
    "stent_status": "In Place",
    "remarks": "Stone fragmented completely with Holmium laser.",
    "team": [
      {
        "role": "Anesthetist",
        "member_name": "Dr. Anjali",
        "fees": 6000,
        "payment_status": "Paid"
      }
    ]
  }
  ```

#### `PUT /surgery/<surgery_id>` & `DELETE /surgery/<surgery_id>`
Edits or removes surgery records.

---

### Follow-up Reminders

#### `GET /followup/<doctor_id>` (also `/followups/...`)
Lists active patient recalls categorized by status (`UPCOMING`, `DUE`, `OVERDUE`, `COMPLETED`).

#### `POST /followup`
Schedules a follow-up consultation date.

#### `POST /followup/<fid>/complete`
Marks a follow-up appointment as completed.

---

### Profiles & Dashboards

#### `GET /profile/<user_id>`
Retrieves user profile (differentiates patient vs doctor attributes).

#### `PUT /profile/<user_id>`
Updates profile details (phone, age, condition, specialization).

#### `PUT /profile/<user_id>/change-password`
Changes account password.
- **Request Body**:
  ```json
  {
    "old_password": "CurrentPassword123!",
    "new_password": "NewSecurePassword456!"
  }
  ```

#### `GET /profile/doctor/<doctor_id>/patients`
Returns list of assigned patients, their latest test status, and unread chat counts.

#### `GET /profile/doctor/<doctor_id>/dashboard`
Returns high-level statistics for the doctor's home dashboard (total patients, tests today, abnormal flags, pending follow-ups).

#### `GET /profile/patient/<patient_id>/dashboard`
Returns patient overview metrics (last flow rate, test count, assigned doctor info).

---

## Management Scripts (start.sh / stop.sh)

Convenience shell scripts are provided in the `backend/` directory for daily operation:

### `start.sh`
- Automatically finds and activates the virtual environment (`venv/`).
- Checks if port `5001` is already active. If active, prints the running PID and health URL.
- Starts `app.py` in the foreground.

```bash
./start.sh
```

### `stop.sh`
- Detects the process running on port `5001`.
- Sends a `SIGTERM` signal for clean shutdown.
- Force kills (`SIGKILL`) if the process does not terminate within 1 second.
- Confirms port `5001` is released.

```bash
./stop.sh
```

---

## Troubleshooting & FAQ

### 1. Port 5001 is already in use (`Address already in use`)
Run `stop.sh` to release the port:
```bash
./stop.sh
```
Or manually terminate the process occupying port 5001:
```bash
lsof -ti :5001 | xargs kill -9
```

### 2. MySQL Connection Refused (`Can't connect to MySQL server on '127.0.0.1'`)
- Ensure MySQL is running:
  ```bash
  sudo /Applications/XAMPP/xamppfiles/bin/mysql.server status
  ```
- If stopped, start it:
  ```bash
  sudo /Applications/XAMPP/xamppfiles/bin/mysql.server start
  ```
- If using Homebrew MySQL:
  ```bash
  brew services restart mysql
  ```

### 3. Database `urosonic` does not exist (`1049: Unknown database 'urosonic'`)
Create the database and import schema:
```bash
mysql -u root -e "CREATE DATABASE urosonic CHARACTER SET utf8mb4;"
mysql -u root urosonic < urosonic.sql
```

### 4. `ModuleNotFoundError: No module named 'flask_cors'` (or another package)
Ensure you are using the virtual environment's Python interpreter:
```bash
source venv/bin/activate
pip install -r requirements.txt
```

### 5. `InconsistentVersionWarning` when loading the ML model
The pre-trained model artifact was built with scikit-learn. The backend includes a compatibility shim in `ml_inference_service.py` to transparently resolve loss functions across scikit-learn releases. The warning is informational and does not affect inference precision.

### 6. iOS Client fails to connect to backend
- Check that the backend is bound to `0.0.0.0` (which it does by default in `app.py`).
- Verify your Mac's IP address (`ipconfig getifaddr en0`) and confirm `APIClient.baseURL` in the iOS app points to `http://<YOUR_IP>:5001`.
- Test reaching the health endpoint from another device or curl:
  ```bash
  curl http://<YOUR_IP>:5001/health
  ```

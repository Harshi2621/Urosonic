# Urosonic — Acoustic Uroflowmetry System

**Urosonic** is a medical-grade acoustic uroflowmetry diagnostic platform that captures voiding acoustic audio, processes frequency and spectral energy features in real time, and infers urinary flow rate curves ($Q_{\text{max}}$, $Q_{\text{avg}}$, voided volume, voiding time) using a trained Machine Learning model.

The platform consists of three integrated components:
1. **iOS Client (`Urosonic/`)**: Native SwiftUI application with hardware-synchronized 44.1 kHz audio recording, real-time FFT spectrogram rendering, patient/doctor portals, and offline physiological acoustic fallback estimation.
2. **REST API Backend (`backend/`)**: Python Flask microservice connecting to MySQL, providing user authentication, measurement records, live chat, clinical triage, and the `/api/ai/predict_flow` endpoint with model pre-warming.
3. **Machine Learning Pipeline (`ml/`)**: Acoustic feature extraction (13 MFCCs, spectral centroid, spectral rolloff, RMS energy, zero-crossing rate) and Random Forest regression model trained on acoustic voiding sessions.

---

## Repository Architecture & Directory Structure

```text
Urosonic/                                    # Workspace Root
├── Urosonic.code-workspace                  # Multi-layer IDE workspace configuration
├── README.md                                # System architecture, setup, and runbook
│
├── Urosonic.xcodeproj/                      # Xcode project configuration
│
├── Urosonic/                                # iOS Application Source (SwiftUI)
│   ├── UrosonicApp.swift                    # Main Application Entry Point
│   ├── ContentView.swift                    # Root Router Switcher (Splash -> Auth -> Role View)
│   ├── Info.plist                           # Audio capture permissions & local network usage
│   │
│   ├── Core/                                # Global State, Navigation, and Domain Models
│   │   ├── AppRouter.swift                  # Central navigation state & role routing
│   │   ├── AuthState.swift                  # Reactive session state & authenticated user profile
│   │   └── DataModels.swift                 # Clinical models (Patient, FlowMetrics, Logs)
│   │
│   ├── Networking/                          # Backend HTTP API Service Layer
│   │   ├── APIClient.swift                  # Async/await REST client & monotonic frame sanitizer
│   │   └── APIModels.swift                  # Codable DTOs matching Flask backend responses
│   │
│   ├── Audio/                               # Real-Time Audio Capture & Hardware Sessions
│   │   ├── AudioBufferProcessor.swift       # Monotonic sample-counted frame buffer processor
│   │   ├── AudioCaptureService.swift        # AVAudioEngine 44.1 kHz PCM microphone capture
│   │   ├── AudioRecordingFile.swift         # Local WAV recording file writer
│   │   └── AudioSessionManager.swift        # AVAudioSession category & activation manager
│   │
│   ├── SignalProcessing/                    # DSP, FFT, and Acoustic Feature Extractors
│   │   ├── AudioFeatureExtractor.swift      # vDSP spectral centroid, RMS energy, and rolloff
│   │   ├── FFTProcessor.swift               # Accelerate vDSP FFT calculation (512-point)
│   │   └── FlowEventDetector.swift          # Energy threshold flow onset/cessation detector
│   │
│   ├── Calibration/                         # Ground Truth Calibration & Dataset Management
│   │   ├── AcousticVsGroundTruthView.swift  # Side-by-side curve comparison UI
│   │   ├── CalibrationModeView.swift        # Guided laboratory calibration workflow
│   │   ├── CalibrationModels.swift          # Ground truth session metadata schemas
│   │   ├── CalibrationSessionManager.swift  # Session recorder and synchronization manager
│   │   ├── DatasetExporter.swift            # ZIP / JSON dataset bundle packager
│   │   └── GroundTruthInputView.swift       # Digital scale weight / volume input form
│   │
│   ├── Recording/                           # Active Recording Telemetry UI
│   │   └── AcousticTimelineView.swift       # Live scrolling frequency waterfall & waveforms
│   │
│   ├── Views/                               # Visual User Interfaces Grouped by Domain
│   │   ├── Auth/                            # Authentication Flows
│   │   │   ├── LoginView.swift              # Role-aware login view
│   │   │   ├── RegisterView.swift           # Patient / Doctor registration
│   │   │   ├── ForgotPasswordView.swift     # Password recovery interface
│   │   │   └── SplashView.swift             # High-tech medical acoustic splash screen
│   │   │
│   │   ├── Patient/                         # Patient Portal Screens
│   │   │   ├── PatientMainView.swift        # Patient TabView shell
│   │   │   ├── PatientHomeView.swift        # Quick test trigger & recent flow summary
│   │   │   ├── ActiveRecordingView.swift    # Live voiding recording, decibel meter & telemetry
│   │   │   ├── VolumeEntryView.swift        # Post-recording voided volume confirmation
│   │   │   ├── ResultGraphView.swift        # Diagnostic result report with interactive curve
│   │   │   ├── PatientHistoryView.swift     # Past uroflowmetry sessions & trends
│   │   │   ├── PatientMessagesView.swift    # Direct chat thread with assigned urologist
│   │   │   ├── FluidLoggerView.swift        # Daily fluid intake & bladder diary
│   │   │   └── PatientProfileView.swift     # Personal clinical details & doctor linking
│   │   │
│   │   ├── Doctor/                          # Clinician Portal Screens
│   │   │   ├── DoctorMainView.swift         # Doctor TabView shell
│   │   │   ├── DoctorHomeView.swift         # Clinical dashboard, triage alerts & metrics
│   │   │   ├── DoctorPatientsView.swift     # Patient roster, status filter & search
│   │   │   ├── DoctorPatientDetailView.swift# Deep clinical history, uroflow curves & notes
│   │   │   ├── DoctorProfileView.swift      # Clinician bio, hospital affiliation & settings
│   │   │   ├── SurgeryLogView.swift         # OR schedule & surgical procedures log
│   │   │   ├── StockInventoryView.swift     # Medical supply & catheter inventory tracker
│   │   │   ├── FollowUpRemindersView.swift  # Post-operative recall & appointment reminders
│   │   │   └── WriteFeedbackView.swift      # Clinical report & patient feedback publisher
│   │   │
│   │   └── Components/                      # Shared Reusable Widgets
│   │       ├── SharedComponents.swift       # Aura-style glass cards, badges, buttons, inputs
│   │       └── UroflowGraphView.swift       # High-performance diagnostic flow curve chart
│   │
│   └── Assets.xcassets/                     # App Icons, Splash Graphics, Color Tokens
│
├── backend/                                 # Flask REST API Backend
│   ├── README.md                            # Comprehensive backend step-by-step documentation
│   ├── app.py                               # Flask server entry point (warm-loads ML model)
│   ├── config.py                            # MySQL, host, port, and JWT configurations
│   ├── db.py                                # MySQL connection pool & dict cursor helpers
│   ├── ml_inference_service.py              # ML bridge resolving models & computing curves
│   ├── schema.sql                           # MySQL database schema (tables, foreign keys, indexes)
│   ├── requirements.txt                     # Backend Python package dependencies
│   ├── start.sh                             # Robust startup script with venv & port checks
│   ├── routes/                              # Modular Blueprint Handlers
│   │   ├── __init__.py                      # Package initialization
│   │   ├── ai_flow.py                       # ML Acoustic Flow Inference endpoint
│   │   ├── auth.py                          # User Authentication & JWT session issuing
│   │   ├── feedback.py                      # Doctor clinical notes & patient feedback
│   │   ├── fluid.py                         # Fluid intake logs & daily balances
│   │   ├── followup.py                      # Patient follow-up schedules & reminders
│   │   ├── measurements.py                  # Uroflowmetry session results & curve JSON
│   │   ├── messages.py                      # Real-time doctor-patient messaging
│   │   ├── profile.py                       # User profile updates & clinician linkage
│   │   ├── stock.py                         # Hospital inventory & medical supplies
│   │   └── surgery.py                       # Surgical procedures & operative logs
│   ├── ml/                                  # Local Backend Copy of ML Assets
│   │   ├── models/                          # Serialized model & metadata
│   │   │   ├── acoustic_flow_model.joblib
│   │   │   └── model_metadata.json
│   │   └── outputs/
│   │       └── dataset_report.json
│   └── tests/                               # Backend Integration Tests
│       ├── __init__.py
│       └── test_ai_flow.py                  # 15 comprehensive unit & API integration tests
│
└── ml/                                      # Machine Learning Research & Training Pipeline
    ├── README.md                            # ML pipeline documentation
    ├── PHASE5_ML.md                         # Architecture, model selection & feature specs
    ├── requirements.txt                     # ML pipeline dependencies
    ├── features.py                          # Spectral & temporal audio feature extractor
    ├── prepare_dataset.py                   # Raw WAV audio session feature preprocessor
    ├── adapt_audio_flow_dataset.py          # Ground-truth flow rate dataset adapter
    ├── pre_training_validation.py           # Pre-training data quality & consistency auditor
    ├── validate_dataset.py                  # Final dataset schema & range validator
    ├── train.py                             # Random Forest regression training script
    ├── evaluate.py                          # Non-interactive Cross-Validation evaluator
    ├── inference.py                         # Standalone command-line inference utility
    ├── models/                              # Trained model artifacts
    │   ├── acoustic_flow_model.joblib       # Serialized Random Forest model
    │   └── model_metadata.json              # Version, feature names, hyperparameter metadata
    ├── datasets/                            # Training & synthetic session datasets
    │   └── sessions/
    ├── outputs/                             # Evaluation reports & predicted curves
    └── tests/                               # ML Pipeline Test Suite
        ├── __init__.py
        ├── test_pipeline.py                 # Feature extractor & model pipeline unit tests
        ├── test_end_to_end_fixture.py       # Autonomous synthetic WAV end-to-end test
        └── test_ios_models.swift            # Swift Codable contract test matching Python API
```

---

## Getting Started

### 1. Prerequisites
- **macOS** with **Xcode 16+** and Command Line Tools installed.
- **Python 3.10+** (Python 3.10, 3.11, or 3.14 virtual environments supported).
- **XAMPP** or standalone **MySQL** running on port `3306`.

### 2. Start MySQL Database
If using XAMPP:
1. Open XAMPP Control Panel or start MySQL via terminal:
   ```bash
   sudo /Applications/XAMPP/xamppfiles/bin/mysql.server start
   ```
2. Import the schema if starting fresh:
   ```bash
   mysql -u root -p urosonic < backend/schema.sql
   ```

### 3. Start Flask Backend
Run the resilient startup script from the repository root:
```bash
./backend/start.sh
```
The script will:
- Detect or create the virtual environment (`backend/venv`).
- Ensure all dependencies from `backend/requirements.txt` are installed.
- Check port `5001` and verify the MySQL connection.
- Pre-warm the Machine Learning model.
- Start the server at `http://127.0.0.1:5001`.

Verify the health check:
```bash
curl http://127.0.0.1:5001/health
```
Expected output:
```json
{
  "database": "connected",
  "ml_model": "loaded (v1.0.0)",
  "service": "urosonic-backend",
  "status": "healthy"
}
```

### 4. Build and Run the iOS Application
1. Open `Urosonic.xcodeproj` in Xcode:
   ```bash
   open Urosonic.xcodeproj
   ```
2. Select your desired simulator (e.g., **iPhone 16 Pro**) or a connected physical iOS device.
3. Press **Cmd + R** to run.
4. Or compile via terminal:
   ```bash
   xcodebuild -project Urosonic.xcodeproj -scheme Urosonic -destination "generic/platform=iOS Simulator" -configuration Debug build
   ```

---

## Machine Learning Pipeline

### Feature Extraction
The ML model consumes 17 acoustic features per 100ms audio frame:
- **13 MFCCs** (Mel-Frequency Cepstral Coefficients)
- **Spectral Centroid** ($Hz$)
- **Spectral Rolloff** ($Hz$, 85% energy threshold)
- **RMS Energy** (Root Mean Square amplitude)
- **Zero-Crossing Rate (ZCR)**

### Retraining the Model
To re-train the model with new acoustic recordings:
```bash
python3 ml/prepare_dataset.py
python3 ml/train.py --data ml/datasets/acoustic_flow_dataset.csv --output ml/models/
```
The training script will regenerate `acoustic_flow_model.joblib` and `model_metadata.json`. Copy these to `backend/ml/models/` for backend deployment.

---

## Running Automated Tests

### Backend Unit & Integration Tests (15 tests)
```bash
cd backend
python3 -m pytest tests/test_ai_flow.py -v
```

### ML Pipeline Tests (14 tests)
```bash
python3 -m unittest ml/tests/test_pipeline.py ml/tests/test_end_to_end_fixture.py
```

### iOS Data Model Swift Contract Tests (18 tests)
```bash
swift ml/tests/test_ios_models.swift
```
All test suites must pass 100% green before creating a release.

# Urosonic ML — Phase 5 Acoustic-to-Flow Pipeline

Offline Python machine learning pipeline that learns the relationship:
$$\text{Real Acoustic Features} \longrightarrow \text{ML Regression Model} \longrightarrow \text{Estimated Flow Rate (mL/s)}$$

---

## 1. Directory Layout

```
ml/
├── README.md               # User guide and execution commands
├── PHASE5_ML.md            # Comprehensive scientific and architectural documentation
├── requirements.txt        # Python package dependencies
├── features.py             # Feature configuration, extraction, per-session windowing, and scaler
├── prepare_dataset.py      # Ingest, validate, and audit Phase 4 exported CSV datasets
├── validate_dataset.py     # Session-level partitioning and strict data leakage enforcement
├── train.py                # Model training orchestrator and baseline selection
├── evaluate.py             # Evaluation on completely held-out test sessions
├── inference.py            # Deterministic offline inference engine
├── tests/
│   └── test_pipeline.py    # Comprehensive unit test suite with synthetic fixtures
├── datasets/               # Target directory for exported Phase 4 calibration sessions
├── models/                 # Serialized model artifacts (.joblib and model_metadata.json)
└── outputs/                # Dataset reports, evaluation metrics, and plots
```

---

## 2. Requirements & Setup

Ensure Python 3.10+ is available:
```bash
python3 -m pip install -r ml/requirements.txt
```

---

## 3. Pipeline Execution Commands

### Step 1: Run Unit Tests (Verifies Pipeline Software Correctness)
```bash
python3 ml/tests/test_pipeline.py
```
*Executes all unit tests using synthetic test fixtures to verify data parsing, windowing, leakage checking, model training, persistence, and inference.*

### Step 2: Audit Exported Calibration Data
```bash
python3 ml/prepare_dataset.py --dataset-dir ml/datasets
```
*Scans the dataset directory, inspects per-frame flow curves vs volume-only sessions, and writes `ml/outputs/dataset_report.json`.*

### Step 3: Run Model Training
```bash
python3 ml/train.py --dataset-dir ml/datasets --output-dir ml/models
```
*If sufficient real paired calibration sessions exist, trains `RandomForestRegressor` and `GradientBoostingRegressor`, selects the best model using the validation partition, and saves artifacts.*  
*If insufficient real paired calibration data exists, safely halts and reports:*
```text
Insufficient paired acoustic/ground-truth data for supervised ML training.
```

### Step 4: Evaluate on Held-Out Test Sessions
```bash
python3 ml/evaluate.py --model-artifact ml/models/acoustic_flow_model.joblib --dataset-dir ml/datasets
```
*Computes frame-level MAE, RMSE, R², and session-level Qmax/average flow/integrated volume errors, generating plots in `ml/outputs/`.*

### Step 5: Run Deterministic Inference
```bash
python3 ml/inference.py --features-csv path/to/acoustic_features.csv --output-csv ml/outputs/predicted_flow.csv --smooth
```
*Produces estimated flow curve points (`timestamp`, `predicted_flow_ml_s`, optional `smoothed_flow_ml_s`).*

---

## 4. Scientific Principles & Safeguards

1. **No Synthetic Training Data**: The pipeline will never manufacture artificial flow curves or convert volume-only sessions into fake per-frame flow values.
2. **Session-Level Splitting**: Individual frames or overlapping temporal windows are never randomly split. Partitions occur at the whole-session or whole-subject level.
3. **Data Leakage Check**: Training halts with a fatal error if any session ID or subject ID overlaps across train, validation, or test partitions.
4. **Test Set Isolation**: The test partition is never touched during feature engineering, hyperparameter tuning, or model selection.
5. **Non-Negative Post-Processing**: Negative flow regression outputs are clipped to `0.0 mL/s` as a physical constraint.

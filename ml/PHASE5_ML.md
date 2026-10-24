# PHASE 5 — ACOUSTIC-TO-FLOW MACHINE LEARNING PIPELINE

> **IMPORTANT CLINICAL & SCIENTIFIC DISCLAIMER**
> **This is a research and engineering pipeline.**
> The machine-learning models developed herein estimate flow rate ($\text{mL/s}$) from acoustic emissions. They are **NOT** clinically validated, medical-grade, or diagnostic instruments. The model outputs must strictly be designated as **"Estimated Flow Rate"** and cannot replace certified clinical uroflowmetry equipment.

---

## 1. Objective & Relationship

The primary objective of Phase 5 is to establish an offline, reproducible machine learning pipeline that learns the physical transfer function:

$$\text{Real Acoustic Features } \mathbf{X}(t) \xrightarrow{\quad f_{\theta}\quad} \text{Estimated Urinary Flow Rate } \hat{\dot{V}}(t)\quad (\text{mL/s})$$

### Core Scientific Principles:
- **Empirical Learning Only**: The model does **NOT** assume that acoustic amplitude ($\text{dBFS}$) or dominant frequency directly equals $\text{mL/s}$.
- **No Handcrafted Mathematical Formulas**: No arbitrary Gaussian, polynomial, or synthetic curves are substituted for physical measurements.
- **Ground-Truth Rigor**: Training requires paired acoustic frames with independent, physical reference uroflow measurements (from calibrated laboratory uroflowmeters or precision gravimetric sensors).
- **Volume-Only Exclusion**: Sessions with only total volume and total duration are strictly excluded from per-frame supervised training targets.

---

## 2. Current Calibration Dataset Status

An automated audit of the exported calibration directory was executed:
```bash
python3 ml/prepare_dataset.py --dataset-dir ml/datasets
```
**Audit Output Summary (`ml/outputs/dataset_report.json`)**:
- Total Sessions: `153` (150 active flow sessions + 3 baseline silence recordings)
- Valid Sessions: `153` (100% integrity, 0 errors)
- Sessions with Per-Frame Ground-Truth Flow Curves: `153`
- Volume-Only Sessions: `0`
- Total Synchronized Paired Samples: `840,572` frames
- Distinct Devices: `3` (Oppo: 51, Phone: 51, Ultramic: 51)
- Flow Rate Range: `0.0 to 50.0 mL/s` (Mean: `25.25 mL/s`)
- Supervised Training Ready: `True`

### Pre-Training Validation Status (`ml/outputs/pre_training_validation.json`):
- **Session Classification**: 150 active flow sessions (1–50 mL/s) + 3 zero-flow baseline silence recordings (30s at 0 mL/s) across Phone, Oppo, and Ultramic.
- **Stratified Session Split**: 108 Train sessions (mean 25.45 mL/s), 30 Validation sessions (mean 25.63 mL/s), 15 Test sessions (mean 25.60 mL/s). Balanced representation across devices and flow rates.
- **Data Leakage Check**: $\text{Train} \cap \text{Val} = \emptyset$, $\text{Train} \cap \text{Test} = \emptyset$, $\text{Val} \cap \text{Test} = \emptyset$. Zero session overlap.
- **Nyquist Verification**: Dominant frequencies and spectral centroids strictly bounded within device Nyquist frequencies (44.1 kHz $\to$ 22.05 kHz, 48 kHz $\to$ 24 kHz, 192 kHz $\to$ 96 kHz).
- **Temporal Durations**: 1024 samples corresponds to 23.22 ms on Oppo (43.07 fps), 21.33 ms on Phone (46.88 fps), and 5.33 ms on Ultramic (187.5 fps).
- **Scaler Isolation**: Fitted exclusively on training partition; validation and test partitions strictly transformed.
- **Status**: `READY_FOR_TRAINING: true` (model training deferred per explicit user instruction).

---

## 3. Feature Engineering & Temporal Context

### Base Acoustic Features (Extracted in Real-Time by Phase 2 DSP):
1. `rms` (Float): Root Mean Square linear signal amplitude.
2. `peak` (Float): Peak absolute signal amplitude.
3. `dbfs` (Float): Decibels relative to full scale: $20 \log_{10}(\text{RMS} + \epsilon)$.
4. `dominant_frequency` (Float): Peak energy bin in 2048-point Hann FFT ($\text{Hz}$).
5. `spectral_centroid` (Float): Center-of-mass frequency of power spectrum ($\text{Hz}$).
6. `spectral_energy` (Float): Total spectral power density.

### Temporal Windowing (`ml/features.py`):
Acoustic impact dynamics depend on short-term surface turbulence and fluid accumulation. The pipeline constructs a multi-frame temporal context:
- **Lag Features**: Current frame $t$ plus $N$ preceding frames $(t-1, \dots, t-N)$. Default $N=3$ frames ($\sim 70\text{ ms}$ at 1024 frames / 44.1 kHz).
- **Rolling Statistics**: Rolling mean and rolling variance computed over the temporal window.
- **Spectral Dynamics**: Frame-to-frame change rates ($\Delta \text{Centroid}$, $\Delta \text{Energy}$, $\Delta \text{dBFS}$).
- **Boundary Guarantee**: Temporal windows are created **STRICTLY per-session**. Features never cross session boundaries.

---

## 4. Session-Level Partitioning & Data Leakage Prevention

To prevent catastrophic temporal data leakage, partitioning adheres to a strict protocol:

```
RAW RECORDING SESSIONS
         ↓
Group by Anonymized Subject ID (when subject IDs exist)
         ↓
Partition into Train (70%), Validation (15%), and Test (15%)
         ↓
Create Temporal Windows Strictly INSIDE Each Partition
         ↓
Fit Scaler ONLY on Training Partition Features
         ↓
Transform Validation and Test Features Using Training Scaler
         ↓
Train and Evaluate Models
```

### Mathematical Disjointness Checks (`ml/validate_dataset.py`):
```text
TRAIN ∩ VALIDATION = ∅
TRAIN ∩ TEST = ∅
VALIDATION ∩ TEST = ∅
```
The automated validation module enforces:
1. No `session_id` exists in multiple partitions.
2. No `subject_id` exists in multiple partitions.
3. Temporal windows never cross partition boundaries.
4. Scaler is fit solely on training data.
*Any violation triggers a fatal `DataLeakageError` that immediately terminates execution.*

---

## 5. Model Architecture & Selection

### Baseline 1: `RandomForestRegressor`
- **Description**: *"Strong non-linear baseline suitable for structured acoustic features."*
- Handles non-linear acoustics, threshold effects, and feature interactions without requiring large-scale deep learning datasets.
- Hyperparameters: `n_estimators=100`, `max_depth=12`, `min_samples_split=4`, `random_state=42`.

### Baseline 2: `GradientBoostingRegressor`
- Sequential boosted decision trees optimizing mean squared error.
- Hyperparameters: `n_estimators=100`, `max_depth=5`, `learning_rate=0.08`, `random_state=42`.

### Strict Test-Set Isolation:
Model comparison and hyperparameter selection occur **strictly on the validation partition**. The held-out test set is completely frozen and untouched until final frozen-model evaluation.

---

## 6. Evaluation Framework & Metrics

Model evaluation (`ml/evaluate.py`) operates across two distinct analytical levels:

### 1. Frame-Level Metrics:
- **MAE** (Mean Absolute Error): $\frac{1}{M}\sum |\hat{y}_i - y_i|\quad (\text{mL/s})$
- **RMSE** (Root Mean Squared Error): $\sqrt{\frac{1}{M}\sum (\hat{y}_i - y_i)^2}\quad (\text{mL/s})$
- **$R^2$** (Coefficient of Determination): Proportion of variance explained by acoustic features.

### 2. Session-Level Clinical Metrics:
- **$Q_{\max}$ Error**: Peak reference flow vs peak predicted flow ($|Q_{\max}^{\text{pred}} - Q_{\max}^{\text{true}}|$).
- **Average Flow Error**: Mean reference flow vs mean predicted flow.
- **Integrated Voided Volume Error**:
  $$\text{Volume} \approx \sum_{i=1}^{T-1} \frac{\text{Flow}(t_i) + \text{Flow}(t_{i+1})}{2} \cdot (t_{i+1} - t_i)$$
  Calculated using trapezoidal integration over actual timestamps (not assuming a constant sampling rate).

### Non-Negative Physical Post-Processing:
Flow rates are physically non-negative during unidirectional voiding:
$$\hat{\dot{V}}_{\text{final}}(t) = \max(0.0, \hat{\dot{V}}_{\text{raw}}(t))$$
*Documented constraint: non-negative clipping is a post-processing heuristic, not proof of model precision.*

---

## 7. Model Artifact & Metadata Persistence

Trained models are packaged in a self-contained bundle:
- **Artifact**: `ml/models/acoustic_flow_model.joblib`
  - Serialized scikit-learn model object
  - Serialized `FeaturePipeline` state (configuration and fitted `StandardScaler`)
- **Metadata**: `ml/models/model_metadata.json`
  - `model_version`, `model_type`, `model_description`
  - `feature_names`, `temporal_window_size`, `scaler_type`
  - `hyperparameters`, `random_seed`
  - `training_session_ids`, `validation_session_ids`, `test_session_ids`
  - `training_metrics`, `validation_metrics`, `training_timestamp`

---

## 8. Offline Inference Pipeline (`ml/inference.py`)

Standalone deterministic inference:
```bash
python3 ml/inference.py \
  --features-csv path/to/acoustic_features.csv \
  --model-artifact ml/models/acoustic_flow_model.joblib \
  --output-csv ml/outputs/predicted_flow.csv \
  --smooth
```
- Ingests chronological acoustic frame features.
- Applies saved training scaler and temporal window transformations.
- Produces `PredictedFlowPoint(timestamp, flow_rate_ml_per_s)`.
- Preserves raw regression estimates alongside optional moving median smoothed estimates.

---

## 9. Core ML Preparation Status

- **Status**: **Prepared for Future Export (Deferred)**.
- Scikit-learn tree ensembles (`RandomForestRegressor`, `GradientBoostingRegressor`) can be converted to Core ML `.mlmodel` via `coremltools.converters.sklearn.convert`.
- **Deliberate Decision**: Core ML conversion is deferred until a model is trained and validated on genuine physical calibration recordings. Integrating an unvalidated model into the iOS application would violate clinical engineering safety standards.

---

## 10. Summary of Unit Testing

Automated test suite (`ml/tests/test_pipeline.py`) covers:
1. RFC 4180 CSV parsing
2. Missing-target dropping without zero-filling
3. Volume-only session rejection
4. Session-level splitting disjointness
5. Subject-level grouping isolation
6. Data leakage detection and fatal error raising
7. Temporal window shape and feature dimensions
8. Training scaler fitting and isolated test transformation
9. Model training using synthetic UNIT TEST FIXTURES
10. Model bundle serialization and deserialization
11. Deterministic inference execution
12. Non-negative flow clipping
13. Empty dataset graceful handling
14. Trapezoidal volume integration accuracy

*All 12 test suites execute in $< 0.2\text{ s}$ and pass cleanly.*

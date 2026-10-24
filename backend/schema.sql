-- =============================================================
-- Urosonic Database Schema
-- Run this in phpMyAdmin or via MySQL CLI with XAMPP running
-- =============================================================

CREATE DATABASE IF NOT EXISTS urosonic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE urosonic;

-- ─────────────────────────────────────────────
-- USERS (shared: patients & doctors)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('patient','doctor') NOT NULL DEFAULT 'patient',
    -- doctor-only
    license_number VARCHAR(50),
    specialization VARCHAR(100),
    -- patient-only (assigned doctor)
    doctor_id     INT,
    -- profile
    avatar_initials VARCHAR(5),
    age           INT,
    gender        VARCHAR(20),
    `condition`   VARCHAR(200),
    is_active     TINYINT(1) DEFAULT 1,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- PASSWORD RESET TOKENS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    token      VARCHAR(100) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    used       TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- UROFLOW MEASUREMENTS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS measurements (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    patient_id  INT NOT NULL,
    qmax        DECIMAL(6,2) NOT NULL,   -- mL/s
    avg_flow    DECIMAL(6,2),
    volume      INT NOT NULL,            -- mL
    void_time   INT NOT NULL,            -- seconds
    status      ENUM('NORMAL','BORDERLINE','ABNORMAL') DEFAULT 'NORMAL',
    notes       TEXT,
    flow_curve_json LONGTEXT,
    recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- DOCTOR FEEDBACK on Measurements
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feedback (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    measurement_id  INT NOT NULL,
    doctor_id       INT NOT NULL,
    patient_id      INT NOT NULL,
    interpretation  ENUM('Normal','Borderline','Abnormal','Needs Follow-up') NOT NULL,
    clinical_notes  TEXT NOT NULL,
    prescription    TEXT,
    follow_up_date  DATE,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (measurement_id) REFERENCES measurements(id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id)      REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id)     REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- FLUID LOG
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fluid_logs (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    drink_type ENUM('Water','Coffee','Juice','Other') DEFAULT 'Water',
    volume_ml  INT NOT NULL,
    logged_at  VARCHAR(50),             -- stored as "9:30 AM" string
    log_date   DATE,                    -- app layer sets this to today; MySQL 5.7 compatible
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- URINE OUTPUT LOG (Fluid Voiding & Output)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS urine_output_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    patient_id  INT NOT NULL,
    volume_ml   INT NOT NULL,
    urgency     VARCHAR(50) DEFAULT 'Normal',
    color       VARCHAR(50) DEFAULT 'Pale Yellow',
    source      VARCHAR(50) DEFAULT 'Manual',
    logged_at   VARCHAR(50),             -- stored as "11:45 AM"
    log_date    DATE,
    notes       TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- MESSAGES
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    sender_id   INT NOT NULL,
    receiver_id INT NOT NULL,
    message     TEXT NOT NULL,
    is_read     TINYINT(1) DEFAULT 0,
    sent_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id)   REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- STOCK INVENTORY
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_items (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id   INT NOT NULL,
    name        VARCHAR(150) NOT NULL,
    category    VARCHAR(100) DEFAULT 'Medical Supplies',
    current_qty INT NOT NULL DEFAULT 0,
    threshold   INT NOT NULL DEFAULT 10,
    unit        VARCHAR(50) DEFAULT 'units',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- SURGERY LOG
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS surgery_records (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id             INT NOT NULL,
    surgery_date          DATE NOT NULL,
    hospital              VARCHAR(200),
    my_role               VARCHAR(100) DEFAULT 'Primary Surgeon',
    patient_name          VARCHAR(100) NOT NULL,
    patient_id_ref        VARCHAR(50),
    phone_number          VARCHAR(30),
    surgery_type          VARCHAR(200) NOT NULL,
    diagnoses             TEXT,             -- JSON array stored as text
    professional_fees     INT DEFAULT 0,
    instrument_charges    INT DEFAULT 0,
    payment_status        ENUM('Paid','Pending','Partial') DEFAULT 'Pending',
    consumables           TEXT,             -- JSON array
    rental_name           VARCHAR(150),
    rental_fees           INT DEFAULT 0,
    stent_type            VARCHAR(100),
    stent_due_date        DATE,
    stent_status          ENUM('In Place','Removed','N/A') DEFAULT 'N/A',
    remarks               TEXT,
    created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- SURGERY TEAM MEMBERS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS surgery_team (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    surgery_id     INT NOT NULL,
    role           VARCHAR(100),
    member_name    VARCHAR(100),
    fees           INT DEFAULT 0,
    payment_status ENUM('Paid','Pending','Partial') DEFAULT 'Pending',
    FOREIGN KEY (surgery_id) REFERENCES surgery_records(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- FOLLOW-UP REMINDERS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS follow_ups (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id   INT NOT NULL,
    patient_id  INT NOT NULL,
    due_date    DATE NOT NULL,
    status      ENUM('UPCOMING','DUE','OVERDUE','COMPLETED') DEFAULT 'UPCOMING',
    notes       TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id)  REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- SAMPLE SEED DATA (optional — for testing)
-- Use POST /auth/register to generate real bcrypt-hashed users.
-- ─────────────────────────────────────────────
-- Example (run /auth/register with these bodies to create real accounts):
--   { "full_name": "Dr. Kumar",   "email": "dr.kumar@urosonic.com",  "password": "Test@1234", "role": "doctor", "license_number": "MCI-12345", "specialization": "Urology" }
--   { "full_name": "Rajan Kumar", "email": "rajan@example.com",       "password": "Test@1234", "role": "patient", "age": 58, "gender": "Male" }

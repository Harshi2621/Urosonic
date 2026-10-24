"""
validate_dataset.py - Session-Level Partitioning and Data Leakage Validation
===========================================================================
Part of Urosonic Phase 5 (Acoustic-to-Flow Machine Learning Pipeline).

Strict Rules Enforced:
1. SESSIONS (or SUBJECTS) are partitioned FIRST before any windowing or feature extraction.
2. TRAIN ∩ VALIDATION = EMPTY, TRAIN ∩ TEST = EMPTY, VALIDATION ∩ TEST = EMPTY.
3. No session ID or subject ID may appear in more than one partition.
4. Temporal context windows are constructed strictly INSIDE each partition.
5. Scaler is fit ONLY on the training partition.
"""

from __future__ import annotations
from typing import Any, Dict, List, Optional, Set, Tuple
import numpy as np
from prepare_dataset import SessionData


class DataLeakageError(Exception):
    """Raised when data leakage between train, validation, or test partitions is detected."""
    pass


def check_data_leakage(
    train_sessions: List[SessionData],
    val_sessions: List[SessionData],
    test_sessions: List[SessionData]
) -> Dict[str, Any]:
    """
    Assert complete mathematical isolation between train, validation, and test partitions.
    
    Verifies:
    1. Session ID disjointness.
    2. Subject ID disjointness (if subject IDs exist).
    
    Raises:
        DataLeakageError if any session ID or subject ID is shared across partitions.
    """
    train_sids: Set[str] = {s.session_id for s in train_sessions}
    val_sids: Set[str] = {s.session_id for s in val_sessions}
    test_sids: Set[str] = {s.session_id for s in test_sessions}

    # 1. Session ID overlaps
    train_val_overlap = train_sids.intersection(val_sids)
    train_test_overlap = train_sids.intersection(test_sids)
    val_test_overlap = val_sids.intersection(test_sids)

    if train_val_overlap:
        raise DataLeakageError(f"CRITICAL LEAKAGE: Session IDs present in both TRAIN and VALIDATION: {train_val_overlap}")
    if train_test_overlap:
        raise DataLeakageError(f"CRITICAL LEAKAGE: Session IDs present in both TRAIN and TEST: {train_test_overlap}")
    if val_test_overlap:
        raise DataLeakageError(f"CRITICAL LEAKAGE: Session IDs present in both VALIDATION and TEST: {val_test_overlap}")

    # 2. Subject ID overlaps (where subject IDs are populated)
    train_subj: Set[str] = {s.subject_id for s in train_sessions if s.subject_id}
    val_subj: Set[str] = {s.subject_id for s in val_sessions if s.subject_id}
    test_subj: Set[str] = {s.subject_id for s in test_sessions if s.subject_id}

    train_val_subj_overlap = train_subj.intersection(val_subj)
    train_test_subj_overlap = train_subj.intersection(test_subj)
    val_test_subj_overlap = val_subj.intersection(test_subj)

    if train_val_subj_overlap:
        raise DataLeakageError(f"CRITICAL LEAKAGE: Subject IDs present in both TRAIN and VALIDATION: {train_val_subj_overlap}")
    if train_test_subj_overlap:
        raise DataLeakageError(f"CRITICAL LEAKAGE: Subject IDs present in both TRAIN and TEST: {train_test_subj_overlap}")
    if val_test_subj_overlap:
        raise DataLeakageError(f"CRITICAL LEAKAGE: Subject IDs present in both VALIDATION and TEST: {val_test_subj_overlap}")

    return {
        "is_leakage_free": True,
        "train_session_count": len(train_sids),
        "val_session_count": len(val_sids),
        "test_session_count": len(test_sids),
        "train_subject_count": len(train_subj),
        "val_subject_count": len(val_subj),
        "test_subject_count": len(test_subj)
    }


def split_sessions(
    sessions: List[SessionData],
    train_ratio: float = 0.70,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    random_seed: int = 42,
    stratify_by_flow: bool = True
) -> Tuple[List[SessionData], List[SessionData], List[SessionData]]:
    """
    Split sessions into Train, Validation, and Test partitions.
    
    Guarantees:
    1. Entire sessions remain in their respective partition (no frame-level bleeding).
    2. If anonymized subject IDs exist, all sessions of a subject stay in the same partition.
    3. If stratify_by_flow is True and multiple flow levels exist, stratification by
       (device, flow_rate_bin) ensures uniform flow-rate and device coverage across partitions.
    4. Enforces strict leakage check before returning.
    
    Args:
        sessions: List of SessionData objects to partition.
        train_ratio: Fraction for training (default 0.70).
        val_ratio: Fraction for validation (default 0.15).
        test_ratio: Fraction for testing (default 0.15).
        random_seed: Random seed for deterministic reproducibility.
        stratify_by_flow: Whether to stratify by (device, flow_bin) when available.
        
    Returns:
        (train_sessions, val_sessions, test_sessions)
    """
    if not sessions:
        return [], [], []

    rng = np.random.default_rng(random_seed)

    # Check if subject grouping is applicable
    has_subjects = any(s.subject_id for s in sessions)
    
    if has_subjects:
        # Group by subject ID (fall back to session_id if subject_id missing)
        subject_groups: Dict[str, List[SessionData]] = {}
        for s in sessions:
            key = s.subject_id if s.subject_id else f"session_{s.session_id}"
            if key not in subject_groups:
                subject_groups[key] = []
            subject_groups[key].append(s)

        distinct_keys = sorted(list(subject_groups.keys()))
        permuted_keys = rng.permutation(distinct_keys)

        n_total = len(permuted_keys)
        n_train = max(1, int(round(n_total * train_ratio))) if n_total >= 3 else 1
        n_val = max(1, int(round(n_total * val_ratio))) if n_total >= 3 else (1 if n_total == 2 else 0)
        
        train_keys = set(permuted_keys[:n_train])
        val_keys = set(permuted_keys[n_train : n_train + n_val])
        test_keys = set(permuted_keys[n_train + n_val:])

        # If test is empty due to small count, ensure distinct allocation
        if not test_keys and len(val_keys) > 1:
            moved = val_keys.pop()
            test_keys.add(moved)

        train_sessions = [s for k in train_keys for s in subject_groups[k]]
        val_sessions = [s for k in val_keys for s in subject_groups[k]]
        test_sessions = [s for k in test_keys for s in subject_groups[k]]
    elif stratify_by_flow and len(sessions) >= 10:
        # Stratify by (device, flow_bin) at the whole-session level
        strata: Dict[Tuple[str, str], List[SessionData]] = {}
        for s in sessions:
            dev = s.metadata_row.get("device_category", "default")
            flow_val_str = s.metadata_row.get("flow_rate_ml_s")
            if flow_val_str is not None and flow_val_str != "":
                try:
                    fl = float(flow_val_str)
                except ValueError:
                    fl = 0.0
            elif s.ground_truth_points:
                fl = s.ground_truth_points[0].get("flow_rate", 0.0)
            else:
                fl = 0.0

            if fl == 0:
                bin_lbl = "zero"
            elif fl <= 10:
                bin_lbl = "bin_1_10"
            elif fl <= 20:
                bin_lbl = "bin_11_20"
            elif fl <= 30:
                bin_lbl = "bin_21_30"
            elif fl <= 40:
                bin_lbl = "bin_31_40"
            else:
                bin_lbl = "bin_41_50"

            key = (dev, bin_lbl)
            if key not in strata:
                strata[key] = []
            strata[key].append(s)

        train_sessions = []
        val_sessions = []
        test_sessions = []

        for _, s_list in sorted(strata.items(), key=lambda x: str(x[0])):
            perm = rng.permutation(len(s_list))
            n = len(s_list)
            if n == 1:
                train_sessions.append(s_list[0])
                continue

            n_train = max(1, int(round(n * train_ratio)))
            n_val = max(1, int(round(n * val_ratio)))
            n_test = n - n_train - n_val
            if n_test < 1 and n >= 3:
                n_val = max(1, n_val - 1)
                n_test = 1

            t_idx = perm[:n_train]
            v_idx = perm[n_train:n_train + n_val]
            te_idx = perm[n_train + n_val:]

            train_sessions.extend([s_list[i] for i in t_idx])
            val_sessions.extend([s_list[i] for i in v_idx])
            test_sessions.extend([s_list[i] for i in te_idx])
    else:
        # Session-level permutation
        permuted_indices = rng.permutation(len(sessions))
        n_total = len(sessions)
        
        if n_total == 1:
            return [sessions[0]], [], []
        elif n_total == 2:
            return [sessions[permuted_indices[0]]], [sessions[permuted_indices[1]]], []
            
        n_train = max(1, int(round(n_total * train_ratio)))
        n_val = max(1, int(round(n_total * val_ratio)))
        
        train_indices = permuted_indices[:n_train]
        val_indices = permuted_indices[n_train : n_train + n_val]
        test_indices = permuted_indices[n_train + n_val:]
        
        train_sessions = [sessions[i] for i in train_indices]
        val_sessions = [sessions[i] for i in val_indices]
        test_sessions = [sessions[i] for i in test_indices]

    # Run mandatory leakage check before returning
    check_data_leakage(train_sessions, val_sessions, test_sessions)

    return train_sessions, val_sessions, test_sessions

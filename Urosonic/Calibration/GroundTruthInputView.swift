// GroundTruthInputView.swift
// Urosonic — Ground-Truth Flow Measurement Entry & Validation Form

import SwiftUI

struct GroundTruthInputView: View {
    let session: CalibrationSession
    let onSave: (GroundTruthFlowSession) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: GroundTruthMethod = .controlledContainer
    @State private var totalVolumeText: String = ""
    @State private var startTimeText: String = "0.0"
    @State private var endTimeText: String = ""
    @State private var operatorName: String = ""
    @State private var equipmentModel: String = ""
    @State private var notes: String = ""

    // Optional point-by-point flow rate samples
    @State private var flowPoints: [GroundTruthFlowPoint] = []
    @State private var newPointTimeText: String = ""
    @State private var newPointRateText: String = ""

    @State private var validationError: String? = nil

    init(session: CalibrationSession, onSave: @escaping (GroundTruthFlowSession) -> Void) {
        self.session = session
        self.onSave = onSave

        if let existing = session.groundTruth {
            _selectedMethod = State(initialValue: existing.method)
            _totalVolumeText = State(initialValue: String(format: "%.1f", existing.totalVolumeML))
            _startTimeText = State(initialValue: String(format: "%.2f", existing.startTime))
            _endTimeText = State(initialValue: String(format: "%.2f", existing.endTime))
            _operatorName = State(initialValue: existing.measuredBy ?? "")
            _equipmentModel = State(initialValue: existing.equipmentModel ?? "")
            _notes = State(initialValue: existing.notes ?? "")
            _flowPoints = State(initialValue: existing.flowPoints)
        } else {
            // Pre-fill default suggested timing from detected acoustic event
            let suggestedStart = session.eventStartTime ?? 0.0
            let suggestedEnd = session.eventEndTime ?? session.eventDuration ?? 10.0
            _startTimeText = State(initialValue: String(format: "%.2f", suggestedStart))
            _endTimeText = State(initialValue: String(format: "%.2f", suggestedEnd))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Measurement Method
                Section(header: Text("Independent Measurement Method")) {
                    Picker("Method", selection: $selectedMethod) {
                        ForEach(GroundTruthMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Equipment / Instrument Model", text: $equipmentModel)
                    TextField("Operator Name / Researcher", text: $operatorName)
                }

                // Section 2: Volumetric & Timing Ground Truth
                Section(
                    header: Text("Volumetric Ground Truth"),
                    footer: Text("Total volume and duration must be measured independently using calibrated physical scales or clinical reference meters.")
                ) {
                    HStack {
                        Text("Total Volume")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        TextField("e.g. 350", text: $totalVolumeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Text("mL")
                            .font(.system(size: 13))
                            .foregroundColor(.slateSub)
                    }

                    HStack {
                        Text("Start Time (t = 0 is recording start)")
                            .font(.system(size: 13))
                        Spacer()
                        TextField("0.0", text: $startTimeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 13, design: .monospaced))
                        Text("s")
                            .font(.system(size: 13))
                            .foregroundColor(.slateSub)
                    }

                    HStack {
                        Text("End Time")
                            .font(.system(size: 13))
                        Spacer()
                        TextField("e.g. 14.5", text: $endTimeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 13, design: .monospaced))
                        Text("s")
                            .font(.system(size: 13))
                            .foregroundColor(.slateSub)
                    }

                    if let st = Double(startTimeText), let et = Double(endTimeText), et > st {
                        HStack {
                            Text("Calculated Duration")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(String(format: "%.2f seconds", et - st))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.appTeal)
                        }
                    }
                }

                // Section 3: Point-by-point Flow Curve (Optional)
                Section(
                    header: Text("Point-by-Point Reference Flow Rate (Optional)"),
                    footer: Text("Add discrete flow rate samples (mL/s) if recorded by a reference digital uroflowmeter.")
                ) {
                    HStack(spacing: 8) {
                        TextField("Time (s)", text: $newPointTimeText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        TextField("Flow (mL/s)", text: $newPointRateText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            addFlowPoint()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.appTeal)
                    }

                    if flowPoints.isEmpty {
                        Text("No discrete flow points added (Session-level ground truth only).")
                            .font(.system(size: 12))
                            .foregroundColor(.slateSub)
                    } else {
                        ForEach(flowPoints.sorted(by: { $0.timestamp < $1.timestamp })) { pt in
                            HStack {
                                Text(String(format: "t = %.2f s", pt.timestamp))
                                    .font(.system(size: 13, design: .monospaced))
                                Spacer()
                                Text(String(format: "%.1f mL/s", pt.flowRateMLPerSecond))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.appTeal)
                            }
                        }
                        .onDelete(perform: deleteFlowPoint)
                    }
                }

                // Section 4: Notes & Validation Errors
                if let error = validationError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                    }
                }

                Section(header: Text("Research Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 70)
                }
            }
            .navigationTitle("Ground-Truth Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { validateAndSave() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func addFlowPoint() {
        guard let t = Double(newPointTimeText), let rate = Double(newPointRateText) else { return }
        guard t >= 0, rate >= 0 else { return }
        flowPoints.append(GroundTruthFlowPoint(timestamp: t, flowRateMLPerSecond: rate))
        flowPoints.sort(by: { $0.timestamp < $1.timestamp })
        newPointTimeText = ""
        newPointRateText = ""
    }

    private func deleteFlowPoint(at offsets: IndexSet) {
        flowPoints.remove(atOffsets: offsets)
    }

    private func validateAndSave() {
        guard let vol = Double(totalVolumeText), vol > 0 else {
            validationError = "Total volume must be a valid positive number greater than 0 mL."
            return
        }
        guard let st = Double(startTimeText), let et = Double(endTimeText), et > st else {
            validationError = "End time must be greater than start time."
            return
        }

        // Validate flow points monotonicity
        var prevT: TimeInterval = -1
        for pt in flowPoints {
            if pt.timestamp < prevT {
                validationError = "Flow point timestamps must be monotonically non-decreasing."
                return
            }
            if pt.flowRateMLPerSecond < 0 {
                validationError = "Flow rate values cannot be negative."
                return
            }
            prevT = pt.timestamp
        }

        let gtSession = GroundTruthFlowSession(
            calibrationSessionId: session.id,
            method: selectedMethod,
            totalVolumeML: vol,
            startTime: st,
            endTime: et,
            flowPoints: flowPoints,
            measuredBy: operatorName.isEmpty ? nil : operatorName,
            equipmentModel: equipmentModel.isEmpty ? nil : equipmentModel,
            notes: notes.isEmpty ? nil : notes
        )

        onSave(gtSession)
        dismiss()
    }
}

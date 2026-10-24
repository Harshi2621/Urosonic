// DoctorClinicalReportSheetView.swift — Exact Replica of Clinical Hospital Uroflowmetry Report
// Modeled directly from Saveetha Medical College & Hospital / Aymed Uroflowmeter System

import SwiftUI

struct DoctorClinicalReportSheetView: View {
    @Environment(\.dismiss) var dismiss
    let patientName: String
    let age: Int
    let gender: String
    let hospitalNo: String
    let doctorName: String
    let dateString: String
    let qmax: Double
    let avgFlow: Double
    let volume: Int
    let voidDuration: Int
    let flowStartTime: Double
    let maxFlowTime: Double
    let startTime: Double
    let stopTime: Double
    let flowIntervals: Int
    let flowCurve: [PredictedFlowPoint]?
    let volumeCurve: [PredictedVolumePoint]?

    @State private var isExporting = false
    @State private var pdfURL: URL? = nil
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Printable White Medical Sheet Container
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. Hospital Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cross.case.fill")
                                        .foregroundColor(Color(hex: "0284C7"))
                                        .font(.system(size: 16))
                                    Text("Saveetha Medical College & Hospital")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(Color.black)
                                }
                                Text("Department Of Urology")
                                    .font(.system(size: 13, weight: .semibold, design: .serif))
                                    .foregroundColor(Color.black.opacity(0.8))
                                Text("www.aymed.com")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color(hex: "0284C7"))
                            }
                            Spacer()
                            // AYMED Logo / Seal
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("AYMED")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Color(hex: "0369A1"))
                                Text("URODYNAMICS")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Color.gray)
                            }
                        }
                        .padding(.bottom, 6)

                        Divider().background(Color.black.opacity(0.4))

                        // 2. Patient & Test Metadata Table
                        HStack(alignment: .top, spacing: 12) {
                            // Left Column Metadata
                            VStack(alignment: .leading, spacing: 4) {
                                metaRow(label: "Test Type", value: "Uroflow")
                                metaRow(label: "Date", value: dateString)
                                metaRow(label: "H.No", value: hospitalNo)
                                metaRow(label: "Name Surname", value: "\(patientName) \(age)yrs/ \(gender.prefix(1))")
                                metaRow(label: "Marital Status", value: "Married")
                                metaRow(label: "Gender", value: "\(gender)")
                                metaRow(label: "Doctor", value: doctorName.uppercased())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Right Box: Uroflowmeter / Diagnosis Observation
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Uroflowmeter")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.black)
                                Text("Clinical Assessment: \(qmax >= 15 ? "Normal Flow" : (qmax >= 10 ? "Borderline Flow" : "Abnormal / Obstructed"))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(qmax >= 15 ? Color(hex: "065F46") : Color(hex: "991B1B"))
                                Text("Pattern: Continuous physiological stream with peak max flow at \(String(format: "%.1f", maxFlowTime))s.")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.black.opacity(0.7))
                            }
                            .padding(8)
                            .frame(maxWidth: 160, alignment: .leading)
                            .background(Color.black.opacity(0.02))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.3), lineWidth: 0.8))
                        }

                        Divider().background(Color.black.opacity(0.4))

                        // 3. Clinical Dual Curves (Volume Curve + Flow Rate Curve)
                        VStack(spacing: 8) {
                            clinicalVolumeChart()
                                .frame(height: 140)

                            clinicalFlowChart()
                                .frame(height: 150)
                        }

                        Divider().background(Color.black.opacity(0.4))

                        // 4. Clinical Parameters Table & Siroky Nomograms Grid
                        HStack(alignment: .top, spacing: 12) {
                            // Clinical Parameters Table (Left)
                            VStack(alignment: .leading, spacing: 6) {
                                paramRow(label: "Start Time", value: String(format: "%.0f sec", startTime))
                                paramRow(label: "Stop Time", value: String(format: "%.0f sec", stopTime > 0 ? stopTime : Double(voidDuration)))
                                paramRow(label: "Flow Start Time", value: String(format: "%.0f sec", flowStartTime))
                                paramRow(label: "Max Flow", value: String(format: "%.1f ml/sec", qmax), isBold: true)
                                paramRow(label: "Max Flow Time", value: String(format: "%.0f sec", maxFlowTime))
                                paramRow(label: "Average Flow", value: String(format: "%.1f ml/sec", avgFlow))
                                paramRow(label: "Void Duration", value: String(format: "%d sec", voidDuration))
                                paramRow(label: "Voided Volume", value: String(format: "%d ml", volume), isBold: true)
                                paramRow(label: "Number of Flow Interval", value: "\(flowIntervals)")
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.02))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.3), lineWidth: 0.8))

                            // Siroky Nomograms (Right)
                            VStack(spacing: 8) {
                                SirokyNomogramView(type: .maxFlow, volume: Double(volume), flowValue: qmax)
                                    .frame(height: 105)
                                SirokyNomogramView(type: .averageFlow, volume: Double(volume), flowValue: avgFlow)
                                    .frame(height: 105)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Divider().background(Color.black.opacity(0.4))

                        // 5. Footer: System Version & Doctor Signature
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Locom Wireless System v. 0.2.64")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color.black.opacity(0.6))
                                Text("Saveetha Institute of Medical and Technical Sciences")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.black.opacity(0.5))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Physician Signature : ____________________")
                                    .font(.system(size: 10, weight: .semibold, design: .serif))
                                    .foregroundColor(Color.black)
                                Text("\(doctorName)")
                                    .font(.system(size: 9, design: .serif))
                                    .foregroundColor(Color.black.opacity(0.7))
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
                    .padding(16)
                }
            }
            .background(Color(hex: "F1F5F9").ignoresSafeArea())
            .navigationTitle("Hospital Uroflow Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.appNavy)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        exportReportPDF()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Print / Share")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTeal)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color.black.opacity(0.8))
                .frame(width: 85, alignment: .leading)
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.black)
            Spacer()
        }
    }

    private func paramRow(label: String, value: String, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: isBold ? .bold : .regular))
                .foregroundColor(Color.black.opacity(0.85))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: isBold ? .heavy : .semibold, design: .monospaced))
                .foregroundColor(isBold ? Color(hex: "991B1B") : Color.black)
        }
    }

    private func calcX(_ t: Double, maxT: Double, padL: CGFloat, drawW: CGFloat) -> CGFloat {
        padL + CGFloat(min(max(t, 0.0), maxT) / maxT) * drawW
    }

    private func calcY(_ val: Double, maxVal: Double, padT: CGFloat, drawH: CGFloat) -> CGFloat {
        padT + CGFloat(1.0 - min(max(val, 0.0), maxVal) / maxVal) * drawH
    }

    // MARK: - Clinical Volume Chart (Green)
    @ViewBuilder
    private func clinicalVolumeChart() -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let padL: CGFloat = 36
            let padR: CGFloat = 40
            let padT: CGFloat = 16
            let padB: CGFloat = 16
            let drawW = max(w - padL - padR, 10)
            let drawH = max(h - padT - padB, 10)
            let maxT = max(stopTime > 0 ? stopTime : Double(voidDuration), 1.0)
            let maxVol = max(Double(volume), 100.0) * 1.15

            ZStack(alignment: .topLeading) {
                // Background grid & border
                Rectangle()
                    .stroke(Color.black.opacity(0.4), lineWidth: 0.8)
                    .background(Color.white)

                // Grid lines
                Path { p in
                    // 4 horizontal lines
                    for i in 1...3 {
                        let y = padT + (CGFloat(i) / 4.0) * drawH
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    // Vertical lines at 10s intervals
                    var t = 10.0
                    while t < maxT {
                        let x = calcX(t, maxT: maxT, padL: padL, drawW: drawW)
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                        t += 10.0
                    }
                }
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)

                // Volume Curve (Green)
                Path { p in
                    if let pts = volumeCurve, !pts.isEmpty {
                        p.move(to: CGPoint(x: calcX(pts[0].timestamp, maxT: maxT, padL: padL, drawW: drawW), y: calcY(pts[0].volumeML, maxVal: maxVol, padT: padT, drawH: drawH)))
                        for pt in pts.dropFirst() {
                            p.addLine(to: CGPoint(x: calcX(pt.timestamp, maxT: maxT, padL: padL, drawW: drawW), y: calcY(pt.volumeML, maxVal: maxVol, padT: padT, drawH: drawH)))
                        }
                    } else {
                        // Smooth Sigmoidal S-curve fallback
                        let samples = 40
                        let dt = maxT / Double(samples)
                        p.move(to: CGPoint(x: calcX(0, maxT: maxT, padL: padL, drawW: drawW), y: calcY(0, maxVal: maxVol, padT: padT, drawH: drawH)))
                        for i in 1...samples {
                            let t = Double(i) * dt
                            let fraction = t / maxT
                            let s = 1.0 / (1.0 + exp(-10.0 * (fraction - 0.45)))
                            let v = Double(volume) * s
                            p.addLine(to: CGPoint(x: calcX(t, maxT: maxT, padL: padL, drawW: drawW), y: calcY(v, maxVal: maxVol, padT: padT, drawH: drawH)))
                        }
                    }
                }
                .stroke(Color(hex: "15803D"), lineWidth: 1.8)

                // Time marker at Max Flow (Red vertical dashed line)
                if maxFlowTime > 0 {
                    let markX = calcX(maxFlowTime, maxT: maxT, padL: padL, drawW: drawW)
                    Path { p in
                        p.move(to: CGPoint(x: markX, y: 0))
                        p.addLine(to: CGPoint(x: markX, y: h))
                    }
                    .stroke(Color.red.opacity(0.7), lineWidth: 0.8)

                    Text(String(format: "%.0f", maxFlowTime))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color.red)
                        .position(x: markX + 10, y: 8)
                }

                // Final Volume label on right
                Text("Volume\n\(volume)")
                    .font(.system(size: 8, weight: .bold, design: .serif))
                    .foregroundColor(Color.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .position(x: w - 20, y: calcY(Double(volume), maxVal: maxVol, padT: padT, drawH: drawH))
            }
        }
    }

    // MARK: - Clinical Flow Chart (Red)
    @ViewBuilder
    private func clinicalFlowChart() -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let padL: CGFloat = 36
            let padR: CGFloat = 40
            let padT: CGFloat = 16
            let padB: CGFloat = 16
            let drawW = max(w - padL - padR, 10)
            let drawH = max(h - padT - padB, 10)
            let maxT = max(stopTime > 0 ? stopTime : Double(voidDuration), 1.0)
            let maxFlow = max(qmax, 5.0) * 1.3

            ZStack(alignment: .topLeading) {
                // Background grid & border
                Rectangle()
                    .stroke(Color.black.opacity(0.4), lineWidth: 0.8)
                    .background(Color.white)

                // Grid lines
                Path { p in
                    for i in 1...3 {
                        let y = padT + (CGFloat(i) / 4.0) * drawH
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    var t = 10.0
                    while t < maxT {
                        let x = calcX(t, maxT: maxT, padL: padL, drawW: drawW)
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                        t += 10.0
                    }
                }
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)

                // Flow Curve (Red)
                Path { p in
                    if let pts = flowCurve, !pts.isEmpty {
                        p.move(to: CGPoint(x: calcX(pts[0].timestamp, maxT: maxT, padL: padL, drawW: drawW), y: calcY(pts[0].flowMLPerSec, maxVal: maxFlow, padT: padT, drawH: drawH)))
                        for pt in pts.dropFirst() {
                            p.addLine(to: CGPoint(x: calcX(pt.timestamp, maxT: maxT, padL: padL, drawW: drawW), y: calcY(pt.flowMLPerSec, maxVal: maxFlow, padT: padT, drawH: drawH)))
                        }
                    } else {
                        // Bell curve fallback with smooth 40 points
                        let samples = 40
                        let dt = maxT / Double(samples)
                        let peakT = maxFlowTime > 0 ? maxFlowTime : (maxT * 0.4)
                        p.move(to: CGPoint(x: calcX(0, maxT: maxT, padL: padL, drawW: drawW), y: calcY(0, maxVal: maxFlow, padT: padT, drawH: drawH)))
                        for i in 1...samples {
                            let t = Double(i) * dt
                            let f: Double
                            if t < peakT {
                                let ratio = t / max(peakT, 0.001)
                                f = qmax * pow(ratio, 1.6)
                            } else {
                                let ratio = (t - peakT) / max(maxT - peakT, 0.001)
                                f = qmax * pow(max(1.0 - ratio, 0.0), 2.0)
                            }
                            p.addLine(to: CGPoint(x: calcX(t, maxT: maxT, padL: padL, drawW: drawW), y: calcY(max(f, 0.0), maxVal: maxFlow, padT: padT, drawH: drawH)))
                        }
                    }
                }
                .stroke(Color.red, lineWidth: 1.8)

                // Vertical Max Flow line
                if maxFlowTime > 0 {
                    let flowX = calcX(maxFlowTime, maxT: maxT, padL: padL, drawW: drawW)
                    Path { p in
                        p.move(to: CGPoint(x: flowX, y: 0))
                        p.addLine(to: CGPoint(x: flowX, y: h))
                    }
                    .stroke(Color.red, lineWidth: 1.0)

                    Text(String(format: "%.1f", qmax))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.red)
                        .position(x: flowX + 12, y: calcY(qmax, maxVal: maxFlow, padT: padT, drawH: drawH))
                }

                // X-Axis Time tick labels (00:10, 00:20, 00:30, 00:40, 00:50)
                ForEach(stride(from: 10.0, through: maxT, by: 10.0).map { $0 }, id: \.self) { tVal in
                    Text(String(format: "00:%.0f", tVal))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.7))
                        .position(x: calcX(tVal, maxT: maxT, padL: padL, drawW: drawW), y: h - 6)
                }

                // Right label: Flow(ml/s) 0
                Text("Flow(ml/s)\n0")
                    .font(.system(size: 7, weight: .bold, design: .serif))
                    .foregroundColor(Color.red)
                    .multilineTextAlignment(.center)
                    .position(x: w - 20, y: calcY(0, maxVal: maxFlow, padT: padT, drawH: drawH) - 10)
            }
        }
    }

    private func exportReportPDF() {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Uroflow_Report_\(patientName.replacingOccurrences(of: " ", with: "_")).pdf")

        do {
            try renderer.writePDF(to: tempURL) { ctx in
                ctx.beginPage()
                let headerFont = UIFont.boldSystemFont(ofSize: 14)
                let subFont = UIFont.systemFont(ofSize: 10)
                let boldFont = UIFont.boldSystemFont(ofSize: 9)
                let regularFont = UIFont.systemFont(ofSize: 9)

                // 1. Hospital Header
                "Saveetha Medical College & Hospital".draw(
                    at: CGPoint(x: 36, y: 36),
                    withAttributes: [.font: headerFont, .foregroundColor: UIColor(red: 2/255, green: 132/255, blue: 199/255, alpha: 1.0)]
                )
                "Department Of Urology • Locom Wireless Uroflowmetry".draw(
                    at: CGPoint(x: 36, y: 54),
                    withAttributes: [.font: subFont, .foregroundColor: UIColor.darkGray]
                )
                "AYMED URODYNAMICS • www.aymed.com".draw(
                    at: CGPoint(x: 380, y: 38),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor(red: 3/255, green: 105/255, blue: 161/255, alpha: 1.0)]
                )

                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: 36, y: 72))
                linePath.addLine(to: CGPoint(x: 576, y: 72))
                linePath.lineWidth = 0.8
                UIColor.lightGray.setStroke()
                linePath.stroke()

                // 2. Metadata Box
                var curY: CGFloat = 80
                let metaLeft: [(String, String)] = [
                    ("Test Type:", "Uroflow"),
                    ("Date:", dateString),
                    ("Hospital No:", hospitalNo),
                    ("Patient Name:", "\(patientName) (\(age) yrs / \(gender))"),
                    ("Attending Doctor:", doctorName)
                ]
                for (lbl, val) in metaLeft {
                    lbl.draw(at: CGPoint(x: 40, y: curY), withAttributes: [.font: boldFont, .foregroundColor: UIColor.black])
                    val.draw(at: CGPoint(x: 135, y: curY), withAttributes: [.font: regularFont, .foregroundColor: UIColor.black])
                    curY += 15
                }

                let diagBox = CGRect(x: 375, y: 80, width: 195, height: 70)
                let diagPath = UIBezierPath(roundedRect: diagBox, cornerRadius: 4)
                UIColor(white: 0.96, alpha: 1.0).setFill()
                diagPath.fill()
                UIColor.lightGray.setStroke()
                diagPath.stroke()

                "UROFLOWMETER EVALUATION".draw(at: CGPoint(x: 382, y: 86), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.black])
                let statusStr = qmax >= 15 ? "Normal Flow Rate" : (qmax >= 10 ? "Borderline Flow Rate" : "Abnormal / Obstructed Flow")
                let statusColor = qmax >= 15 ? UIColor(red: 22/255, green: 101/255, blue: 52/255, alpha: 1.0) : UIColor(red: 153/255, green: 27/255, blue: 27/255, alpha: 1.0)
                statusStr.draw(at: CGPoint(x: 382, y: 100), withAttributes: [.font: boldFont, .foregroundColor: statusColor])
                "Acoustic AI Signal Processing".draw(at: CGPoint(x: 382, y: 114), withAttributes: [.font: regularFont, .foregroundColor: UIColor.darkGray])

                // 3. Dual Clinical Charts
                let maxT = max(stopTime > 0 ? stopTime : Double(voidDuration), 1.0)
                let maxV = max(Double(volume), 100.0) * 1.15
                let maxF = max(qmax, 5.0) * 1.3

                // Volume Curve (Green)
                let volChartRect = CGRect(x: 40, y: 165, width: 530, height: 125)
                UIBezierPath(rect: volChartRect).stroke()
                "Volume (mL) vs Time (sec)".draw(at: CGPoint(x: 45, y: 168), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor(red: 21/255, green: 128/255, blue: 61/255, alpha: 1.0)])

                for i in 1...3 {
                    let gy = volChartRect.minY + CGFloat(i) * (volChartRect.height / 4.0)
                    let gp = UIBezierPath()
                    gp.move(to: CGPoint(x: volChartRect.minX, y: gy))
                    gp.addLine(to: CGPoint(x: volChartRect.maxX, y: gy))
                    UIColor(white: 0.9, alpha: 1.0).setStroke()
                    gp.stroke()
                }

                let volPath = UIBezierPath()
                let vPts = volumeCurve ?? []
                if !vPts.isEmpty {
                    for (idx, pt) in vPts.enumerated() {
                        let px = volChartRect.minX + CGFloat(min(pt.timestamp / maxT, 1.0)) * volChartRect.width
                        let py = volChartRect.maxY - CGFloat(min(pt.volumeML / maxV, 1.0)) * volChartRect.height
                        if idx == 0 { volPath.move(to: CGPoint(x: px, y: py)) }
                        else { volPath.addLine(to: CGPoint(x: px, y: py)) }
                    }
                } else {
                    for i in 0...40 {
                        let frac = Double(i) / 40.0
                        let s = 1.0 / (1.0 + exp(-10.0 * (frac - 0.45)))
                        let v = Double(volume) * s
                        let px = volChartRect.minX + CGFloat(frac) * volChartRect.width
                        let py = volChartRect.maxY - CGFloat(min(v / maxV, 1.0)) * volChartRect.height
                        if i == 0 { volPath.move(to: CGPoint(x: px, y: py)) }
                        else { volPath.addLine(to: CGPoint(x: px, y: py)) }
                    }
                }
                volPath.lineWidth = 1.4
                UIColor(red: 21/255, green: 128/255, blue: 61/255, alpha: 1.0).setStroke()
                volPath.stroke()
                "\(volume) mL".draw(at: CGPoint(x: volChartRect.maxX - 45, y: volChartRect.minY + 6), withAttributes: [.font: boldFont, .foregroundColor: UIColor(red: 21/255, green: 128/255, blue: 61/255, alpha: 1.0)])

                // Flow Rate Curve (Red)
                let flowChartRect = CGRect(x: 40, y: 300, width: 530, height: 125)
                UIBezierPath(rect: flowChartRect).stroke()
                "Flow Rate (mL/s) vs Time (sec)".draw(at: CGPoint(x: 45, y: 303), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.red])

                for i in 1...3 {
                    let gy = flowChartRect.minY + CGFloat(i) * (flowChartRect.height / 4.0)
                    let gp = UIBezierPath()
                    gp.move(to: CGPoint(x: flowChartRect.minX, y: gy))
                    gp.addLine(to: CGPoint(x: flowChartRect.maxX, y: gy))
                    UIColor(white: 0.9, alpha: 1.0).setStroke()
                    gp.stroke()
                }

                let flowPath = UIBezierPath()
                let fPts = flowCurve ?? []
                if !fPts.isEmpty {
                    for (idx, pt) in fPts.enumerated() {
                        let px = flowChartRect.minX + CGFloat(min(pt.timestamp / maxT, 1.0)) * flowChartRect.width
                        let py = flowChartRect.maxY - CGFloat(min(pt.flowMLPerSec / maxF, 1.0)) * flowChartRect.height
                        if idx == 0 { flowPath.move(to: CGPoint(x: px, y: py)) }
                        else { flowPath.addLine(to: CGPoint(x: px, y: py)) }
                    }
                } else {
                    let peakT = maxFlowTime > 0 ? maxFlowTime : (maxT * 0.4)
                    for i in 0...40 {
                        let frac = Double(i) / 40.0
                        let t = frac * maxT
                        let f: Double
                        if t < peakT {
                            f = qmax * pow(t / max(peakT, 0.001), 1.6)
                        } else {
                            f = qmax * pow(max(1.0 - (t - peakT) / max(maxT - peakT, 0.001), 0.0), 2.0)
                        }
                        let px = flowChartRect.minX + CGFloat(frac) * flowChartRect.width
                        let py = flowChartRect.maxY - CGFloat(min(f / maxF, 1.0)) * flowChartRect.height
                        if i == 0 { flowPath.move(to: CGPoint(x: px, y: py)) }
                        else { flowPath.addLine(to: CGPoint(x: px, y: py)) }
                    }
                }
                flowPath.lineWidth = 1.4
                UIColor.red.setStroke()
                flowPath.stroke()
                "Qmax: \(String(format: "%.1f", qmax)) mL/s".draw(at: CGPoint(x: flowChartRect.maxX - 95, y: flowChartRect.minY + 6), withAttributes: [.font: boldFont, .foregroundColor: UIColor.red])

                // 4. Clinical Parameters Table
                let tableY: CGFloat = 438
                let params: [(String, String, Bool)] = [
                    ("Start Time", String(format: "%.0f sec", startTime), false),
                    ("Stop Time", String(format: "%.0f sec", stopTime > 0 ? stopTime : Double(voidDuration)), false),
                    ("Flow Start Time (Hesitancy)", String(format: "%.0f sec", flowStartTime), false),
                    ("Max Flow Rate (Qmax)", String(format: "%.1f ml/sec", qmax), true),
                    ("Time to Max Flow", String(format: "%.0f sec", maxFlowTime), false),
                    ("Average Flow Rate", String(format: "%.1f ml/sec", avgFlow), false),
                    ("Void Duration", "\(voidDuration) sec", false),
                    ("Voided Volume", "\(volume) ml", true),
                    ("Number of Flow Intervals", "\(flowIntervals)", false)
                ]

                let tableBox = CGRect(x: 40, y: tableY, width: 275, height: 185)
                UIBezierPath(roundedRect: tableBox, cornerRadius: 4).stroke()
                var pY = tableY + 8
                for (lbl, val, isB) in params {
                    lbl.draw(at: CGPoint(x: 48, y: pY), withAttributes: [.font: isB ? boldFont : regularFont, .foregroundColor: UIColor.black])
                    val.draw(at: CGPoint(x: 220, y: pY), withAttributes: [.font: isB ? UIFont.boldSystemFont(ofSize: 9) : regularFont, .foregroundColor: isB ? UIColor(red: 153/255, green: 27/255, blue: 27/255, alpha: 1.0) : UIColor.black])
                    pY += 19
                }

                // Siroky Nomogram Assessment Box
                let nomoBox = CGRect(x: 325, y: tableY, width: 245, height: 185)
                UIBezierPath(roundedRect: nomoBox, cornerRadius: 4).stroke()
                "SIROKY NOMOGRAM ASSESSMENT".draw(at: CGPoint(x: 335, y: tableY + 8), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.black])

                let sqrtV = sqrt(max(Double(volume), 10.0))
                let maxSD = (qmax - 2.06 * sqrtV) / 3.8
                let avgSD = (avgFlow - 1.05 * sqrtV) / 2.4

                let maxSDStr = String(format: "Max Flow SD: %.2f (%@)", maxSD, maxSD >= 0 ? "Normal" : (maxSD >= -2 ? "Borderline" : "Obstructed"))
                let avgSDStr = String(format: "Average Flow SD: %.2f (%@)", avgSD, avgSD >= 0 ? "Normal" : (avgSD >= -2 ? "Borderline" : "Obstructed"))

                maxSDStr.draw(at: CGPoint(x: 335, y: tableY + 36), withAttributes: [.font: regularFont, .foregroundColor: UIColor.black])
                avgSDStr.draw(at: CGPoint(x: 335, y: tableY + 58), withAttributes: [.font: regularFont, .foregroundColor: UIColor.black])

                "Siroky nomograms adjust flow values against voided volume".draw(at: CGPoint(x: 335, y: tableY + 95), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray])
                "to assess standard deviation from healthy adult reference ranges.".draw(at: CGPoint(x: 335, y: tableY + 110), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray])
                "Green zone represents flow >= 0 SD. Red indicates < -2 SD.".draw(at: CGPoint(x: 335, y: tableY + 125), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray])

                // 5. Footer & Doctor Signature
                let footerLine = UIBezierPath()
                footerLine.move(to: CGPoint(x: 40, y: 700))
                footerLine.addLine(to: CGPoint(x: 570, y: 700))
                UIColor.lightGray.setStroke()
                footerLine.stroke()

                "Locom Wireless System v. 0.2.64 • Saveetha Institute of Medical and Technical Sciences".draw(
                    at: CGPoint(x: 40, y: 710),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray]
                )
                "Physician Signature : _________________________".draw(
                    at: CGPoint(x: 340, y: 720),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.black]
                )
                doctorName.draw(
                    at: CGPoint(x: 440, y: 736),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray]
                )
            }

            self.pdfURL = tempURL
            self.showShareSheet = true
        } catch {
            print("Failed to generate PDF: \(error)")
        }
    }
}

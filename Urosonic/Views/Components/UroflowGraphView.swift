// UroflowGraphView.swift — SwiftUI Clinical Uroflowmetry Graph System (Dual Synchronized Flow & Volume)
// Aura MedTech Design System & Hospital Urodynamics

import SwiftUI

enum UroflowGraphDisplayMode: String, CaseIterable {
    case dual = "Dual (Doctor Report)"
    case flowOnly = "Flow (mL/s)"
    case volumeOnly = "Volume (mL)"
}

struct UroflowGraphView: View {
    let qmax:         Double
    let volume:       Int
    let voidTime:     Int
    let avgFlow:      Double
    var flowCurve:    [PredictedFlowPoint]? = nil
    var volumeCurve:  [PredictedVolumePoint]? = nil
    var flowStartTime: Double? = nil
    var maxFlowTime:   Double? = nil
    var isDemoMode:   Bool = false

    @State private var displayMode: UroflowGraphDisplayMode = .dual
    @State private var drawProgress: Double = 0

    private var effectiveMaxT: Double {
        if let curve = flowCurve, let last = curve.last, last.timestamp > 0 {
            return max(last.timestamp, Double(max(voidTime, 1)))
        }
        return Double(max(voidTime, 1))
    }

    private var effectiveQmax: Double {
        if let curve = flowCurve, !curve.isEmpty {
            let maxInCurve = curve.map(\.flowMLPerSec).max() ?? 0.0
            return max(qmax, maxInCurve, 5.0)
        }
        return max(qmax, 5.0)
    }

    private var effectiveMaxVolume: Double {
        if let vCurve = volumeCurve, let last = vCurve.last, last.volumeML > 0 {
            return max(Double(volume), last.volumeML, 100.0)
        }
        return max(Double(volume), 100.0)
    }

    private func flowAtDemo(t: Double, peak: Double, maxT: Double) -> Double {
        let peakTime = maxT * 0.4
        if t < peakTime {
            let p = t / peakTime
            return peak * pow(p, 1.5)
        } else {
            let p = (t - peakTime) / (maxT - peakTime)
            return peak * pow(1 - p, 2)
        }
    }

    // MARK: - Flow Path Builder
    private func buildFlowPath(in rect: CGRect) -> (curve: Path, area: Path, peakPt: CGPoint, displayQmax: Double) {
        let pad = UIEdgeInsets(top: 22, left: 44, bottom: 24, right: 20)
        let drawW = max(rect.width - pad.left - pad.right, 10.0)
        let drawH = max(rect.height - pad.top - pad.bottom, 10.0)
        let maxT = effectiveMaxT
        let peakFlow = effectiveQmax
        let maxFlow = peakFlow * 1.25

        func xP(_ t: Double) -> CGFloat {
            pad.left + CGFloat(min(max(t, 0.0), maxT) / maxT) * drawW
        }
        func yP(_ f: Double) -> CGFloat {
            pad.top + CGFloat(1.0 - min(max(f, 0.0), maxFlow) / maxFlow) * drawH
        }

        var pts: [(CGFloat, CGFloat)] = []
        var peakPt = CGPoint(x: pad.left, y: yP(0))
        var highestVal = 0.0

        if let curve = flowCurve, !curve.isEmpty {
            for pt in curve {
                let x = xP(pt.timestamp)
                let y = yP(pt.flowMLPerSec)
                pts.append((x, y))
                if pt.flowMLPerSec >= highestVal {
                    highestVal = pt.flowMLPerSec
                    peakPt = CGPoint(x: x, y: y)
                }
            }
        } else if isDemoMode {
            var t = 0.0
            while t <= maxT {
                let f = flowAtDemo(t: t, peak: qmax > 0 ? qmax : 15.0, maxT: maxT)
                let x = xP(t)
                let y = yP(f)
                pts.append((x, y))
                if f >= highestVal {
                    highestVal = f
                    peakPt = CGPoint(x: x, y: y)
                }
                t += max(maxT / 40.0, 0.25)
            }
        } else {
            pts.append((xP(0.0), yP(0.0)))
            pts.append((xP(maxT), yP(0.0)))
            peakPt = CGPoint(x: xP(maxT / 2), y: yP(0.0))
        }

        var curvePath = Path()
        var areaPath = Path()

        if let first = pts.first {
            curvePath.move(to: CGPoint(x: first.0, y: first.1))
            areaPath.move(to: CGPoint(x: first.0, y: yP(0)))
            areaPath.addLine(to: CGPoint(x: first.0, y: first.1))
        }

        if pts.count >= 2 {
            for i in 1..<pts.count {
                let (cx, cy) = pts[i]
                let (px, py) = pts[i - 1]
                let cp1 = CGPoint(x: px + (cx - px) / 3, y: py)
                let cp2 = CGPoint(x: px + 2 * (cx - px) / 3, y: cy)
                curvePath.addCurve(to: CGPoint(x: cx, y: cy), control1: cp1, control2: cp2)
                areaPath.addCurve(to: CGPoint(x: cx, y: cy), control1: cp1, control2: cp2)
            }
        }

        if let last = pts.last {
            areaPath.addLine(to: CGPoint(x: last.0, y: yP(0)))
            areaPath.closeSubpath()
        }

        return (curvePath, areaPath, peakPt, max(highestVal, qmax))
    }

    // MARK: - Cumulative Volume Path Builder
    private func buildVolumePath(in rect: CGRect) -> (curve: Path, area: Path, endPt: CGPoint, maxVol: Double) {
        let pad = UIEdgeInsets(top: 22, left: 44, bottom: 24, right: 20)
        let drawW = max(rect.width - pad.left - pad.right, 10.0)
        let drawH = max(rect.height - pad.top - pad.bottom, 10.0)
        let maxT = effectiveMaxT
        let peakVol = effectiveMaxVolume
        let maxVolumeScale = peakVol * 1.15

        func xP(_ t: Double) -> CGFloat {
            pad.left + CGFloat(min(max(t, 0.0), maxT) / maxT) * drawW
        }
        func yP(_ v: Double) -> CGFloat {
            pad.top + CGFloat(1.0 - min(max(v, 0.0), maxVolumeScale) / maxVolumeScale) * drawH
        }

        var pts: [(CGFloat, CGFloat)] = []
        var endPt = CGPoint(x: pad.left, y: yP(0))

        if let vCurve = volumeCurve, !vCurve.isEmpty {
            for pt in vCurve {
                let x = xP(pt.timestamp)
                let y = yP(pt.volumeML)
                pts.append((x, y))
                endPt = CGPoint(x: x, y: y)
            }
        } else if let fCurve = flowCurve, !fCurve.isEmpty {
            // Integrate on-the-fly
            var cum = 0.0
            for i in 0..<fCurve.count {
                if i == 0 {
                    pts.append((xP(fCurve[0].timestamp), yP(0.0)))
                } else {
                    let dt = fCurve[i].timestamp - fCurve[i - 1].timestamp
                    let fAvg = 0.5 * (fCurve[i - 1].flowMLPerSec + fCurve[i].flowMLPerSec)
                    cum += fAvg * dt
                    let x = xP(fCurve[i].timestamp)
                    let y = yP(cum)
                    pts.append((x, y))
                    endPt = CGPoint(x: x, y: y)
                }
            }
        } else {
            // Simulated S-curve volume
            let steps = 30
            for i in 0...steps {
                let t = (Double(i) / Double(steps)) * maxT
                let p = t / maxT
                let v = Double(volume) * (1.0 / (1.0 + exp(-8.0 * (p - 0.4))))
                let x = xP(t)
                let y = yP(v)
                pts.append((x, y))
                endPt = CGPoint(x: x, y: y)
            }
        }

        var curvePath = Path()
        var areaPath = Path()

        if let first = pts.first {
            curvePath.move(to: CGPoint(x: first.0, y: first.1))
            areaPath.move(to: CGPoint(x: first.0, y: yP(0)))
            areaPath.addLine(to: CGPoint(x: first.0, y: first.1))
        }

        if pts.count >= 2 {
            for i in 1..<pts.count {
                let (cx, cy) = pts[i]
                let (px, py) = pts[i - 1]
                let cp1 = CGPoint(x: px + (cx - px) / 3, y: py)
                let cp2 = CGPoint(x: px + 2 * (cx - px) / 3, y: cy)
                curvePath.addCurve(to: CGPoint(x: cx, y: cy), control1: cp1, control2: cp2)
                areaPath.addCurve(to: CGPoint(x: cx, y: cy), control1: cp1, control2: cp2)
            }
        }

        if let last = pts.last {
            areaPath.addLine(to: CGPoint(x: last.0, y: yP(0)))
            areaPath.closeSubpath()
        }

        return (curvePath, areaPath, endPt, peakVol)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mode toggle
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTeal)

                    Text("Urodynamic Curves")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                }

                Spacer()

                if let curve = flowCurve, !curve.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color.uroSuccess).frame(width: 6, height: 6)
                        Text("ML SYNCHRONIZED (\(curve.count) PTS)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "065F46"))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.uroSuccessBg)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.uroSuccess.opacity(0.3), lineWidth: 0.75))
                } else if isDemoMode {
                    Text("DEMO / PREVIEW")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "92400E"))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.uroWarningBg)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.uroWarning.opacity(0.3), lineWidth: 0.75))
                }
            }

            // Mode Picker Selector (Dual Clinical View | Flow Only | Volume Only)
            HStack(spacing: 4) {
                ForEach(UroflowGraphDisplayMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            displayMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: displayMode == mode ? .bold : .medium, design: .rounded))
                            .foregroundColor(displayMode == mode ? .white : Color.slateSub)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                displayMode == mode ?
                                    Color.appTeal :
                                    Color.slateCard
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.slateBorder.opacity(0.6), lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Chart Rendering
            if displayMode == .dual {
                // Stacked Hospital Dual Charts (Volume on Top, Flow on Bottom)
                VStack(spacing: 8) {
                    volumeChart(height: 140)
                    flowChart(height: 160)
                }
            } else if displayMode == .volumeOnly {
                volumeChart(height: 220)
            } else {
                flowChart(height: 220)
            }
        }
        .padding(16)
        .uroCard(cornerRadius: 22)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                drawProgress = 1.0
            }
        }
    }

    // MARK: - Flow Rate Subchart (Red/Coral like Doctor's Report)
    @ViewBuilder
    private func flowChart(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Flow Rate Curve")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                }
                Spacer()
                Text(String(format: "Max Flow: %.1f mL/s", effectiveQmax))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.red)
            }

            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let (curve, area, peak, peakVal) = buildFlowPath(in: rect)
                let pad = UIEdgeInsets(top: 22, left: 44, bottom: 24, right: 20)
                let drawH = max(rect.height - pad.top - pad.bottom, 10.0)
                let drawW = max(rect.width - pad.left - pad.right, 10.0)
                let maxFlow = effectiveQmax * 1.25
                let maxT = effectiveMaxT

                ZStack(alignment: .topLeading) {
                    // Y-axis grid lines
                    ForEach(0...3, id: \.self) { idx in
                        let frac = Double(idx) / 3.0
                        let flowVal = frac * maxFlow
                        let y = pad.top + CGFloat(1.0 - frac) * drawH

                        Path { p in
                            p.move(to: CGPoint(x: pad.left, y: y))
                            p.addLine(to: CGPoint(x: rect.width - pad.right, y: y))
                        }
                        .stroke(Color.slateBorder.opacity(0.6), lineWidth: 0.6)

                        Text("\(Int(round(flowVal)))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.slateSub)
                            .position(x: pad.left - 18, y: y)
                    }

                    // X-axis time labels
                    ForEach([0.0, maxT * 0.25, maxT * 0.5, maxT * 0.75, maxT], id: \.self) { tVal in
                        let x = pad.left + CGFloat(tVal / maxT) * drawW
                        Text(String(format: "%.0fs", tVal))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.slateSub)
                            .position(x: x, y: rect.height - 8)
                    }

                    // Y-axis unit label
                    Text("Flow (mL/s)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateSub)
                        .rotationEffect(.degrees(-90))
                        .position(x: 10, y: rect.height / 2)

                    // Area fill
                    area.fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.20), Color.red.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Flow Curve
                    curve
                        .trim(from: 0, to: drawProgress)
                        .stroke(
                            Color.red,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.red.opacity(0.3), radius: 4, y: 1)

                    // Vertical Red Indicator line at Max Flow (Doctor's report format)
                    if drawProgress > 0.6 && peakVal > 0.0 {
                        Path { p in
                            p.move(to: CGPoint(x: peak.x, y: pad.top))
                            p.addLine(to: CGPoint(x: peak.x, y: pad.top + drawH))
                        }
                        .stroke(Color.red.opacity(0.8), style: StrokeStyle(lineWidth: 1.0, dash: [3, 2]))

                        // Max Flow label pill
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", peakVal))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .position(x: min(max(peak.x, pad.left + 24), rect.width - pad.right - 24), y: max(peak.y - 12, 10))
                    }
                }
            }
            .frame(height: height)
        }
    }

    // MARK: - Cumulative Volume Subchart (Green like Doctor's Report)
    @ViewBuilder
    private func volumeChart(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.uroSuccess).frame(width: 8, height: 8)
                    Text("Volume Curve")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                }
                Spacer()
                Text(String(format: "Total Volume: %d mL", volume))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.uroSuccess)
            }

            GeometryReader { geo in
                let rect = geo.frame(in: .local)
                let (curve, area, endPt, peakVol) = buildVolumePath(in: rect)
                let pad = UIEdgeInsets(top: 22, left: 44, bottom: 24, right: 20)
                let drawH = max(rect.height - pad.top - pad.bottom, 10.0)
                let drawW = max(rect.width - pad.left - pad.right, 10.0)
                let maxVolumeScale = peakVol * 1.15
                let maxT = effectiveMaxT

                ZStack(alignment: .topLeading) {
                    // Y-axis grid lines
                    ForEach(0...3, id: \.self) { idx in
                        let frac = Double(idx) / 3.0
                        let vVal = frac * maxVolumeScale
                        let y = pad.top + CGFloat(1.0 - frac) * drawH

                        Path { p in
                            p.move(to: CGPoint(x: pad.left, y: y))
                            p.addLine(to: CGPoint(x: rect.width - pad.right, y: y))
                        }
                        .stroke(Color.slateBorder.opacity(0.6), lineWidth: 0.6)

                        Text("\(Int(round(vVal)))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.slateSub)
                            .position(x: pad.left - 18, y: y)
                    }

                    // X-axis time labels
                    ForEach([0.0, maxT * 0.25, maxT * 0.5, maxT * 0.75, maxT], id: \.self) { tVal in
                        let x = pad.left + CGFloat(tVal / maxT) * drawW
                        Text(String(format: "%.0fs", tVal))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.slateSub)
                            .position(x: x, y: rect.height - 8)
                    }

                    // Y-axis unit label
                    Text("Volume (mL)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateSub)
                        .rotationEffect(.degrees(-90))
                        .position(x: 10, y: rect.height / 2)

                    // Area fill
                    area.fill(
                        LinearGradient(
                            colors: [Color.uroSuccess.opacity(0.18), Color.uroSuccess.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Volume Curve
                    curve
                        .trim(from: 0, to: drawProgress)
                        .stroke(
                            Color.uroSuccess,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.uroSuccess.opacity(0.3), radius: 4, y: 1)

                    // Final volume label on right edge
                    if drawProgress > 0.8 && volume > 0 {
                        HStack(spacing: 2) {
                            Text("\(volume) mL")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.uroSuccess)
                        .clipShape(Capsule())
                        .position(x: min(endPt.x - 10, rect.width - pad.right - 20), y: endPt.y - 12)
                    }
                }
            }
            .frame(height: height)
        }
    }
}

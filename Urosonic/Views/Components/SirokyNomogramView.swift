// SirokyNomogramView.swift — International Continence Society (ICS) Siroky Uroflow Nomograms
// Aura MedTech Design System & Clinical Diagnostics

import SwiftUI

enum SirokyNomogramType {
    case maxFlow
    case averageFlow

    var title: String {
        switch self {
        case .maxFlow:     return "Maximum Flow Siroky"
        case .averageFlow: return "Average Flow Siroky"
        }
    }

    var yAxisLabel: String {
        switch self {
        case .maxFlow:     return "Qmax (mL/s)"
        case .averageFlow: return "Qavg (mL/s)"
        }
    }

    var maxY: Double {
        switch self {
        case .maxFlow:     return 32.0
        case .averageFlow: return 20.0
        }
    }

    func expected(volume: Double) -> Double {
        let v = max(volume, 10.0)
        switch self {
        case .maxFlow:     return 2.06 * sqrt(v)
        case .averageFlow: return 1.05 * sqrt(v)
        }
    }

    func sd() -> Double {
        switch self {
        case .maxFlow:     return 3.8
        case .averageFlow: return 2.4
        }
    }
}

struct SirokyNomogramView: View {
    let type: SirokyNomogramType
    let volume: Double
    let flowValue: Double

    private let minVol: Double = 50.0
    private let maxVol: Double = 500.0

    private func xPos(_ vol: Double, padL: CGFloat, drawW: CGFloat) -> CGFloat {
        padL + CGFloat((min(max(vol, minVol), maxVol) - minVol) / (maxVol - minVol)) * drawW
    }

    private func yPos(_ flow: Double, padT: CGFloat, drawH: CGFloat) -> CGFloat {
        padT + CGFloat(1.0 - min(max(flow, 0.0), type.maxY) / type.maxY) * drawH
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(type.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.slateText)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let padL: CGFloat = 28
                let padR: CGFloat = 12
                let padT: CGFloat = 12
                let padB: CGFloat = 20
                let drawW = max(w - padL - padR, 10)
                let drawH = max(h - padT - padB, 10)

                ZStack {
                    // Grid background
                    Path { path in
                        // Horizontal grid lines
                        let steps = 4
                        for i in 0...steps {
                            let yVal = (Double(i) / Double(steps)) * type.maxY
                            let y = yPos(yVal, padT: padT, drawH: drawH)
                            path.move(to: CGPoint(x: padL, y: y))
                            path.addLine(to: CGPoint(x: padL + drawW, y: y))
                        }
                        // Vertical grid lines (100, 200, 300, 400, 500 mL)
                        for vol in stride(from: 100.0, through: 500.0, by: 100.0) {
                            let x = xPos(vol, padL: padL, drawW: drawW)
                            path.move(to: CGPoint(x: x, y: padT))
                            path.addLine(to: CGPoint(x: x, y: padT + drawH))
                        }
                    }
                    .stroke(Color.slateBorder.opacity(0.4), lineWidth: 0.5)

                    // Shaded -2 SD obstruction zone
                    Path { path in
                        var first = true
                        for vol in stride(from: minVol, through: maxVol, by: 10.0) {
                            let f = max(type.expected(volume: vol) - 2.0 * type.sd(), 0.0)
                            let pt = CGPoint(x: xPos(vol, padL: padL, drawW: drawW), y: yPos(f, padT: padT, drawH: drawH))
                            if first {
                                path.move(to: CGPoint(x: xPos(minVol, padL: padL, drawW: drawW), y: yPos(0, padT: padT, drawH: drawH)))
                                path.addLine(to: pt)
                                first = false
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                        path.addLine(to: CGPoint(x: xPos(maxVol, padL: padL, drawW: drawW), y: yPos(0, padT: padT, drawH: drawH)))
                        path.closeSubpath()
                    }
                    .fill(Color.red.opacity(0.08))

                    // SD curves (+2SD, +1SD, Mean, -1SD, -2SD)
                    ForEach([-2.0, -1.0, 0.0, 1.0, 2.0], id: \.self) { sdMult in
                        Path { path in
                            var first = true
                            for vol in stride(from: minVol, through: maxVol, by: 10.0) {
                                let f = max(type.expected(volume: vol) + sdMult * type.sd(), 0.0)
                                let pt = CGPoint(x: xPos(vol, padL: padL, drawW: drawW), y: yPos(f, padT: padT, drawH: drawH))
                                if first {
                                    path.move(to: pt)
                                    first = false
                                } else {
                                    path.addLine(to: pt)
                                }
                            }
                        }
                        .stroke(
                            sdMult == 0 ? Color.slateText.opacity(0.8) : (sdMult == -2.0 ? Color.red.opacity(0.5) : Color.slateSub.opacity(0.5)),
                            style: StrokeStyle(lineWidth: sdMult == 0 ? 1.2 : 0.8, dash: sdMult == 0 ? [] : [2, 2])
                        )
                    }

                    // Axis labels
                    // Y labels
                    Text(String(format: "%.0f", type.maxY))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.slateSub)
                        .position(x: padL - 14, y: padT + 4)

                    Text("0")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.slateSub)
                        .position(x: padL - 10, y: padT + drawH - 2)

                    // X labels
                    Text("100")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.slateSub)
                        .position(x: xPos(100, padL: padL, drawW: drawW), y: padT + drawH + 10)

                    Text("300")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.slateSub)
                        .position(x: xPos(300, padL: padL, drawW: drawW), y: padT + drawH + 10)

                    Text("500")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.slateSub)
                        .position(x: xPos(500, padL: padL, drawW: drawW), y: padT + drawH + 10)

                    // Patient Plot Point (Red circle matching clinical printout)
                    if volume > 0 && flowValue > 0 {
                        let ptX = xPos(volume, padL: padL, drawW: drawW)
                        let ptY = yPos(flowValue, padT: padT, drawH: drawH)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.red.opacity(0.5), radius: 4)
                            .position(x: ptX, y: ptY)

                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                            .position(x: ptX, y: ptY)
                    }
                }
            }
            .frame(height: 120)
            .background(Color.slateCard.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.slateBorder.opacity(0.5), lineWidth: 0.8)
            )

            // Bottom Nomogram Classification
            let exp = type.expected(volume: volume)
            let zScore = (flowValue - exp) / type.sd()
            HStack(spacing: 4) {
                Circle()
                    .fill(zScore >= -1.0 ? Color.uroSuccess : (zScore >= -2.0 ? Color.uroWarning : Color.red))
                    .frame(width: 5, height: 5)
                Text(zScore >= -1.0 ? "Normal (> -1 SD)" : (zScore >= -2.0 ? "Borderline (-1 to -2 SD)" : "Obstructed (< -2 SD)"))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(zScore >= -1.0 ? Color.uroSuccess : (zScore >= -2.0 ? Color.uroWarning : Color.red))
            }
        }
    }
}

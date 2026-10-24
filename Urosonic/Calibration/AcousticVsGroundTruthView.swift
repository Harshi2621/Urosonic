// AcousticVsGroundTruthView.swift
// Urosonic — Research Dual Timeline: Acoustic Signal Level (dBFS) vs Independent Ground-Truth Flow (mL/s)

import SwiftUI

struct AcousticVsGroundTruthView: View {
    let session: CalibrationSession
    @Environment(\.dismiss) private var dismiss

    private var maxTime: TimeInterval {
        let maxAcoustic = session.acousticFeatures.last?.timestamp ?? 1.0
        let maxGT = session.groundTruth?.endTime ?? 1.0
        return max(maxAcoustic, maxGT, 1.0)
    }

    private var maxFlowRate: Double {
        let pts = session.groundTruth?.flowPoints.map { $0.flowRateMLPerSecond } ?? []
        return max(pts.max() ?? 25.0, 10.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerBanner
                    acousticLane
                    groundTruthLane
                    scientificNotice
                }
            }
            .navigationTitle("Acoustic vs Ground Truth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews
    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Acoustic vs Ground Truth Timeline")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.slateText)
            Text("Synchronized time alignment between real microphone acoustics and independent reference flow measurements. Acoustic amplitude is in dBFS; reference flow is in mL/s.")
                .font(.system(size: 12))
                .foregroundColor(.slateSub)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var acousticLane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color.appTeal).frame(width: 8, height: 8)
                Text("Acoustic Signal Level (dBFS)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.slateText)
                Spacer()
                Text("Microphone Audio (Full Scale)")
                    .font(.system(size: 10))
                    .foregroundColor(.slateSub)
            }

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    acousticGrid(in: geo.size)

                    if let start = session.eventStartTime, let end = session.eventEndTime {
                        let x = CGFloat(start / maxTime) * geo.size.width
                        let w = CGFloat((end - start) / maxTime) * geo.size.width
                        Rectangle()
                            .fill(Color.appTeal.opacity(0.12))
                            .frame(width: max(w, 2), height: geo.size.height)
                            .offset(x: x)
                    }

                    acousticPath(in: geo.size)
                        .stroke(
                            LinearGradient(colors: [Color.appTeal, Color.appBlue], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .frame(height: 140)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var groundTruthLane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color(hex: "10B981")).frame(width: 8, height: 8)
                Text("Ground-Truth Flow Rate (mL/s)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.slateText)
                Spacer()
                Text(session.groundTruth?.method.rawValue ?? "No Reference Data")
                    .font(.system(size: 10))
                    .foregroundColor(.slateSub)
                    .lineLimit(1)
            }

            if let gt = session.groundTruth, !gt.flowPoints.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        groundTruthGrid(in: geo.size)

                        groundTruthPath(in: geo.size, points: gt.flowPoints)
                            .stroke(Color(hex: "10B981"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        groundTruthArea(in: geo.size, points: gt.flowPoints)
                            .fill(LinearGradient(colors: [Color(hex: "10B981").opacity(0.25), Color(hex: "10B981").opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(height: 140)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
            } else if let gt = session.groundTruth {
                VStack(spacing: 8) {
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appTeal)
                    Text("Session-Level Ground Truth Only")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.slateText)
                    Text("Total Volume: \(String(format: "%.1f mL", gt.totalVolumeML)) • Measured Flow Duration: \(String(format: "%.1f s", gt.duration))")
                        .font(.system(size: 12))
                        .foregroundColor(.slateSub)
                    Text("(Discrete point-by-point flow curve was not recorded during this session)")
                        .font(.system(size: 10))
                        .italic()
                        .foregroundColor(.slateSub.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.slateLight.opacity(0.4))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.slateSub)
                    Text("No ground-truth measurement associated yet.")
                        .font(.system(size: 12))
                        .foregroundColor(.slateSub)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.slateLight.opacity(0.4))
                .cornerRadius(12)
            }

            // Shared Time Axis Labels
            HStack {
                Text("0.0s")
                Spacer()
                Text(String(format: "%.1fs", maxTime / 2))
                Spacer()
                Text(String(format: "%.1fs", maxTime))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.slateSub)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var scientificNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.appTeal)
            Text("Scientific Note: Acoustic decibels (dBFS) do not linearly equate to fluid flow (mL/s). This dual alignment visualizes the empirical inputs for subsequent ML training.")
                .font(.system(size: 10))
                .foregroundColor(.slateSub)
                .lineSpacing(2)
        }
        .padding(12)
        .background(Color.appTeal.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Drawing Helpers
    private func acousticGrid(in size: CGSize) -> some View {
        Canvas { ctx, sz in
            let dbs: [Float] = [0.0, -20.0, -40.0, -60.0, -80.0]
            for db in dbs {
                let y = (1.0 - CGFloat((db - -80.0) / 80.0)) * sz.height
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color(Color.slateBorder.opacity(0.6)), lineWidth: 0.8)

                let label = Text("\(Int(db)) dB").font(.system(size: 8)).foregroundColor(Color.slateSub.opacity(0.7))
                ctx.draw(label, at: CGPoint(x: 20, y: max(y - 6, 6)))
            }
        }
    }

    private func acousticPath(in size: CGSize) -> Path {
        var path = Path()
        let features = session.acousticFeatures
        guard features.count > 1 else { return path }

        for (i, f) in features.enumerated() {
            let x = CGFloat(f.timestamp / maxTime) * size.width
            let clampedDB = min(max(f.dbFS, -80.0), 0.0)
            let y = (1.0 - CGFloat((clampedDB - -80.0) / 80.0)) * size.height

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func groundTruthGrid(in size: CGSize) -> some View {
        Canvas { ctx, sz in
            let maxRate = maxFlowRate
            let steps = 4
            for i in 0...steps {
                let rate = Double(i) / Double(steps) * maxRate
                let y = (1.0 - CGFloat(rate / maxRate)) * sz.height
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color(Color.slateBorder.opacity(0.6)), lineWidth: 0.8)

                let label = Text(String(format: "%.0f mL/s", rate)).font(.system(size: 8)).foregroundColor(Color.slateSub.opacity(0.7))
                ctx.draw(label, at: CGPoint(x: 24, y: max(y - 6, 6)))
            }
        }
    }

    private func groundTruthPath(in size: CGSize, points: [GroundTruthFlowPoint]) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        for (i, pt) in sorted.enumerated() {
            let x = CGFloat(pt.timestamp / maxTime) * size.width
            let y = (1.0 - CGFloat(pt.flowRateMLPerSecond / maxFlowRate)) * size.height

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func groundTruthArea(in size: CGSize, points: [GroundTruthFlowPoint]) -> Path {
        var path = groundTruthPath(in: size, points: points)
        guard let last = points.sorted(by: { $0.timestamp < $1.timestamp }).last,
              let first = points.sorted(by: { $0.timestamp < $1.timestamp }).first else { return path }

        let lastX = CGFloat(last.timestamp / maxTime) * size.width
        let firstX = CGFloat(first.timestamp / maxTime) * size.width

        path.addLine(to: CGPoint(x: lastX, y: size.height))
        path.addLine(to: CGPoint(x: firstX, y: size.height))
        path.closeSubpath()
        return path
    }
}

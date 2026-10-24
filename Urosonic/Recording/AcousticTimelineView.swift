// AcousticTimelineView.swift
// Urosonic — Acoustic Signal Timeline & Spectrogram Development Visualizer

import SwiftUI

struct AcousticTimelineView: View {
    let features: [AudioFrameFeature]
    let detectedEvents: [FlowEvent]
    let noiseFloorDBFS: Float
    let totalDuration: TimeInterval

    @State private var selectedTab: Int = 0 // 0: Signal Level (dBFS), 1: Frequency Spectrogram
    @State private var hoveredFeature: AudioFrameFeature? = nil

    private let minDisplayDBFS: Float = -80.0
    private let maxDisplayDBFS: Float = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTab == 0 ? "Acoustic Signal Timeline" : "Acoustic Spectrogram")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.slateText)
                    Text(selectedTab == 0 ? "Real acoustic signal level (dBFS) over time — not clinical flow rate" : "Frequency magnitude intensity over time (Diagnostic)")
                        .font(.system(size: 11))
                        .foregroundColor(.slateSub)
                }
                Spacer()

                // Tab Switcher
                Picker("Graph Type", selection: $selectedTab) {
                    Text("dBFS").tag(0)
                    Text("Spectrogram").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if features.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.slateSub.opacity(0.6))
                    Text("No acoustic frames captured")
                        .font(.system(size: 13))
                        .foregroundColor(.slateSub)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.slateLight.opacity(0.5))
                .cornerRadius(14)
            } else {
                if selectedTab == 0 {
                    // ── 1. REAL ACOUSTIC SIGNAL TIMELINE (dBFS vs TIME) ──
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .topLeading) {
                                // Background Grid & Event Zones
                                timelineBackground(in: geo.size)

                                // Event Highlight Regions
                                ForEach(detectedEvents) { event in
                                    eventHighlightZone(event: event, in: geo.size)
                                }

                                // Noise Floor Baseline Line
                                noiseFloorLine(in: geo.size)

                                // Real dBFS Curve
                                signalLevelPath(in: geo.size)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.appTeal, Color.appBlue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                                    )
                            }
                        }
                        .frame(height: 180)
                        .background(Color.slateCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))

                        // Timeline Axis Labels
                        HStack {
                            Text("0.0s")
                            Spacer()
                            Text(String(format: "%.1fs", totalDuration / 2))
                            Spacer()
                            Text(String(format: "%.1fs", max(totalDuration, 1.0)))
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.slateSub)
                    }

                    // Legend & Detected Event Banner
                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Circle().fill(Color.appTeal).frame(width: 7, height: 7)
                            Text("Audio Signal (dBFS)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.slateSub)
                        }

                        HStack(spacing: 5) {
                            Rectangle().fill(Color.orange.opacity(0.8)).frame(width: 12, height: 2)
                            Text("Noise Floor (\(Int(noiseFloorDBFS)) dBFS)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.slateSub)
                        }

                        if !detectedEvents.isEmpty {
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.appTeal.opacity(0.2))
                                    .frame(width: 12, height: 8)
                                Text("Flow Window")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.appTeal)
                            }
                        }
                    }
                } else {
                    // ── 2. ACOUSTIC SPECTROGRAM VIEW ──
                    spectrogramView
                }
            }
        }
        .padding(16)
        .background(Color.slateCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slateBorder, lineWidth: 1.2))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Timeline Helper Drawings
    private func timelineBackground(in size: CGSize) -> some View {
        Canvas { context, sz in
            let gridDBs: [Float] = [0.0, -20.0, -40.0, -60.0, -80.0]
            for db in gridDBs {
                let y = yPosition(for: db, height: sz.height)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: sz.width, y: y))
                context.stroke(path, with: .color(Color.slateBorder.opacity(0.6)), lineWidth: 0.8)

                // Label
                let text = Text("\(Int(db)) dB").font(.system(size: 8)).foregroundColor(Color.slateSub.opacity(0.7))
                context.draw(text, at: CGPoint(x: 20, y: max(y - 6, 6)))
            }
        }
    }

    private func noiseFloorLine(in size: CGSize) -> some View {
        let y = yPosition(for: noiseFloorDBFS, height: size.height)
        return Path { p in
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
        }
        .stroke(Color.orange.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
    }

    private func eventHighlightZone(event: FlowEvent, in size: CGSize) -> some View {
        let maxTime = max(totalDuration, 1.0)
        let startRatio = CGFloat(event.startTime / maxTime)
        let endRatio = CGFloat(event.endTime / maxTime)

        let x = startRatio * size.width
        let width = max((endRatio - startRatio) * size.width, 2.0)

        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.appTeal.opacity(0.12))
                .frame(width: width, height: size.height)
                .offset(x: x)

            Text("FLOW: \(String(format: "%.1fs", event.duration))")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.appTeal)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.slateCard)
                .cornerRadius(4)
                .offset(x: x + 4, y: 4)
        }
    }

    private func signalLevelPath(in size: CGSize) -> Path {
        var path = Path()
        guard features.count > 1 else { return path }

        let maxTime = max(totalDuration, 0.01)

        for (index, f) in features.enumerated() {
            let x = CGFloat(f.timestamp / maxTime) * size.width
            let y = yPosition(for: f.dbFS, height: size.height)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func yPosition(for dbFS: Float, height: CGFloat) -> CGFloat {
        let clamped = min(max(dbFS, minDisplayDBFS), maxDisplayDBFS)
        let ratio = CGFloat((clamped - minDisplayDBFS) / (maxDisplayDBFS - minDisplayDBFS))
        return height * (1.0 - ratio)
    }

    // MARK: - Spectrogram View
    private var spectrogramView: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                Canvas { context, size in
                    guard !features.isEmpty else { return }
                    let stepWidth = size.width / CGFloat(max(features.count, 1))

                    for (i, f) in features.enumerated() {
                        let x = CGFloat(i) * stepWidth
                        // Draw frequency centroid marker
                        let maxFreq: Float = 4000.0 // Display up to 4 kHz
                        let freqRatio = CGFloat(min(f.dominantFrequency, maxFreq) / maxFreq)
                        let y = size.height * (1.0 - freqRatio)

                        // Draw intensity bar
                        let energyRatio = CGFloat(min(f.rms * 3.0, 1.0))
                        let barHeight = max(energyRatio * size.height, 4)

                        let rect = CGRect(x: x, y: size.height - barHeight, width: max(stepWidth, 1.5), height: barHeight)
                        let color = Color.appTeal.opacity(Double(energyRatio * 0.8 + 0.2))
                        context.fill(Path(rect), with: .color(color))

                        // Dominant freq dot
                        let dotRect = CGRect(x: x - 1, y: y - 1, width: 2.5, height: 2.5)
                        context.fill(Path(ellipseIn: dotRect), with: .color(Color.appBlue))
                    }
                }
            }
            .frame(height: 180)
            .background(Color(hex: "0F172A")) // Dark background for spectrogram
            .cornerRadius(12)

            HStack {
                Text("0 Hz")
                Spacer()
                Text("Dominant Freq Dot • Energy Intensity Bar")
                Spacer()
                Text("4000 Hz")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.slateSub)
        }
    }
}

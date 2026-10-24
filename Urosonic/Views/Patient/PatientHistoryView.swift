// PatientHistoryView.swift — Modern Uroflowmetry History View
// Aura MedTech Design System

import SwiftUI

struct PatientHistoryView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var activeTab: HistoryTab = .all
    @State private var appeared = false
    @State private var isLoading = true
    @State private var measurements: [APIMeasurement] = []

    enum HistoryTab: String, CaseIterable {
        case all = "All Tests"
        case week = "This Week"
        case month = "This Month"
    }

    var filtered: [APIMeasurement] {
        let now = Date()
        return measurements.filter { m in
            guard let rd = rawDate(m.recordedAt) else { return true }
            switch activeTab {
            case .all: return true
            case .week: return Calendar.current.dateComponents([.day], from: rd, to: now).day ?? 0 <= 7
            case .month: return Calendar.current.dateComponents([.day], from: rd, to: now).day ?? 0 <= 30
            }
        }
    }

    var avgQmax: Double {
        guard !filtered.isEmpty else { return 0.0 }
        let total = filtered.map(\.qmax).reduce(0, +)
        return total / Double(filtered.count)
    }

    var normalPercentage: Int {
        guard !filtered.isEmpty else { return 0 }
        let normalCount = filtered.filter { $0.status.uppercased() == "NORMAL" || $0.status.uppercased() == "OK" }.count
        return Int((Double(normalCount) / Double(filtered.count)) * 100)
    }

    struct HistoryGroup: Identifiable {
        let id: String
        let month: String
        let items: [APIMeasurement]
    }

    var grouped: [HistoryGroup] {
        let dict = Dictionary(grouping: filtered) { m -> String in
            guard let d = rawDate(m.recordedAt) else { return "Recent" }
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            return f.string(from: d)
        }
        return dict.map { HistoryGroup(id: $0.key, month: $0.key, items: $0.value) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session History")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("\(measurements.count) total recorded uroflow sessions")
                            .font(.system(size: 12))
                            .foregroundColor(Color.slateSub)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)

                if isLoading && measurements.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else if measurements.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.appTeal.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "tray.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color.appTeal)
                        }
                        Text("No test records yet")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("Start a new uroflowmetry recording to begin building your clinical timeline.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.slateSub)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)

                        PrimaryButton(title: "Record First Test", icon: "mic.fill") {
                            router.startMeasurement()
                        }
                        .padding(.horizontal, 48)
                        .padding(.top, 8)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Filter Pills
                            HStack(spacing: 8) {
                                ForEach(HistoryTab.allCases, id: \.self) { tab in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            activeTab = tab
                                        }
                                    } label: {
                                        Text(tab.rawValue)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(activeTab == tab ? Color.white : Color.slateSub)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(activeTab == tab ? Color.appTeal : Color.slateCard)
                                                    .overlay(
                                                        Capsule().stroke(activeTab == tab ? Color.appTeal : Color.slateBorder, lineWidth: 1)
                                                    )
                                            )
                                            .shadow(color: activeTab == tab ? Color.appTeal.opacity(0.3) : Color.black.opacity(0.02), radius: 4, y: 2)
                                    }
                                    .tactileButton()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .opacity(appeared ? 1 : 0)

                            // Summary Statistics Card
                            if !filtered.isEmpty {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Avg Qmax")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color.slateSub)
                                        Text(String(format: "%.1f mL/s", avgQmax))
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.slateText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Divider().frame(height: 32)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Normal Rate")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color.slateSub)
                                        Text("\(normalPercentage)%")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.uroSuccess)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Divider().frame(height: 32)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Total Tests")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color.slateSub)
                                        Text("\(filtered.count)")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.appTeal)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(16)
                                .uroCard(cornerRadius: 18)
                                .padding(.horizontal, 16)
                                .opacity(appeared ? 1 : 0)
                            }

                            // Grouped Sessions
                            ForEach(Array(grouped.enumerated()), id: \.element.id) { gIdx, group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.month.uppercased())
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.slateSub)
                                        .tracking(0.8)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 4)

                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { mIdx, m in
                                        Button {
                                            router.pendingMeasurementId = m.id
                                            router.showResultFromHistory()
                                        } label: {
                                            HStack(spacing: 14) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(m.displayDate)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(Color.slateSub)

                                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                                        Text(m.formattedQmax)
                                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                                            .foregroundColor(Color.slateText)
                                                    }

                                                    Text("\(m.formattedVolume) • \(m.formattedVoidTime)")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(Color.appTeal)
                                                }

                                                Spacer()

                                                VStack(alignment: .trailing, spacing: 8) {
                                                    StatusBadgeView(status: m.status)
                                                    SparklineView(status: m.statusEnum)
                                                }
                                            }
                                            .padding(16)
                                            .uroCard(cornerRadius: 18)
                                            .padding(.horizontal, 16)
                                        }
                                        .tactileButton()
                                        .offset(x: appeared ? 0 : 20)
                                        .opacity(appeared ? 1 : 0)
                                        .animation(.spring(response: 0.4).delay(Double(mIdx) * 0.04), value: appeared)
                                    }
                                }
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadData() }
        }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        measurements = (try? await APIClient.shared.getMeasurements(patientId: authState.userId)) ?? []
        isLoading = false
    }

    private func rawDate(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        return iso.date(from: s)
    }
}

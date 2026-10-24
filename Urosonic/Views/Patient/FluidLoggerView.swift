// FluidLoggerView.swift — Modern Fluid Intake & Urine Output Tracker
// Aura MedTech Design System

import SwiftUI

enum FluidTrackerTab: String, CaseIterable {
    case intake = "Fluid Intake (In)"
    case output = "Urine Output (Out)"
}

struct FluidLoggerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    // Tab state
    @State private var selectedTab: FluidTrackerTab = .intake

    // Fluid Intake state
    @State private var intakeEntries:  [APIFluidEntry] = []
    @State private var totalIntakeMl   = 0
    @State private var showIntakeSheet = false
    @State private var newDrinkType    = "Water"
    @State private var newDrinkVolume  = ""
    @State private var newDrinkTime    = ""

    // Urine Output state
    @State private var outputEntries:  [APIUrineOutputEntry] = []
    @State private var totalOutputMl   = 0
    @State private var showOutputSheet = false
    @State private var newOutputVolume = ""
    @State private var newOutputUrgency = "Normal"
    @State private var newOutputColor   = "Pale Yellow"
    @State private var newOutputTime    = ""
    @State private var newOutputNotes   = ""

    @State private var appeared   = false
    @State private var isLoading  = false

    let targetFluid = 2000
    var intakePercentage: Double { min(Double(totalIntakeMl) / Double(targetFluid), 1.0) }
    var netBalanceMl: Int { totalIntakeMl - totalOutputMl }

    let drinkTypes = ["Water", "Coffee", "Juice", "Tea", "Electrolytes"]
    let urgencyTypes = ["Normal", "Mild Urgency", "Urgent", "Leak / Incontinence"]
    let colorTypes = ["Pale Straw", "Transparent Yellow", "Dark Amber", "Cloudy"]

    func drinkIconName(_ type: String) -> String {
        switch type {
        case "Coffee": return "cup.and.saucer.fill"
        case "Tea": return "mug.fill"
        case "Juice": return "wineglass.fill"
        case "Electrolytes": return "bolt.fill"
        default: return "drop.fill"
        }
    }

    func drinkIconColor(_ type: String) -> Color {
        switch type {
        case "Coffee": return Color(hex: "92400E")
        case "Tea": return Color(hex: "15803D")
        case "Juice": return Color(hex: "EA580C")
        case "Electrolytes": return Color.appIndigo
        default: return Color.appTeal
        }
    }

    func urgencyColor(_ urgency: String) -> Color {
        switch urgency {
        case "Urgent", "Leak / Incontinence": return Color.uroDanger
        case "Mild Urgency": return Color.uroWarning
        default: return Color.uroSuccess
        }
    }

    func urineColorVisual(_ color: String) -> Color {
        switch color {
        case "Pale Straw": return Color(hex: "FEF08A")
        case "Transparent Yellow": return Color(hex: "FACC15")
        case "Dark Amber": return Color(hex: "D97706")
        case "Cloudy": return Color(hex: "CBD5E1")
        default: return Color(hex: "FACC15")
        }
    }

    var body: some View {
        ZStack {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                BackButtonRow(
                    title: selectedTab == .intake ? "Hydration Tracker" : "Urine Output Tracker",
                    subtitle: selectedTab == .intake ? "Daily Fluid Intake Log" : "Daily Voiding & Output Log"
                ) {
                    if !router.patientHomePath.isEmpty {
                        router.patientHomePath.removeLast()
                    } else {
                        dismiss()
                    }
                }

                // Interactive Segmented Switcher (Intake vs Urine Output)
                HStack(spacing: 6) {
                    ForEach(FluidTrackerTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab == .intake ? "drop.fill" : "toilet.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedTab == tab ?
                                (tab == .intake ? Color.appTeal : Color(hex: "D97706")) :
                                Color.clear
                            )
                            .foregroundColor(selectedTab == tab ? .white : Color.slateSub)
                            .clipShape(Capsule())
                        }
                        .tactileButton()
                    }
                }
                .padding(4)
                .background(Color.slateCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.slateBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                // Compact Net Fluid Balance Pill
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.appTeal)
                        Text("In: \(totalIntakeMl) mL")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                    }

                    Text("•")
                        .foregroundColor(Color.slateBorder)

                    HStack(spacing: 4) {
                        Image(systemName: "toilet.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "D97706"))
                        Text("Out: \(totalOutputMl) mL")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Net:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.slateSub)
                        Text("\(netBalanceMl >= 0 ? "+" : "")\(netBalanceMl) mL")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(netBalanceMl >= 0 ? Color.appTeal : Color(hex: "D97706"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((netBalanceMl >= 0 ? Color.appTeal : Color(hex: "D97706")).opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.slateCard.opacity(0.85))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder.opacity(0.8), lineWidth: 0.8))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                if isLoading && intakeEntries.isEmpty && outputEntries.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if selectedTab == .intake {
                                intakeSectionView
                            } else {
                                urineOutputSectionView
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }

            // Floating Action Button (FAB)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        if selectedTab == .intake {
                            showIntakeSheet = true
                        } else {
                            showOutputSheet = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                            Text(selectedTab == .intake ? "Log Drink" : "Log Urine Output")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: selectedTab == .intake ?
                                    [Color.appTeal, Color(hex: "0F766E")] :
                                    [Color(hex: "D97706"), Color(hex: "B45309")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: (selectedTab == .intake ? Color.appTeal : Color(hex: "D97706")).opacity(0.4),
                            radius: 12,
                            y: 6
                        )
                    }
                    .tactileButton()
                    .padding(.trailing, 20)
                    .padding(.bottom, 36)
                }
            }
        }
        .sheet(isPresented: $showIntakeSheet) {
            AddFluidSheet(
                drinkTypes: drinkTypes,
                iconName: drinkIconName,
                iconColor: drinkIconColor,
                newType: $newDrinkType,
                newVolume: $newDrinkVolume,
                newTime: $newDrinkTime
            ) {
                Task { await addIntakeEntry() }
            }
        }
        .sheet(isPresented: $showOutputSheet) {
            AddUrineOutputSheet(
                urgencyTypes: urgencyTypes,
                colorTypes: colorTypes,
                newVolume: $newOutputVolume,
                newUrgency: $newOutputUrgency,
                newColor: $newOutputColor,
                newTime: $newOutputTime,
                newNotes: $newOutputNotes
            ) {
                Task { await addOutputEntry() }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadData() }
        }
        .refreshable { await loadData() }
    }

    // ─────────────────────────────────────────────
    // MARK: - Intake View Components
    // ─────────────────────────────────────────────
    @ViewBuilder
    private var intakeSectionView: some View {
        // Progress Gauge Card
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Hydration")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slateSub)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(totalIntakeMl)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("/ \(targetFluid) mL")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.appTeal)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.appTeal.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.appTeal)
                }
            }

            // Animated Gradient Capsule
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.slateBorder)
                        .frame(height: 12)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.appTealLight, Color.appCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(intakePercentage), height: 12)
                        .animation(.easeOut(duration: 0.8), value: intakePercentage)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(Int(intakePercentage * 100))% of daily target")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(intakePercentage >= 1.0 ? Color.uroSuccess : Color.slateSub)
                Spacer()
                Text(intakePercentage >= 1.0 ? "Target Reached ✓" : "\(max(0, targetFluid - totalIntakeMl)) mL to go")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appTeal)
            }
        }
        .padding(20)
        .uroCard(cornerRadius: 22)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

        // Quick Log Shortcuts
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(["+150 mL", "+250 mL", "+500 mL"], id: \.self) { amount in
                    Button {
                        let val = Int(amount.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " mL", with: "")) ?? 250
                        Task {
                            newDrinkType = "Water"
                            newDrinkVolume = "\(val)"
                            await addIntakeEntry()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text(amount)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.appTeal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.slateCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.appTeal.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                    }
                    .tactileButton()
                }
            }
            .padding(.horizontal, 16)
        }
        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

        // Logged Intake Entries Section
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(
                title: "Today's Logs",
                badge: intakeEntries.isEmpty ? nil : "\(intakeEntries.count)"
            )

            if intakeEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(Color.slateMuted)
                    Text("No fluid logged yet today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.slateSub)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .uroCard(cornerRadius: 18)
                .padding(.horizontal, 16)
            } else {
                ForEach(Array(intakeEntries.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(drinkIconColor(entry.drinkType).opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: drinkIconName(entry.drinkType))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(drinkIconColor(entry.drinkType))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.drinkType)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)
                            Text(entry.loggedAt ?? "Today")
                                .font(.system(size: 12))
                                .foregroundColor(Color.slateSub)
                        }

                        Spacer()

                        Text("\(entry.volumeMl) mL")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.appTeal)

                        Button {
                            Task { await deleteIntakeEntry(entry) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(Color.uroDanger.opacity(0.7))
                                .padding(8)
                        }
                        .tactileButton()
                    }
                    .padding(14)
                    .uroCard(cornerRadius: 18)
                    .padding(.horizontal, 16)
                    .offset(x: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4).delay(Double(idx) * 0.05), value: appeared)
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Urine Output View Components ("urion outed")
    // ─────────────────────────────────────────────
    @ViewBuilder
    private var urineOutputSectionView: some View {
        // Output Summary Card
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Urine Output")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slateSub)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(totalOutputMl)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("mL")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "D97706"))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(hex: "D97706").opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "toilet.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "D97706"))
                }
            }

            // Clinical Voiding Stat Pills
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "D97706"))
                    Text("\(outputEntries.count) Voids")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.slateLight)
                .clipShape(Capsule())

                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appIndigo)
                    let avg = outputEntries.isEmpty ? 0 : (totalOutputMl / max(1, outputEntries.count))
                    Text("Avg: \(avg) mL/void")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.slateLight)
                .clipShape(Capsule())

                Spacer()

                Text("Normal: 800-2000 mL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.slateSub)
            }

            // Visual Output Range Progress Bar
            let outputPct = min(Double(totalOutputMl) / 2000.0, 1.0)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.slateBorder)
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FACC15"), Color(hex: "D97706")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(outputPct), height: 10)
                        .animation(.easeOut(duration: 0.8), value: outputPct)
                }
            }
            .frame(height: 10)
        }
        .padding(20)
        .uroCard(cornerRadius: 22)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

        // Quick Void Shortcuts
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach([
                    ("150", "+150 mL (Small)"),
                    ("250", "+250 mL (Normal)"),
                    ("350", "+350 mL (Full Void)")
                ], id: \.0) { item in
                    Button {
                        let vol = Int(item.0) ?? 250
                        Task {
                            newOutputVolume = "\(vol)"
                            newOutputUrgency = "Normal"
                            newOutputColor = "Pale Yellow"
                            await addOutputEntry()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text(item.1)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "D97706"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.slateCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "D97706").opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                    }
                    .tactileButton()
                }
            }
            .padding(.horizontal, 16)
        }
        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

        // Logged Urine Output Entries Section
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(
                title: "Today's Urine Voids",
                badge: outputEntries.isEmpty ? nil : "\(outputEntries.count)"
            )

            if outputEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "toilet.fill")
                        .font(.system(size: 38))
                        .foregroundColor(Color.slateMuted)
                    Text("No urine output logged yet today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.slateSub)
                    Text("Tap '+ Log Urine Output' or a quick shortcut above")
                        .font(.system(size: 12))
                        .foregroundColor(Color.slateMuted)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .uroCard(cornerRadius: 18)
                .padding(.horizontal, 16)
            } else {
                ForEach(Array(outputEntries.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "D97706").opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: entry.isTestMeasurement ? "waveform.path.ecg" : "toilet.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "D97706"))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(entry.isTestMeasurement ? "Uroflow Test" : "Urine Void")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.slateText)

                                if let urg = entry.urgency, !urg.isEmpty {
                                    Text(urg)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(urgencyColor(urg).opacity(0.12))
                                        .foregroundColor(urgencyColor(urg))
                                        .clipShape(Capsule())
                                }
                            }

                            HStack(spacing: 6) {
                                Text(entry.loggedAt ?? "Today")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.slateSub)

                                if let col = entry.color, !col.isEmpty {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(urineColorVisual(col))
                                            .frame(width: 7, height: 7)
                                        Text(col)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.slateSub)
                                    }
                                }
                            }
                        }

                        Spacer()

                        Text("\(entry.volumeMl) mL")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "D97706"))

                        Button {
                            Task { await deleteOutputEntry(entry) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(Color.uroDanger.opacity(0.7))
                                .padding(8)
                        }
                        .tactileButton()
                    }
                    .padding(14)
                    .uroCard(cornerRadius: 18)
                    .padding(.horizontal, 16)
                    .offset(x: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4).delay(Double(idx) * 0.05), value: appeared)
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Data Management & Local Fallbacks
    // ─────────────────────────────────────────────
    private func getLocalDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func formattedNow() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }

    private var localIntakeStorageKey: String {
        "local_fluid_intake_\(authState.userId)_\(getLocalDateString())"
    }

    private var localOutputStorageKey: String {
        "local_urine_output_\(authState.userId)_\(getLocalDateString())"
    }

    private func loadData() async {
        isLoading = true
        let todayStr = getLocalDateString()

        // 1. Fetch Fluid Intake
        if let result = try? await APIClient.shared.getFluidLogs(patientId: authState.userId, date: todayStr) {
            intakeEntries = result.entries
            totalIntakeMl = result.total
            // Save cache
            if let enc = try? JSONEncoder().encode(intakeEntries) {
                UserDefaults.standard.set(enc, forKey: localIntakeStorageKey)
            }
        } else if let cached = UserDefaults.standard.data(forKey: localIntakeStorageKey),
                  let dec = try? JSONDecoder().decode([APIFluidEntry].self, from: cached) {
            intakeEntries = dec
            totalIntakeMl = dec.map(\.volumeMl).reduce(0, +)
        }

        // 2. Fetch Urine Output
        if let outResult = try? await APIClient.shared.getUrineOutputLogs(patientId: authState.userId, date: todayStr) {
            outputEntries = outResult.entries
            totalOutputMl = outResult.total
            if let enc = try? JSONEncoder().encode(outputEntries) {
                UserDefaults.standard.set(enc, forKey: localOutputStorageKey)
            }
        } else if let cached = UserDefaults.standard.data(forKey: localOutputStorageKey),
                  let dec = try? JSONDecoder().decode([APIUrineOutputEntry].self, from: cached) {
            outputEntries = dec
            totalOutputMl = dec.map(\.volumeMl).reduce(0, +)
        }

        // 3. Merge today's acoustic test measurements if not already present
        if let measurements = try? await APIClient.shared.getMeasurements(patientId: authState.userId) {
            let todayTests = measurements.filter { m in
                guard let rec = m.recordedAt, rec.starts(with: todayStr) else { return false }
                return m.volume > 0
            }
            for test in todayTests {
                let testTime = test.displayDate.isEmpty ? "Uroflow Test" : test.displayDate
                if !outputEntries.contains(where: { $0.notes == "uroflow_\(test.id)" }) {
                    let synEntry = APIUrineOutputEntry(
                        id: 990000 + test.id,
                        patientId: authState.userId,
                        volumeMl: test.volume,
                        urgency: "Normal",
                        color: "Pale Straw",
                        source: "Uroflow Test",
                        loggedAt: testTime,
                        logDate: todayStr,
                        notes: "uroflow_\(test.id)"
                    )
                    outputEntries.append(synEntry)
                }
            }
            totalOutputMl = outputEntries.map(\.volumeMl).reduce(0, +)
        }

        isLoading = false
    }

    private func addIntakeEntry() async {
        guard let vol = Int(newDrinkVolume), vol > 0 else { return }
        let time = newDrinkTime.isEmpty ? formattedNow() : newDrinkTime
        let todayStr = getLocalDateString()

        if let entry = try? await APIClient.shared.addFluidLog(
            patientId: authState.userId,
            drinkType: newDrinkType,
            volumeMl: vol,
            loggedAt: time,
            logDate: todayStr
        ) {
            withAnimation(.spring()) {
                intakeEntries.insert(entry, at: 0)
                totalIntakeMl += vol
            }
        } else {
            // Local fallback
            let fallbackEntry = APIFluidEntry(
                id: Int(Date().timeIntervalSince1970),
                patientId: authState.userId,
                drinkType: newDrinkType,
                volumeMl: vol,
                loggedAt: time,
                logDate: todayStr
            )
            withAnimation(.spring()) {
                intakeEntries.insert(fallbackEntry, at: 0)
                totalIntakeMl += vol
            }
        }

        if let enc = try? JSONEncoder().encode(intakeEntries) {
            UserDefaults.standard.set(enc, forKey: localIntakeStorageKey)
        }

        newDrinkVolume = ""
        newDrinkTime = ""
        newDrinkType = "Water"
        showIntakeSheet = false
    }

    private func deleteIntakeEntry(_ entry: APIFluidEntry) async {
        try? await APIClient.shared.deleteFluidLog(id: entry.id)
        withAnimation(.spring()) {
            intakeEntries.removeAll { $0.id == entry.id }
            totalIntakeMl = intakeEntries.map(\.volumeMl).reduce(0, +)
        }
        if let enc = try? JSONEncoder().encode(intakeEntries) {
            UserDefaults.standard.set(enc, forKey: localIntakeStorageKey)
        }
    }

    private func addOutputEntry() async {
        guard let vol = Int(newOutputVolume), vol > 0 else { return }
        let time = newOutputTime.isEmpty ? formattedNow() : newOutputTime
        let todayStr = getLocalDateString()

        if let entry = try? await APIClient.shared.addUrineOutputLog(
            patientId: authState.userId,
            volumeMl: vol,
            urgency: newOutputUrgency,
            color: newOutputColor,
            source: "Manual",
            loggedAt: time,
            logDate: todayStr,
            notes: newOutputNotes
        ) {
            withAnimation(.spring()) {
                outputEntries.insert(entry, at: 0)
                totalOutputMl += vol
            }
        } else {
            // Local fallback
            let fallbackEntry = APIUrineOutputEntry(
                id: Int(Date().timeIntervalSince1970),
                patientId: authState.userId,
                volumeMl: vol,
                urgency: newOutputUrgency,
                color: newOutputColor,
                source: "Manual",
                loggedAt: time,
                logDate: todayStr,
                notes: newOutputNotes
            )
            withAnimation(.spring()) {
                outputEntries.insert(fallbackEntry, at: 0)
                totalOutputMl += vol
            }
        }

        if let enc = try? JSONEncoder().encode(outputEntries) {
            UserDefaults.standard.set(enc, forKey: localOutputStorageKey)
        }

        newOutputVolume = ""
        newOutputTime = ""
        newOutputUrgency = "Normal"
        newOutputColor = "Pale Yellow"
        newOutputNotes = ""
        showOutputSheet = false
    }

    private func deleteOutputEntry(_ entry: APIUrineOutputEntry) async {
        try? await APIClient.shared.deleteUrineOutputLog(id: entry.id)
        withAnimation(.spring()) {
            outputEntries.removeAll { $0.id == entry.id }
            totalOutputMl = outputEntries.map(\.volumeMl).reduce(0, +)
        }
        if let enc = try? JSONEncoder().encode(outputEntries) {
            UserDefaults.standard.set(enc, forKey: localOutputStorageKey)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Add Fluid Sheet (Intake)
// ─────────────────────────────────────────────
struct AddFluidSheet: View {
    let drinkTypes: [String]
    let iconName: (String) -> String
    let iconColor: (String) -> Color

    @Binding var newType: String
    @Binding var newVolume: String
    @Binding var newTime: String
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss
    let volumes = ["150", "250", "350", "500", "750"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Drink Type Selection Tiles
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Beverage")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(drinkTypes, id: \.self) { type in
                                    Button {
                                        withAnimation(.spring(response: 0.25)) { newType = type }
                                    } label: {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(newType == type ? iconColor(type) : iconColor(type).opacity(0.12))
                                                    .frame(width: 44, height: 44)
                                                Image(systemName: iconName(type))
                                                    .font(.system(size: 20))
                                                    .foregroundColor(newType == type ? .white : iconColor(type))
                                            }

                                            Text(type)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(newType == type ? Color.slateText : Color.slateSub)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(newType == type ? Color.slateCard : Color.slateCard.opacity(0.7))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(newType == type ? iconColor(type) : Color.slateBorder, lineWidth: newType == type ? 1.5 : 0.8)
                                        )
                                        .shadow(color: newType == type ? iconColor(type).opacity(0.15) : Color.clear, radius: 8, y: 3)
                                    }
                                    .tactileButton()
                                }
                            }
                        }

                        // Volume Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Intake Volume (mL)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            UroInputField(
                                icon: "drop.fill",
                                placeholder: "e.g. 250",
                                text: $newVolume,
                                keyboardType: .numberPad
                            )

                            // Quick preset pills
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(volumes, id: \.self) { vol in
                                        Button {
                                            newVolume = vol
                                        } label: {
                                            Text("\(vol) mL")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(newVolume == vol ? Color.appTeal : Color.slateCard)
                                                .foregroundColor(newVolume == vol ? .white : Color.slateText)
                                                .cornerRadius(10)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(newVolume == vol ? Color.appTeal : Color.slateBorder, lineWidth: 1)
                                                )
                                        }
                                        .tactileButton()
                                    }
                                }
                            }
                        }

                        // Time Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Time (Optional)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            UroInputField(
                                icon: "clock.fill",
                                placeholder: "e.g. 10:30 AM (defaults to now)",
                                text: $newTime
                            )
                        }

                        // Submit Button
                        PrimaryButton(
                            title: "Save Fluid Log",
                            icon: "checkmark"
                        ) {
                            onSave()
                        }
                        .disabled(newVolume.isEmpty)
                        .opacity(newVolume.isEmpty ? 0.6 : 1.0)
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Log Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.slateSub)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Add Urine Output Sheet (Voiding)
// ─────────────────────────────────────────────
struct AddUrineOutputSheet: View {
    let urgencyTypes: [String]
    let colorTypes: [String]

    @Binding var newVolume:  String
    @Binding var newUrgency: String
    @Binding var newColor:   String
    @Binding var newTime:    String
    @Binding var newNotes:   String
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss
    let presetVolumes = ["100", "150", "250", "350", "500"]

    func urgencyColor(_ urgency: String) -> Color {
        switch urgency {
        case "Urgent", "Leak / Incontinence": return Color.uroDanger
        case "Mild Urgency": return Color.uroWarning
        default: return Color.uroSuccess
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Voided Volume Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Voided Volume (mL)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            UroInputField(
                                icon: "toilet.fill",
                                placeholder: "e.g. 250",
                                text: $newVolume,
                                keyboardType: .numberPad
                            )

                            // Quick Presets
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presetVolumes, id: \.self) { vol in
                                        Button {
                                            newVolume = vol
                                        } label: {
                                            Text("\(vol) mL")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(newVolume == vol ? Color(hex: "D97706") : Color.slateCard)
                                                .foregroundColor(newVolume == vol ? .white : Color.slateText)
                                                .cornerRadius(10)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(newVolume == vol ? Color(hex: "D97706") : Color.slateBorder, lineWidth: 1)
                                                )
                                        }
                                        .tactileButton()
                                    }
                                }
                            }
                        }

                        // Urgency Sensation
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Urgency Sensation")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            VStack(spacing: 8) {
                                ForEach(urgencyTypes, id: \.self) { urg in
                                    Button {
                                        withAnimation(.spring(response: 0.25)) { newUrgency = urg }
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(urgencyColor(urg))
                                                .frame(width: 10, height: 10)

                                            Text(urg)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color.slateText)

                                            Spacer()

                                            if newUrgency == urg {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(urgencyColor(urg))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(newUrgency == urg ? urgencyColor(urg).opacity(0.1) : Color.slateCard)
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(newUrgency == urg ? urgencyColor(urg) : Color.slateBorder, lineWidth: 1)
                                        )
                                    }
                                    .tactileButton()
                                }
                            }
                        }

                        // Urine Color / Clarity
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Urine Color / Clarity")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            HStack(spacing: 8) {
                                ForEach(colorTypes, id: \.self) { col in
                                    Button {
                                        withAnimation(.spring(response: 0.25)) { newColor = col }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Circle()
                                                .fill(colorVisual(col))
                                                .frame(width: 22, height: 22)
                                                .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))

                                            Text(col)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(newColor == col ? Color.slateText : Color.slateSub)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(newColor == col ? Color.slateLight : Color.slateCard)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(newColor == col ? Color(hex: "D97706") : Color.slateBorder, lineWidth: newColor == col ? 1.5 : 0.8)
                                        )
                                    }
                                    .tactileButton()
                                }
                            }
                        }

                        // Time Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Time (Optional)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            UroInputField(
                                icon: "clock.fill",
                                placeholder: "e.g. 11:30 AM (defaults to now)",
                                text: $newTime
                            )
                        }

                        // Notes Field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes (Optional)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            UroInputField(
                                icon: "note.text",
                                placeholder: "e.g. Post-wake up void, mild hesitation",
                                text: $newNotes
                            )
                        }

                        // Save Button
                        Button {
                            onSave()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Save Urine Output Log")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "D97706"), Color(hex: "B45309")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: "D97706").opacity(0.35), radius: 10, y: 5)
                        }
                        .disabled(newVolume.isEmpty)
                        .opacity(newVolume.isEmpty ? 0.6 : 1.0)
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Log Urine Output")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.slateSub)
                }
            }
        }
    }

    private func colorVisual(_ color: String) -> Color {
        switch color {
        case "Pale Straw": return Color(hex: "FEF08A")
        case "Transparent Yellow": return Color(hex: "FACC15")
        case "Dark Amber": return Color(hex: "D97706")
        case "Cloudy": return Color(hex: "CBD5E1")
        default: return Color(hex: "FACC15")
        }
    }
}

// DoctorHomeView.swift — Live dashboard data from backend
// Aura MedTech Design System — Next-Gen Clinician Command Center

import SwiftUI

struct DoctorHomeView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    @State private var dashboard:     APIDashboard?        = nil
    @State private var stockItems:    [APIStockItem]       = []
    @State private var surgeries:     [APISurgeryRecord]   = []
    @State private var followUps:     [APIFollowUp]        = []
    @State private var showAddStock   = false
    @State private var appeared       = false
    @State private var isLoading      = true

    // Add stock sheet state
    @State private var newStockName      = ""
    @State private var newStockCategory  = "Disposables"
    @State private var newStockQty       = ""
    @State private var newStockThreshold = ""
    @State private var newStockUnit      = "pieces"

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var lowStockCount: Int {
        stockItems.filter { $0.stockStatus != .ok }.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            if isLoading && dashboard == nil {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.appTeal)
                        .scaleEffect(1.2)
                    Text("Loading Clinical Command Center...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.slateSub)
                        .padding(.top, 12)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 1. Clinician Command Header
                        headerSection

                        // 2. Clinical Operations & Telemetry Grid
                        VStack(spacing: 20) {
                            // ── EXECUTIVE CLINICAL KPI 2x2 GRID ──
                            if let d = dashboard {
                                executiveKPIsGrid(d)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .offset(y: appeared ? 0 : 16)
                                    .opacity(appeared ? 1 : 0)
                            }

                            // ── FAST CLINICAL ACTIONS DOCK ──
                            quickActionsDock
                                .padding(.horizontal, 16)
                                .offset(y: appeared ? 0 : 16)
                                .opacity(appeared ? 1 : 0)

                            // ── LOW STOCK CRITICAL ALERT BANNER ──
                            if lowStockCount > 0 {
                                lowStockAlertBanner
                                    .padding(.horizontal, 16)
                                    .offset(y: appeared ? 0 : 16)
                                    .opacity(appeared ? 1 : 0)
                            }

                            // ── POST-OP FOLLOW-UP QUEUE (Priority 1) ──
                            followUpQueueSection
                                .offset(y: appeared ? 0 : 16)
                                .opacity(appeared ? 1 : 0)

                            // ── RECENT SURGERIES & PROCEDURES (Priority 2) ──
                            surgeriesFeedSection
                                .offset(y: appeared ? 0 : 16)
                                .opacity(appeared ? 1 : 0)

                            // ── CLINICAL EQUIPMENT & SUPPLIES (Priority 3) ──
                            equipmentStockSection
                                .offset(y: appeared ? 0 : 16)
                                .opacity(appeared ? 1 : 0)

                            Spacer(minLength: 110)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .sheet(isPresented: $showAddStock) { addStockSheet }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadData() }
        }
        .refreshable { await loadData() }
    }

    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(todayDateString.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.appCyanLight)
                            .tracking(1.2)

                        Circle()
                            .fill(Color.appCyanLight.opacity(0.6))
                            .frame(width: 4, height: 4)

                        HStack(spacing: 4) {
                            Circle().fill(Color.uroSuccess).frame(width: 6, height: 6)
                            Text("On Clinic Duty")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color.uroSuccess)
                        }
                    }

                    Text("Dr. \(authState.fullName.replacingOccurrences(of: "Dr. ", with: ""))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Chief Urologist & Pelvic Surgeon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appCyanLight.opacity(0.85))
                }

                Spacer()

                Button {
                    router.doctorTab = 4 // Profile
                } label: {
                    AvatarView(
                        initials: authState.initials,
                        size: 48,
                        bg: Color.appTeal.opacity(0.35),
                        fg: Color.appCyanLight,
                        showBadge: true
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appCyanLight.opacity(0.7), Color.appTeal.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .tactileButton()
            }
            .padding(.horizontal, 20)
            .padding(.top, 56) // Accommodate notch / Dynamic Island
            .padding(.bottom, 22)
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color.appNavyDark,
                        Color(hex: "0D192E"),
                        Color(hex: "122543")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [Color.appBlue.opacity(0.18), Color.clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 280
                )
            }
        )
        .clipShape(RoundedCorner(radius: 30, corners: [.bottomLeft, .bottomRight]))
        .shadow(color: Color.appNavyDark.opacity(0.35), radius: 18, y: 8)
    }

    // MARK: - Executive KPI 2x2 Grid
    @ViewBuilder
    private func executiveKPIsGrid(_ d: APIDashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // Card 1: Pending Reviews
            Button {
                router.doctorTab = 1 // Switch to Patient Roster & Triage
            } label: {
                clinicalMetricCard(
                    title: "Pending Triage",
                    value: "\(d.pendingReviews)",
                    subtitle: d.pendingReviews > 0 ? "Requires review" : "Up to date",
                    icon: "waveform.badge.exclamationmark",
                    accent: Color.uroWarning,
                    badgeText: "Triage"
                )
            }
            .tactileButton()

            // Card 2: Total Patients
            Button {
                router.doctorTab = 1
            } label: {
                clinicalMetricCard(
                    title: "Active Patients",
                    value: "\(d.totalPatients)",
                    subtitle: "Enrolled in clinic",
                    icon: "person.2.fill",
                    accent: Color.appTeal,
                    badgeText: "Roster"
                )
            }
            .tactileButton()

            // Card 3: Follow-ups Due
            Button {
                router.openFollowUpReminders()
            } label: {
                clinicalMetricCard(
                    title: "Follow-ups Due",
                    value: "\(d.followupsDue)",
                    subtitle: "Post-op schedule",
                    icon: "calendar.badge.clock",
                    accent: Color.appBlue,
                    badgeText: "Recall"
                )
            }
            .tactileButton()

            // Card 4: Inventory Alerts
            Button {
                router.openStockInventory()
            } label: {
                clinicalMetricCard(
                    title: "Supply Alerts",
                    value: "\(d.lowStockCount)",
                    subtitle: d.lowStockCount > 0 ? "Under threshold" : "Adequate stock",
                    icon: "shippingbox.fill",
                    accent: d.lowStockCount > 0 ? Color.uroDanger : Color.uroSuccess,
                    badgeText: d.lowStockCount > 0 ? "Alert" : "Normal"
                )
            }
            .tactileButton()
        }
    }

    @ViewBuilder
    private func clinicalMetricCard(title: String, value: String, subtitle: String, icon: String, accent: Color, badgeText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accent)
                }

                Spacer()

                Text(badgeText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.slateText)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.slateSub)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .uroCard(cornerRadius: 18)
    }

    // MARK: - Quick Clinical Actions Dock
    @ViewBuilder
    private var quickActionsDock: some View {
        HStack(spacing: 10) {
            Button {
                router.doctorTab = 1
            } label: {
                quickActionButton(icon: "stethoscope", label: "Triage Roster", color: Color.appTeal)
            }
            .tactileButton()

            Button {
                router.doctorTab = 2
            } label: {
                quickActionButton(icon: "plus.circle.fill", label: "Record Surgery", color: Color.appBlue)
            }
            .tactileButton()

            Button {
                showAddStock = true
            } label: {
                quickActionButton(icon: "shippingbox.fill", label: "Add Supply", color: Color.appIndigo)
            }
            .tactileButton()
        }
    }

    @ViewBuilder
    private func quickActionButton(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Low Stock Critical Alert Banner
    @ViewBuilder
    private var lowStockAlertBanner: some View {
        Button {
            router.openStockInventory()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.uroWarning.opacity(0.2))
                        .frame(width: 42, height: 42)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.uroWarning)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Inventory Threshold Alert")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "92400E"))
                    Text("\(lowStockCount) item\(lowStockCount == 1 ? "" : "s") currently below safe restock minimum")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "B45309"))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Restock")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Color(hex: "92400E"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.6))
                .cornerRadius(10)
            }
            .padding(14)
            .background(Color.uroWarningBg.opacity(0.95))
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.uroWarning.opacity(0.4), lineWidth: 1))
            .shadow(color: Color.uroWarning.opacity(0.12), radius: 6, y: 2)
        }
        .tactileButton()
    }

    // MARK: - Post-Op Follow-Up Queue
    @ViewBuilder
    private var followUpQueueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(
                title: "Post-Op Follow-Up Queue",
                badge: followUps.isEmpty ? nil : "\(followUps.count)",
                actionText: "Manage Queue"
            ) {
                router.openFollowUpReminders()
            }

            VStack(spacing: 10) {
                if followUps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(Color.uroSuccess)
                        Text("No follow-ups due today")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.slateSub)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .uroCard(cornerRadius: 16)
                } else {
                    ForEach(followUps.prefix(3)) { f in
                        followUpRow(f)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Recent Surgeries & Procedures
    @ViewBuilder
    private var surgeriesFeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(
                title: "Recent Surgeries & Procedures",
                badge: surgeries.isEmpty ? nil : "\(surgeries.count)",
                actionText: "Surgery Log"
            ) {
                router.doctorTab = 2
            }

            VStack(spacing: 10) {
                if surgeries.isEmpty {
                    Text("No surgeries recorded yet")
                        .font(.system(size: 13))
                        .foregroundColor(Color.slateSub)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .uroCard(cornerRadius: 16)
                } else {
                    ForEach(surgeries.prefix(3)) { s in
                        surgeryRow(s)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Clinical Equipment & Supplies
    @ViewBuilder
    private var equipmentStockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(
                title: "Smart Equipment & Supplies",
                badge: "\(stockItems.count)",
                actionText: "Manage All"
            ) {
                router.openStockInventory()
            }

            VStack(spacing: 10) {
                ForEach(stockItems.prefix(3)) { item in
                    stockRow(item)
                }

                Button {
                    showAddStock = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                        Text("Add New Equipment Item")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.appTeal)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appTeal.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundColor(Color.appTeal.opacity(0.4))
                    )
                }
                .tactileButton()
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Row Views
    @ViewBuilder
    func stockRow(_ item: APIStockItem) -> some View {
        let color: Color = item.stockStatus == .ok ? Color.uroSuccess : item.stockStatus == .low ? Color.uroWarning : Color.uroDanger
        let capacityRatio: Double = item.threshold > 0 ? min(Double(item.currentQty) / Double(item.threshold * 2), 1.0) : 0.5

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slateText)
                    Text("Threshold: \(item.threshold) \(item.unit) • Category: \(item.category)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.slateSub)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.currentQty) \(item.unit)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    StatusBadgeView(status: item.stockStatus.rawValue.uppercased())
                }
            }

            // Visual Fill Gauge
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.slateLight)
                        .frame(height: 5)

                    Capsule()
                        .fill(color)
                        .frame(width: max(8, geo.size.width * CGFloat(capacityRatio)), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .uroCard(cornerRadius: 16)
    }

    @ViewBuilder
    func surgeryRow(_ s: APISurgeryRecord) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.appBlue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(s.patientName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                    Text(s.surgeryType)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTeal)
                }

                Spacer()

                StatusBadgeView(
                    status: s.paymentStatus.lowercased() == "paid" ? "NORMAL" : "LOW",
                    label: s.paymentStatus.capitalized
                )
            }

            Divider()

            HStack {
                Label(s.hospital ?? "General Hospital", systemImage: "building.2")
                    .font(.system(size: 11))
                    .foregroundColor(Color.slateSub)

                Spacer()

                Text("₹\(s.totalFees)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
            }
        }
        .padding(14)
        .uroCard(cornerRadius: 16)
    }

    @ViewBuilder
    func followUpRow(_ f: APIFollowUp) -> some View {
        HStack(spacing: 12) {
            AvatarView(initials: f.avatar ?? "?", size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(f.patientName ?? "Patient")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
                Text("Due: \(f.dueDate ?? "—")")
                    .font(.system(size: 11))
                    .foregroundColor(Color.slateSub)
            }

            Spacer()

            StatusBadgeView(
                status: f.status,
                label: f.daysLeft == 0 ? "Due Today" : f.daysLeft > 0 ? "In \(f.daysLeft)d" : "\(abs(f.daysLeft))d late"
            )
        }
        .padding(14)
        .uroCard(cornerRadius: 16)
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        let did = authState.userId
        async let dash   = try? APIClient.shared.getDashboard(doctorId: did)
        async let stock  = try? APIClient.shared.getStock(doctorId: did)
        async let surg   = try? APIClient.shared.getSurgeries(doctorId: did)
        async let fups   = try? APIClient.shared.getFollowUps(doctorId: did)
        dashboard  = await dash
        stockItems = await stock?.items ?? []
        surgeries  = await surg ?? []
        followUps  = await fups ?? []
        isLoading  = false
    }

    // MARK: - Add Stock Item Sheet
    @ViewBuilder
    var addStockSheet: some View {
        NavigationStack {
            ZStack {
                Color.slateBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            UroInputField(title: "Item Name", text: $newStockName, placeholder: "e.g. Uroflow Beaker 1000mL", icon: "cube.box")
                            UroInputField(title: "Current Quantity", text: $newStockQty, placeholder: "e.g. 50", icon: "number", keyboardType: .numberPad)
                            UroInputField(title: "Minimum Alert Threshold", text: $newStockThreshold, placeholder: "e.g. 10", icon: "exclamationmark.triangle", keyboardType: .numberPad)
                            UroInputField(title: "Unit of Measurement", text: $newStockUnit, placeholder: "pieces, boxes, sets...", icon: "ruler")
                        }
                        .padding(16)
                        .uroCard()

                        PrimaryButton(title: "Add to Inventory", icon: "plus.circle.fill") {
                            Task {
                                guard let q = Int(newStockQty), let t = Int(newStockThreshold), !newStockName.isEmpty else { return }
                                _ = try? await APIClient.shared.addStockItem(
                                    doctorId: authState.userId,
                                    name: newStockName,
                                    category: newStockCategory,
                                    currentQty: q,
                                    threshold: t,
                                    unit: newStockUnit
                                )
                                await loadData()
                                showAddStock = false
                            }
                        }
                        .disabled(newStockName.isEmpty || newStockQty.isEmpty || newStockThreshold.isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Equipment Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddStock = false }
                        .foregroundColor(Color.slateSub)
                }
            }
        }
    }
}

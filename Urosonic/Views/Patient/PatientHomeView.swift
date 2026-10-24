// PatientHomeView.swift — Live data from backend
// Aura MedTech Design System — Next-Gen Medical Telemetry UI

import SwiftUI

struct PatientHomeView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var appeared          = false
    @State private var measurements:     [APIMeasurement] = []
    @State private var fluidSummary:     APIFluidSummary? = nil
    @State private var todayOutputMl:    Int              = 0
    @State private var feedbackList:     [APIFeedback]    = []
    @State private var doctors:          [APIDoctorItem]  = []
    @State private var isLoading         = false
    @State private var isSharingReport   = false
    @State private var sharedSuccessMsg: String?          = nil
    @State private var wavePhase:        CGFloat          = 0

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var fluidPercentage: Double {
        guard let fs = fluidSummary, fs.targetMl > 0 else { return 0.0 }
        return min(Double(fs.totalMl) / Double(fs.targetMl), 1.0)
    }

    private var attendingDoctor: APIDoctorItem? {
        if let docId = authState.currentUser?.doctorId {
            return doctors.first(where: { $0.id == docId }) ?? doctors.first
        }
        return doctors.first
    }

    // Telemetry quick-stat calculations
    private var latestMeasurement: APIMeasurement? {
        measurements.first
    }

    private var greetingTimeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        if hour < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            if isLoading && measurements.isEmpty && fluidSummary == nil {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.appTeal)
                        .scaleEffect(1.2)
                    Text("Syncing Telemetry...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.slateSub)
                        .padding(.top, 12)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 1. Sleek Medical Command Header with Ambient Glow & Hydration Ring
                        headerSection

                        // 2. High-Tech Telemetry & Diagnostic Body Content
                        bodyContentSection
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            Task { await loadData() }
        }
        .refreshable { await loadData() }
    }

    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 18) {
            // Top Safe Area Spacer + Top User Bar
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
                                Text("Acoustic Sensor Ready")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.uroSuccess)
                            }
                        }

                        Text("\(greetingTimeOfDay), \(authState.fullName.components(separatedBy: " ").first ?? "Patient")")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button {
                        router.patientTab = 3 // Profile
                    } label: {
                        AvatarView(
                            initials: authState.initials,
                            size: 46,
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

                // Modernized Hydration Telemetry Card
                hydrationCard
            }
            .padding(.bottom, 20)
        }
        .background(
            ZStack {
                // Multi-layered deep medical gradient
                LinearGradient(
                    colors: [
                        Color.appNavyDark,
                        Color(hex: "0D192E"),
                        Color(hex: "122543")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Ambient Radial Glow
                RadialGradient(
                    colors: [Color.appTeal.opacity(0.18), Color.clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 260
                )
            }
        )
        .clipShape(RoundedCorner(radius: 30, corners: [.bottomLeft, .bottomRight]))
        .shadow(color: Color.appNavyDark.opacity(0.35), radius: 18, y: 8)
        .offset(y: appeared ? 0 : -20)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Hydration Telemetry Card
    @ViewBuilder
    private var hydrationCard: some View {
        let totalMl = fluidSummary?.totalMl ?? 0
        let targetMl = fluidSummary?.targetMl ?? 2000

        VStack(spacing: 14) {
            HStack(spacing: 18) {
                // Glowing Double-Ring Progress Meter
                ZStack {
                    // Outer subtle track
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 72, height: 72)

                    // Secondary track
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 5)
                        .frame(width: 72, height: 72)

                    // Animated Progress Gradient Arc
                    Circle()
                        .trim(from: 0, to: CGFloat(fluidPercentage))
                        .stroke(
                            LinearGradient(
                                colors: [Color.appCyanLight, Color.appTealLight, Color.appCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                        .animation(.easeOut(duration: 0.9), value: fluidPercentage)
                        .shadow(color: Color.appCyan.opacity(0.4), radius: 6, x: 0, y: 0)

                    VStack(spacing: 0) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appCyanLight)
                        Text("\(Int(fluidPercentage * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                // Volume & Status Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("DAILY HYDRATION GOAL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.appCyanLight.opacity(0.9))
                            .tracking(0.8)

                        Spacer()

                        Button {
                            router.openFluidLogger()
                        } label: {
                            HStack(spacing: 3) {
                                Text("Diary")
                                    .font(.system(size: 11, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(Color.appCyanLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(totalMl)")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ \(targetMl) mL in")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "94A3B8"))

                        if todayOutputMl > 0 {
                            Text("•")
                                .foregroundColor(Color.white.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: "toilet.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "FBBF24"))
                                Text("\(todayOutputMl) mL out")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "FDE68A"))
                            }
                        }
                    }

                    // Dynamic Motivation / Remaining Badge
                    HStack(spacing: 5) {
                        Image(systemName: fluidPercentage >= 1.0 ? "checkmark.seal.fill" : "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(fluidPercentage >= 1.0 ? Color.uroSuccess : Color.appCyanLight)

                        Text(fluidPercentage >= 1.0 ? "Target Achieved • Great Hydration!" : "\(max(0, targetMl - totalMl)) mL remaining for today")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(fluidPercentage >= 1.0 ? Color.uroSuccess : Color(hex: "E2E8F0"))
                    }
                }
            }

            // Quick Fluid Preset Tray (Embedded directly for ultra convenience)
            HStack(spacing: 8) {
                quickInlineFluidChip(amount: 150, title: "+150 mL", subtitle: "Cup", icon: "cup.and.saucer.fill")
                quickInlineFluidChip(amount: 250, title: "+250 mL", subtitle: "Glass", icon: "waterbottle.fill")
                quickInlineFluidChip(amount: 500, title: "+500 mL", subtitle: "Bottle", icon: "drop.circle.fill")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func quickInlineFluidChip(amount: Int, title: String, subtitle: String, icon: String) -> some View {
        Button {
            logFluidIntake(amount: amount)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appCyanLight)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .tactileButton()
    }

    // MARK: - Body Content Section
    @ViewBuilder
    private var bodyContentSection: some View {
        VStack(spacing: 20) {
            // ── SUCCESS NOTIFICATION TOAST ──
            if let msg = sharedSuccessMsg {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.uroSuccess)
                        .font(.system(size: 17))
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "065F46"))
                    Spacer()
                    Button { withAnimation { sharedSuccessMsg = nil } } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.slateSub)
                    }
                }
                .padding(14)
                .background(Color.uroSuccessBg)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.uroSuccess.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── FLAGSHIP HERO: ACOUSTIC DIAGNOSTIC SCANNER CARD ──
            acousticHeroScannerCard
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .offset(y: appeared ? 0 : 16)
                .opacity(appeared ? 1 : 0)

            // ── TELEMETRY AT-A-GLANCE STRIP ──
            telemetryStatsStrip
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 16)
                .opacity(appeared ? 1 : 0)

            // ── CONNECTED CARE TEAM / ATTENDING UROLOGIST ──
            if let doc = attendingDoctor {
                attendingDoctorCard(doc)
                    .padding(.horizontal, 16)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
            }

            // ── RECENT DOCTOR CLINICAL REVIEW ──
            if let fb = feedbackList.first {
                clinicalFeedbackCard(fb)
                    .padding(.horizontal, 16)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
            }

            // ── RECENT MEASUREMENTS & HISTORY ──
            recentMeasurementsSection
                .offset(y: appeared ? 0 : 16)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 110)
        }
    }

    // MARK: - Flagship Acoustic Diagnostic Hero Card
    @ViewBuilder
    private var acousticHeroScannerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header badge row
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.uroSuccess)
                        .frame(width: 7, height: 7)
                    Text("ACOUSTIC ML READY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color.uroSuccess)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.uroSuccess.opacity(0.12))
                .cornerRadius(8)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appCyanLight)
                    Text("44.1 kHz PCM")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.appCyanLight)
                }
            }

            // Central Title & Wave Graphic
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start Acoustic Uroflow Test")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Live acoustic audio recording & AI flow rate curve estimation.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer()

                // Animated Soundwave Visualizer Graphic
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 52, height: 52)

                    HStack(spacing: 3) {
                        ForEach(0..<5) { idx in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(colors: [Color.appCyanLight, Color.white], startPoint: .bottom, endPoint: .top))
                                .frame(width: 3.5, height: CGFloat([16, 26, 36, 22, 14][idx]))
                        }
                    }
                }
            }

            // Primary Diagnostic Launch Button
            Button {
                router.startMeasurement()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Begin Voiding Recording")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color(hex: "093430"))
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.white, Color(hex: "D1FAF5")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 3)
            }
            .tactileButton()
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.appTeal, Color(hex: "0D7A70"), Color(hex: "064E48")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.appTeal.opacity(0.35), radius: 14, y: 6)
    }

    // MARK: - Telemetry At-a-Glance Strip
    @ViewBuilder
    private var telemetryStatsStrip: some View {
        HStack(spacing: 10) {
            // Stat 1: Latest Qmax
            telemetryPill(
                title: "Latest Qmax",
                value: latestMeasurement?.formattedQmax ?? "—",
                unit: latestMeasurement != nil ? "" : "",
                status: latestMeasurement?.status ?? "NO DATA",
                icon: "bolt.heart.fill",
                accent: Color.appTeal
            )

            // Stat 2: Voided Volume
            telemetryPill(
                title: "Void Volume",
                value: latestMeasurement?.formattedVolume ?? "—",
                unit: "",
                status: latestMeasurement != nil ? "Measured" : "Ready",
                icon: "chart.bar.xaxis",
                accent: Color.appBlue
            )

            // Stat 3: Total Hydration
            telemetryPill(
                title: "Hydration",
                value: "\(fluidSummary?.totalMl ?? 0)",
                unit: "mL",
                status: "\(Int(fluidPercentage * 100))% Goal",
                icon: "drop.fill",
                accent: Color.appCyan
            )
        }
    }

    @ViewBuilder
    private func telemetryPill(title: String, value: String, unit: String, status: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.slateSub)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.slateSub)
                }
            }

            Text(status)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .uroCard(cornerRadius: 16)
    }

    // MARK: - Attending Doctor Card
    @ViewBuilder
    private func attendingDoctorCard(_ doc: APIDoctorItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(
                    initials: doc.avatarInitials ?? "DR",
                    size: 46,
                    bg: Color.appTeal.opacity(0.15),
                    fg: Color.appTeal
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(doc.fullName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)

                        Circle().fill(Color.uroSuccess).frame(width: 7, height: 7)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appBlue)
                    }

                    Text(doc.specialization ?? "Attending Urologist & Pelvic Specialist")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTeal)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    router.patientTab = 2 // Switch to Messages tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Message Doctor")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        LinearGradient(
                            colors: [Color.appTeal, Color(hex: "0F766E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.appTeal.opacity(0.25), radius: 6, y: 2)
                }
                .tactileButton()

                if let latest = measurements.first {
                    Button {
                        Task { await shareLatestMeasurement(latest, docId: doc.id, docName: doc.fullName) }
                    } label: {
                        HStack(spacing: 6) {
                            if isSharingReport {
                                ProgressView().tint(Color.slateText).scaleEffect(0.8)
                            } else {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text("Transmit Test")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.slateText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.slateCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slateBorder, lineWidth: 1))
                    }
                    .disabled(isSharingReport)
                    .tactileButton()
                }
            }
        }
        .padding(16)
        .uroCard(cornerRadius: 20)
    }

    // MARK: - Clinical Feedback Card
    @ViewBuilder
    private func clinicalFeedbackCard(_ fb: APIFeedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Doctor Clinical Interpretation", systemImage: "stethoscope")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
                Spacer()
                StatusBadgeView(status: fb.interpretation.uppercased(), label: fb.interpretation)
            }

            Text("\"\(fb.clinicalNotes)\"")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.slateSub)
                .italic()

            if let rx = fb.prescription, !rx.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTeal)
                    Text("Rx: \(rx)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slateText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appTeal.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.slateCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appTeal.opacity(0.25), lineWidth: 1.2))
        .shadow(color: Color.appTeal.opacity(0.08), radius: 8, y: 3)
    }

    // MARK: - Recent Measurements Section
    @ViewBuilder
    private var recentMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Recent Voiding Sessions",
                badge: measurements.isEmpty ? nil : "\(measurements.count)",
                actionText: "View History"
            ) {
                router.patientTab = 1
            }

            if measurements.isEmpty {
                // High-Tech Empty State with Guidance
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appTeal.opacity(0.08))
                            .frame(width: 68, height: 68)
                        Circle()
                            .stroke(Color.appTeal.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 82, height: 82)
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundColor(Color.appTeal)
                    }
                    .padding(.top, 8)

                    Text("No Measurements Recorded Yet")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)

                    Text("Record your first acoustic voiding session to generate clinical flow rate curves ($Q_{max}$, $Q_{avg}$, volume).")
                        .font(.system(size: 13))
                        .foregroundColor(Color.slateSub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // 3-step mini guide
                    HStack(spacing: 8) {
                        guideStepPill(step: "1", text: "Place Phone")
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(Color.slateMuted)
                        guideStepPill(step: "2", text: "Tap Record")
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(Color.slateMuted)
                        guideStepPill(step: "3", text: "Void Naturally")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .uroCard(cornerRadius: 22)
                .padding(.horizontal, 16)
            } else {
                ForEach(Array(measurements.prefix(4).enumerated()), id: \.element.id) { idx, m in
                    Button {
                        router.pendingMeasurementId = m.id
                        router.showResultGraph()
                    } label: {
                        HStack(spacing: 14) {
                            // Left: Session Indicator Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(statusColor(m.statusEnum).opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(statusColor(m.statusEnum))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(m.displayDate)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.slateSub)

                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(m.formattedQmax)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                }

                                Text(m.formattedVolume)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.appTeal)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                StatusBadgeView(status: m.status)
                                SparklineView(status: m.statusEnum)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.slateMuted)
                                .padding(.leading, 4)
                        }
                        .padding(14)
                        .uroCard(cornerRadius: 18)
                        .padding(.horizontal, 16)
                    }
                    .tactileButton()
                    .offset(x: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4).delay(0.15 + Double(idx) * 0.06), value: appeared)
                }
            }
        }
    }

    @ViewBuilder
    private func guideStepPill(step: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(step)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Color.appTeal)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.slateText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.slateLight)
        .cornerRadius(10)
    }

    private func statusColor(_ s: MeasurementStatus) -> Color {
        switch s {
        case .normal: return Color.uroSuccess
        case .borderline: return Color.uroWarning
        case .abnormal: return Color.uroDanger
        }
    }

    // MARK: - Action Handlers
    private func logFluidIntake(amount: Int) {
        Task {
            let timeFmt = DateFormatter()
            timeFmt.dateFormat = "h:mm a"
            let timeStr = timeFmt.string(from: Date())

            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            let todayStr = dateFmt.string(from: Date())

            _ = try? await APIClient.shared.addFluidLog(
                patientId: authState.userId,
                drinkType: "Water",
                volumeMl: amount,
                loggedAt: timeStr,
                logDate: todayStr
            )
            await loadData()
        }
    }

    private func shareLatestMeasurement(_ m: APIMeasurement, docId: Int, docName: String) async {
        isSharingReport = true
        let msg = """
        📊 CLINICAL UROFLOWMETRY REPORT
        Measurement Record #\(m.id)
        • Max Flow (Qmax): \(m.formattedQmax)
        • Voided Volume: \(m.formattedVolume)
        • Duration: \(m.formattedVoidTime)
        • Clinical Status: \(m.status)

        Please review my latest acoustic flow rate curve.
        """
        do {
            _ = try await APIClient.shared.sendMessage(senderId: authState.userId, receiverId: docId, text: msg)
            withAnimation(.spring()) {
                sharedSuccessMsg = "Transmitted latest test report (#\(m.id)) to \(docName)."
            }
        } catch {
            print("Failed to share test report: \(error)")
        }
        isSharingReport = false
    }

    private func loadData() async {
        isLoading = true
        let pid = authState.userId
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFmt.string(from: Date())

        async let m = try? APIClient.shared.getMeasurements(patientId: pid)
        async let f = try? APIClient.shared.getFluidSummary(patientId: pid)
        async let uo = try? APIClient.shared.getUrineOutputLogs(patientId: pid, date: todayStr)
        async let fb = try? APIClient.shared.getFeedback(patientId: pid)
        async let docs = try? APIClient.shared.getDoctors()

        measurements  = await m ?? []
        fluidSummary  = await f
        todayOutputMl = await uo?.total ?? 0
        feedbackList  = await fb ?? []
        doctors       = await docs ?? []
        isLoading = false
    }
}

// MARK: - Rounded Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

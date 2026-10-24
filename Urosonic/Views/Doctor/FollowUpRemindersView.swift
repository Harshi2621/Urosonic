// FollowUpRemindersView.swift — Aura MedTech Redesign with Live Backend Integration

import SwiftUI

struct FollowUpRemindersView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var followUps: [APIFollowUp] = []
    @State private var showAdd   = false
    @State private var appeared  = false
    @State private var isLoading = true
    @State private var selectedFilter = "All"

    private let filters = ["All", "Overdue", "Due Today", "Upcoming"]

    var overdueCount:  Int { followUps.filter { $0.followUpStatus == .overdue  }.count }
    var dueCount:      Int { followUps.filter { $0.followUpStatus == .due      }.count }
    var upcomingCount: Int { followUps.filter { $0.followUpStatus == .upcoming }.count }

    var filteredFollowUps: [APIFollowUp] {
        switch selectedFilter {
        case "Overdue":   return followUps.filter { $0.followUpStatus == .overdue }
        case "Due Today": return followUps.filter { $0.followUpStatus == .due }
        case "Upcoming":  return followUps.filter { $0.followUpStatus == .upcoming }
        default:          return followUps
        }
    }

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Clinical Header
                BackButtonRow(
                    title: "Follow-up Queue",
                    subtitle: "\(followUps.count) active patient reminders",
                    action: {
                        if !router.doctorHomePath.isEmpty {
                            router.doctorHomePath.removeLast()
                        } else {
                            dismiss()
                        }
                    }
                )

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(.appTeal).scaleEffect(1.2)
                        Text("Loading reminders...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.slateSub)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 3-Metric Urgency Banner
                            HStack(spacing: 10) {
                                urgencyPill(
                                    count: overdueCount,
                                    label: "Overdue",
                                    icon: "exclamationmark.circle.fill",
                                    color: .uroDanger,
                                    isSelected: selectedFilter == "Overdue"
                                ) {
                                    withAnimation(.spring(response: 0.35)) {
                                        selectedFilter = (selectedFilter == "Overdue") ? "All" : "Overdue"
                                    }
                                }

                                urgencyPill(
                                    count: dueCount,
                                    label: "Due Today",
                                    icon: "clock.badge.exclamationmark.fill",
                                    color: .uroWarning,
                                    isSelected: selectedFilter == "Due Today"
                                ) {
                                    withAnimation(.spring(response: 0.35)) {
                                        selectedFilter = (selectedFilter == "Due Today") ? "All" : "Due Today"
                                    }
                                }

                                urgencyPill(
                                    count: upcomingCount,
                                    label: "Upcoming",
                                    icon: "calendar.badge.clock",
                                    color: .appTeal,
                                    isSelected: selectedFilter == "Upcoming"
                                ) {
                                    withAnimation(.spring(response: 0.35)) {
                                        selectedFilter = (selectedFilter == "Upcoming") ? "All" : "Upcoming"
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)

                            // Quick Filter Tabs
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filters, id: \.self) { filter in
                                        let isSel = selectedFilter == filter
                                        Button {
                                            withAnimation(.spring(response: 0.35)) { selectedFilter = filter }
                                        } label: {
                                            Text(filter)
                                                .font(.system(size: 13, weight: isSel ? .bold : .medium))
                                                .foregroundColor(isSel ? .white : .slateSub)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(isSel ? Color.appTeal : Color.slateCard)
                                                .cornerRadius(20)
                                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSel ? Color.clear : Color.slateBorder, lineWidth: 1))
                                                .shadow(color: isSel ? Color.appTeal.opacity(0.3) : .clear, radius: 6, y: 2)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.top, 2)

                            // Empty State or List
                            if filteredFollowUps.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.system(size: 44))
                                        .foregroundColor(.appTeal.opacity(0.5))
                                    Text("No \(selectedFilter == "All" ? "" : selectedFilter.lowercased()) follow-ups found")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.slateText)
                                    Text("All scheduled consultations are currently up to date.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.slateSub)
                                }
                                .padding(.vertical, 40)
                            } else {
                                ForEach(Array(filteredFollowUps.enumerated()), id: \.element.id) { idx, f in
                                    followUpCard(f, idx: idx)
                                }
                            }

                            // Add Custom Follow-up Dotted Button
                            Button { showAdd = true } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle().fill(Color.appTeal.opacity(0.12)).frame(width: 32, height: 32)
                                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.appTeal)
                                    }
                                    Text("Schedule Custom Follow-up")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.appTeal)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.slateCard)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                        .foregroundColor(Color.appTeal.opacity(0.4))
                                )
                                .shadow(color: .black.opacity(0.02), radius: 6, y: 2)
                            }
                            .buttonStyle(TactileButtonStyle())
                            .padding(.horizontal, 16)
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { addSheet }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadData() }
        }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        followUps = (try? await APIClient.shared.getFollowUps(doctorId: authState.userId)) ?? []
        isLoading = false
    }

    @ViewBuilder
    func urgencyPill(count: Int, label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.slateSub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? color.opacity(0.12) : Color.slateCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : color.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: color.opacity(isSelected ? 0.2 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(TactileButtonStyle())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func followUpCard(_ f: APIFollowUp, idx: Int) -> some View {
        let isOverdue = f.followUpStatus == .overdue
        let isDue = f.followUpStatus == .due
        let color: Color = isOverdue ? .uroDanger : isDue ? .uroWarning : .appTeal

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AvatarView(
                    initials: f.avatar ?? "?",
                    size: 46,
                    bg: color.opacity(0.12),
                    fg: color
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(f.patientName ?? "Patient")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.slateText)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(.slateSub)
                        Text("Due: \(f.dueDate ?? "—")")
                            .font(.system(size: 12))
                            .foregroundColor(.slateSub)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    StatusBadgeView(
                        status: f.status,
                        label: {
                            if f.daysLeft == 0 { return "Due Today" }
                            if f.daysLeft > 0 { return "In \(f.daysLeft)d" }
                            return "\(abs(f.daysLeft))d overdue"
                        }()
                    )

                    // Mini circular progress ring
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.15), lineWidth: 3.5)
                            .frame(width: 26, height: 26)
                        Circle()
                            .trim(from: .zero, to: isOverdue ? 1.0 : min(Double(30 - max(f.daysLeft, 0)) / 30.0, 1.0))
                            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .frame(width: 26, height: 26)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }
            .padding(14)

            // Action Row
            Divider().background(Color.slateBorder.opacity(0.6)).padding(.horizontal, 14)

            HStack(spacing: 12) {
                Button {
                    // Contact action (call patient)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill").font(.system(size: 11))
                        Text("Contact").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(color.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(TactileButtonStyle())

                Button {
                    Task {
                        try? await APIClient.shared.completeFollowUp(id: f.id)
                        await loadData()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        Text("Mark Done").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.uroSuccess)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.uroSuccess.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(TactileButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isOverdue ? Color.uroDanger.opacity(0.3) : Color.slateBorder, lineWidth: 1)
                )
                .shadow(color: isOverdue ? Color.uroDanger.opacity(0.08) : Color.black.opacity(0.03), radius: 8, y: 3)
        )
        .padding(.horizontal, 16)
        .offset(x: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.45).delay(0.06 + Double(idx) * 0.04), value: appeared)
    }

    // MARK: - Add Sheet
    @State private var newPatientIdStr = ""
    @State private var newDueDate      = Date()
    @State private var newNotes        = ""
    @State private var isSubmitting    = false

    @ViewBuilder
    var addSheet: some View {
        NavigationStack {
            ZStack {
                Color.slateBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            UroInputField(
                                title: "Patient ID",
                                text: $newPatientIdStr,
                                placeholder: "e.g. 102",
                                icon: "person.text.rectangle"
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Scheduled Due Date")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.slateSub)
                                DatePicker("", selection: $newDueDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(.appTeal)
                                    .padding(8)
                                    .background(Color.slateCard)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
                            }

                            UroInputField(
                                title: "Clinical Notes (Optional)",
                                text: $newNotes,
                                placeholder: "Post-void residual check, medication review...",
                                icon: "note.text"
                            )
                        }
                        .padding(16)
                        .uroCard()

                        PrimaryButton(title: "Save Follow-up", icon: "calendar.badge.plus", isLoading: isSubmitting) {
                            Task {
                                guard let pid = Int(newPatientIdStr) else { return }
                                isSubmitting = true
                                let fDate = ISO8601DateFormatter().string(from: newDueDate).prefix(10).description
                                if let _ = try? await APIClient.shared.addFollowUp(
                                    doctorId: authState.userId,
                                    patientId: pid,
                                    dueDate: fDate,
                                    notes: newNotes
                                ) {
                                    await loadData()
                                    showAdd = false
                                }
                                isSubmitting = false
                            }
                        }
                        .disabled(newPatientIdStr.isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Follow-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAdd = false }
                        .foregroundColor(.slateSub)
                }
            }
        }
    }
}

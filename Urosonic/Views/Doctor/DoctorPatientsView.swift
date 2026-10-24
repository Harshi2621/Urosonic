// DoctorPatientsView.swift — Live patient roster & triage from backend
// Aura MedTech Design System

import SwiftUI

struct DoctorPatientsView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var patients:  [APIPatientListItem] = []
    @State private var search     = ""
    @State private var activeTab: PatientTab = .all
    @State private var appeared   = false
    @State private var isLoading  = true

    enum PatientTab: String, CaseIterable {
        case all = "All Patients"
        case flagged = "Abnormal / Flagged"
    }

    var filtered: [APIPatientListItem] {
        patients.filter { p in
            let q = search.lowercased().trimmingCharacters(in: .whitespaces)
            let matchesSearch = q.isEmpty || p.name.lowercased().contains(q)
            guard matchesSearch else { return false }
            if activeTab == .flagged { return p.isFlagged || p.latestStatus?.uppercased() == "ABNORMAL" }
            return true
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Patient Roster")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("\(patients.count) active monitored patients")
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

                if isLoading && patients.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            // Search Container
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.appTeal)
                                    .font(.system(size: 15, weight: .semibold))

                                TextField("Search by patient name or ID...", text: $search)
                                    .font(.system(size: 14))
                                    .autocapitalization(.words)
                                    .onChange(of: search) {
                                        Task { await loadPatients() }
                                    }

                                if !search.isEmpty {
                                    Button {
                                        search = ""
                                        Task { await loadPatients() }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color.slateMuted)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Color.slateCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .offset(y: appeared ? 0 : -10).opacity(appeared ? 1 : 0)

                            // Triage Filter Pills
                            HStack(spacing: 8) {
                                ForEach(PatientTab.allCases, id: \.self) { tab in
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
                            .offset(y: appeared ? 0 : -8).opacity(appeared ? 1 : 0)

                            // Patient Cards List
                            if filtered.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.appTeal.opacity(0.1))
                                            .frame(width: 64, height: 64)
                                        Image(systemName: "person.slash")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color.appTeal)
                                    }
                                    Text("No patients match your search")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                    Spacer()
                                }
                                .padding(.top, 40)
                            } else {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, p in
                                    Button {
                                        router.openPatientDetail(id: "\(p.id)")
                                    } label: {
                                        HStack(spacing: 14) {
                                            AvatarView(
                                                initials: p.avatar,
                                                size: 50,
                                                bg: Color.appTeal.opacity(0.12),
                                                fg: Color.appTeal
                                            )

                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack {
                                                    Text(p.name)
                                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                                        .foregroundColor(Color.slateText)
                                                    if p.isFlagged {
                                                        Circle().fill(Color.uroDanger).frame(width: 7, height: 7)
                                                    }
                                                }

                                                Text("Last test: \(p.lastMeasurement ?? "No recordings")")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color.slateSub)

                                                HStack(spacing: 4) {
                                                    Text("Qmax:")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(Color.slateSub)
                                                    Text(p.formattedQmax)
                                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                                        .foregroundColor(Color.appTeal)
                                                }
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 8) {
                                                StatusBadgeView(status: p.latestStatus ?? "NORMAL")
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(Color.slateMuted)
                                            }
                                        }
                                        .padding(14)
                                        .uroCard(cornerRadius: 18)
                                    }
                                    .tactileButton()
                                    .padding(.horizontal, 16)
                                    .offset(x: appeared ? 0 : 20)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.spring(response: 0.4).delay(Double(idx) * 0.04), value: appeared)
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
            Task { await loadPatients() }
        }
        .refreshable { await loadPatients() }
    }

    private func loadPatients() async {
        isLoading = true
        patients = (try? await APIClient.shared.getDoctorPatients(doctorId: authState.userId, search: search)) ?? []
        isLoading = false
    }
}

// SurgeryLogView.swift — Live surgery records & operating log
// Aura MedTech Design System

import SwiftUI

struct SurgeryLogView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var surgeries: [APISurgeryRecord] = []
    @State private var searchQuery = ""
    @State private var showAddSheet = false
    @State private var isLoading = true

    var filteredSurgeries: [APISurgeryRecord] {
        if searchQuery.isEmpty { return surgeries }
        return surgeries.filter {
            $0.patientName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.surgeryType.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.hospital ?? "").localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack(spacing: 12) {
                    Button { router.doctorTab = 0 } label: {
                        ZStack {
                            Circle()
                                .fill(Color.slateCard)
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.slateText)
                        }
                    }
                    .tactileButton()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surgery & OT Log")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("\(surgeries.count) documented procedures")
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

                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.appTeal)
                    TextField("Search by patient, procedure, or hospital...", text: $searchQuery)
                        .font(.system(size: 14))

                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Color.slateMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.slateCard)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                if isLoading && surgeries.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if filteredSurgeries.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.appTeal.opacity(0.1))
                                            .frame(width: 64, height: 64)
                                        Image(systemName: "scissors")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color.appTeal)
                                    }
                                    Text("No surgery records found")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.slateText)
                                    Text("Tap the '+' button below to document a new operating procedure.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.slateSub)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 36)
                                    Spacer()
                                }
                                .padding(.top, 40)
                            } else {
                                ForEach(filteredSurgeries) { surgery in
                                    SurgeryLogCard(surgery: surgery)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    .refreshable { await loadData() }
                }
            }

            // Floating Action Button
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                    Text("Add Surgery")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.appTeal, Color(hex: "0F766E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.appTeal.opacity(0.4), radius: 12, y: 6)
            }
            .tactileButton()
            .padding(.trailing, 20)
            .padding(.bottom, 36)
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            AddFullSurgerySheet(surgeries: $surgeries)
        }
        .onAppear { Task { await loadData() } }
    }

    private func loadData() async {
        isLoading = true
        surgeries = (try? await APIClient.shared.getSurgeries(doctorId: authState.userId)) ?? []
        isLoading = false
    }
}

// MARK: - Surgery Log Card
struct SurgeryLogCard: View {
    let surgery: APISurgeryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AvatarView(
                    initials: surgery.avatar,
                    size: 46,
                    bg: Color.appBlue.opacity(0.12),
                    fg: Color.appBlue
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(surgery.patientName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)

                    Text(surgery.surgeryType)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appTeal)

                    if let ref = surgery.patientIdRef, !ref.isEmpty {
                        Text("Patient ID #\(ref)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.slateSub)
                    }
                }

                Spacer()

                StatusBadgeView(status: surgery.paymentStatus)
            }

            Divider()

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(surgery.surgeryDate ?? "—")
                }

                HStack(spacing: 4) {
                    Image(systemName: "building.2.fill")
                    Text(surgery.hospital ?? "General Hospital").lineLimit(1)
                }

                Spacer()

                Text("₹\(surgery.professionalFees + surgery.instrumentCharges)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slateText)
            }
            .font(.system(size: 12))
            .foregroundColor(Color.slateSub)
        }
        .padding(16)
        .uroCard(cornerRadius: 20)
    }
}

// MARK: - Add Full Surgery Sheet
struct AddFullSurgerySheet: View {
    @EnvironmentObject var authState: AuthState
    @Binding var surgeries: [APISurgeryRecord]
    @Environment(\.dismiss) var dismiss

    @State private var date = Date()
    @State private var hospital = ""
    @State private var myRole = "Primary Surgeon"
    @State private var patientName = ""
    @State private var patientId   = ""
    @State private var phoneNumber = ""
    @State private var diagnoses: [String] = [""]
    @State private var surgeryType = ""
    @State private var profFees = ""
    @State private var instCharges = ""
    @State private var paymentStatus = "Pending"
    @State private var consumables: [String] = [""]
    @State private var rentalName = ""
    @State private var rentalFees = ""
    @State private var team: [APITeamMember] = [
        APITeamMember(id: 0, surgeryId: 0, role: "Assistant", memberName: "", fees: 0, paymentStatus: "Pending")
    ]
    @State private var stentType = ""
    @State private var stentDueDate = Date()
    @State private var stentStatus = "N/A"
    @State private var remarks = ""

    let roles = ["Primary Surgeon", "Assistant Surgeon", "Consultant"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient & Facility") {
                    DatePicker("Surgery Date", selection: $date, displayedComponents: .date)
                    TextField("Hospital / Clinic Name", text: $hospital)
                    Picker("Surgical Role", selection: $myRole) {
                        ForEach(roles, id: \.self) { Text($0) }
                    }
                    TextField("Patient Name", text: $patientName)
                    TextField("Patient ID / Ref", text: $patientId)
                    TextField("Contact Phone", text: $phoneNumber).keyboardType(.phonePad)
                }

                Section("Procedure Information") {
                    TextField("Procedure Name (e.g. TURP, URS, PCNL)", text: $surgeryType)
                    ForEach($diagnoses.indices, id: \.self) { idx in
                        HStack {
                            TextField("Diagnosis \(idx + 1)", text: $diagnoses[idx])
                            if diagnoses.count > 1 {
                                Button { diagnoses.remove(at: idx) } label: {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button("Add Another Diagnosis") { diagnoses.append("") }
                        .foregroundColor(Color.appTeal)
                }

                Section("Billing & Fees (₹)") {
                    TextField("Professional Fees", text: $profFees).keyboardType(.numberPad)
                    TextField("Instrument Charges", text: $instCharges).keyboardType(.numberPad)
                    Picker("Payment Status", selection: $paymentStatus) {
                        ForEach(["Paid", "Pending", "Partial"], id: \.self) { Text($0) }
                    }
                }

                Section("Clinical Notes & Remarks") {
                    TextEditor(text: $remarks).frame(height: 80)
                }
            }
            .navigationTitle("Add Surgery Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.slateSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Record") { saveSurgery() }
                        .disabled(patientName.isEmpty || surgeryType.isEmpty)
                        .foregroundColor(Color.appTeal)
                }
            }
        }
    }

    private func saveSurgery() {
        Task {
            let dateStr = ISO8601DateFormatter().string(from: date).prefix(10).description
            let pFees = Int(profFees) ?? 0
            let iFees = Int(instCharges) ?? 0
            let rFees = Int(rentalFees) ?? 0

            let surgeryBody: [String: Any] = [
                "doctor_id": authState.userId,
                "surgery_date": dateStr,
                "hospital": hospital,
                "my_role": myRole,
                "patient_name": patientName,
                "patient_id_ref": patientId,
                "phone_number": phoneNumber,
                "surgery_type": surgeryType,
                "diagnoses": diagnoses,
                "professional_fees": pFees,
                "instrument_charges": iFees,
                "payment_status": paymentStatus,
                "consumables": consumables,
                "rental_name": rentalName,
                "rental_fees": rFees,
                "team": team.map { [
                    "role": $0.role ?? "",
                    "member_name": $0.memberName ?? "",
                    "fees": $0.fees,
                    "payment_status": $0.paymentStatus
                ] },
                "stent_type": stentType,
                "stent_due_date": "",
                "stent_status": stentStatus,
                "remarks": remarks
            ]

            if let s = try? await APIClient.shared.addSurgery(body: surgeryBody) {
                withAnimation(.spring()) {
                    surgeries.insert(s, at: 0)
                }
                dismiss()
            }
        }
    }
}

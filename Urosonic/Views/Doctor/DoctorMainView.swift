// DoctorMainView.swift — Doctor TabView with NavigationStacks routed via AppRouter

import SwiftUI

struct DoctorMainView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: Binding(
            get: { router.doctorTab },
            set: { newTab in
                if newTab == 3 {
                    NotificationCenter.default.post(name: .resetDoctorMessagesToRoot, object: nil)
                }
                router.doctorTab = newTab
            }
        )) {
            // MARK: - Tab 0: Home
            NavigationStack(path: $router.doctorHomePath) {
                DoctorHomeView()
                    .navigationBarHidden(true)
                    .navigationDestination(for: DoctorHomeDestination.self) { dest in
                        switch dest {
                        case .writeFeedback:      WriteFeedbackView().navigationBarHidden(true)
                        case .stockInventory:     StockInventoryView().navigationBarHidden(true)
                        case .followUpReminders:  FollowUpRemindersView().navigationBarHidden(true)
                        }
                    }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            // MARK: - Tab 1: Patients
            NavigationStack(path: $router.doctorPatientsPath) {
                DoctorPatientsView()
                    .navigationBarHidden(true)
                    .navigationDestination(for: DoctorPatientsDestination.self) { dest in
                        switch dest {
                        case .patientDetail(let id): DoctorPatientDetailView(patientId: id).navigationBarHidden(true)
                        case .writeFeedback:          WriteFeedbackView().navigationBarHidden(true)
                        }
                    }
            }
            .tabItem { Label("Patients", systemImage: "person.2.fill") }
            .tag(1)

            // MARK: - Tab 2: Surgery
            NavigationStack {
                SurgeryLogView()
                    .navigationBarHidden(true)
            }
            .tabItem { Label("Surgery", systemImage: "scissors") }
            .tag(2)

            // MARK: - Tab 3: Messages
            NavigationStack {
                DoctorMessagesView()
                    .navigationBarHidden(true)
            }
            .tabItem { Label("Messages", systemImage: "message.fill") }
            .tag(3)

            // MARK: - Tab 4: Profile
            NavigationStack {
                DoctorProfileView()
                    .navigationBarHidden(true)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(4)
        }
        .accentColor(.appTeal)
    }
}

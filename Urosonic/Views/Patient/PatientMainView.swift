// PatientMainView.swift — Patient TabView with NavigationStacks routed via AppRouter

import SwiftUI

struct PatientMainView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: Binding(
            get: { router.patientTab },
            set: { newTab in
                if newTab == 2 {
                    NotificationCenter.default.post(name: .resetPatientMessagesToRoot, object: nil)
                }
                router.patientTab = newTab
            }
        )) {
            // MARK: - Tab 0: Home
            NavigationStack(path: $router.patientHomePath) {
                PatientHomeView()
                    .navigationBarHidden(true)
                    .navigationDestination(for: PatientHomeDestination.self) { dest in
                        switch dest {
                        case .activeRecording: ActiveRecordingView().navigationBarHidden(true)
                        case .volumeEntry:     VolumeEntryView().navigationBarHidden(true)
                        case .resultGraph:     ResultGraphView().navigationBarHidden(true)
                        case .fluidLogger:     FluidLoggerView().navigationBarHidden(true)
                        }
                    }
            }
            .tabItem { Label("Home",    systemImage: "house.fill") }
            .tag(0)

            // MARK: - Tab 1: History
            NavigationStack(path: $router.patientHistoryPath) {
                PatientHistoryView()
                    .navigationBarHidden(true)
                    .navigationDestination(for: PatientHistoryDestination.self) { dest in
                        switch dest {
                        case .resultGraph: ResultGraphView().navigationBarHidden(true)
                        }
                    }
            }
            .tabItem { Label("History", systemImage: "clock.fill") }
            .tag(1)

            // MARK: - Tab 2: Messages
            NavigationStack {
                PatientMessagesView()
                    .navigationBarHidden(true)
            }
            .tabItem { Label("Messages", systemImage: "message.fill") }
            .tag(2)

            // MARK: - Tab 3: Profile
            NavigationStack {
                PatientProfileView()
                    .navigationBarHidden(true)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(3)
        }
        .accentColor(.appTeal)
    }
}

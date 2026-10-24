// ContentView.swift — Root Router: reads AppRouter and presents the right screen

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    var body: some View {
        Group {
            switch router.screen {
            case .splash:        SplashView()
            case .login:         LoginView()
            case .register:      RegisterView()
            case .forgotPassword:ForgotPasswordView()
            case .patient:       PatientMainView()
            case .doctor:        DoctorMainView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.screen)
    }
}

#Preview { ContentView() }

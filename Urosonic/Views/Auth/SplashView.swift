// SplashView.swift — High-tech Medical Acoustic Splash screen
// Aura MedTech Design System

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var scale: CGFloat  = 0.85
    @State private var opacity: Double = 0.0
    @State private var ringPulse: Bool = false
    @State private var dotPulse: Bool  = false

    var body: some View {
        ZStack {
            // Dark Medical Background
            LinearGradient(
                colors: [Color.appNavyDark, Color.appNavy, Color(hex: "0A1E32")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient Glow Blobs
            Circle()
                .fill(Color.appTeal.opacity(0.12))
                .frame(width: 320, height: 320)
                .offset(x: 100, y: -120)
                .blur(radius: 70)

            Circle()
                .fill(Color.appCyan.opacity(0.10))
                .frame(width: 260, height: 260)
                .offset(x: -90, y: 140)
                .blur(radius: 60)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Logo Container with Acoustic Pulse Rings
                    ZStack {
                        // Outer Pulsing Aura Ring
                        Circle()
                            .stroke(Color.appTeal.opacity(ringPulse ? 0.0 : 0.4), lineWidth: ringPulse ? 2 : 1)
                            .frame(width: 220, height: 220)
                            .scaleEffect(ringPulse ? 1.25 : 0.9)

                        Circle()
                            .stroke(Color.appCyan.opacity(ringPulse ? 0.0 : 0.5), lineWidth: ringPulse ? 2 : 1)
                            .frame(width: 190, height: 190)
                            .scaleEffect(ringPulse ? 1.18 : 0.95)

                        // Central Frosted Emblem
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appNavyLight.opacity(0.8), Color.appNavyDark.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 150, height: 150)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.appTealLight.opacity(0.7), Color.appCyan.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color.appTeal.opacity(0.35), radius: 25, y: 10)

                            Image("UroflowLogo_v1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        }
                    }

                    // Brand Typography
                    VStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("URO")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("SONIC")
                                .font(.system(size: 38, weight: .light, design: .rounded))
                                .foregroundColor(Color.appTealLight)
                        }
                        .shadow(color: Color.appTeal.opacity(0.3), radius: 10, y: 4)

                        Text("Acoustic Precision Uroflowmetry")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.appCyan.opacity(0.9))
                            .tracking(1.2)
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Spacer()

                // High-tech loader dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.appTealLight)
                            .frame(width: 7, height: 7)
                            .scaleEffect(dotPulse ? 1.3 : 0.8)
                            .opacity(dotPulse ? 1.0 : 0.4)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.18),
                                value: dotPulse
                            )
                    }
                }
                .opacity(opacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                scale   = 1.0
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                ringPulse = true
            }
            dotPulse = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let user = SessionManager.shared.restoreSession() {
                    authState.set(user)
                    if user.role == "doctor" {
                        router.loginAsDoctor()
                    } else {
                        router.loginAsPatient()
                    }
                    // Silently refresh profile in background
                    Task {
                        _ = try? await SessionManager.shared.refreshSessionProfile()
                    }
                } else {
                    router.navigate(to: .login)
                }
            }
        }
    }
}

// AuthState.swift — Single source of truth for the logged-in user

import SwiftUI
import Combine

@MainActor
final class AuthState: ObservableObject {
    @Published var currentUser: APIUser? = nil

    init() {
        if let restored = SessionManager.shared.restoreSession() {
            self.currentUser = restored
        }
    }

    var isLoggedIn: Bool { currentUser != nil }
    var userId:     Int    { currentUser?.id   ?? 0   }
    var role:       String { currentUser?.role ?? ""  }
    var isDoctor:   Bool   { role.lowercased() == "doctor" }
    var isPatient:  Bool   { role.lowercased() == "patient" }
    var initials:   String { currentUser?.initials ?? "?" }
    var fullName:   String { currentUser?.fullName ?? "User" }
    var email:      String { currentUser?.email ?? "" }
    var phone:      String { currentUser?.phone ?? "" }
    var doctorId:   Int?   { currentUser?.doctorId }

    func set(_ user: APIUser, token: String? = nil) {
        currentUser = user
        SessionManager.shared.startSession(user: user, token: token)
    }

    func clear() {
        currentUser = nil
        SessionManager.shared.endSession()
    }
}

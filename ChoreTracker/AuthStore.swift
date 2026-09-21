import Foundation

@MainActor
final class AuthStore: ObservableObject {
    enum Stage {
        case email
        case code
        case profile
        case signedIn
    }

    @Published var stage: Stage = .email
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var name = ""
    @Published var role: MemberRole = .parent
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionKey = "chore-tracker.auth-session.v3"
    private let emailKey = "chore-tracker.auth-email.v1"
    private let nameKey = "chore-tracker.auth-name.v1"
    private let roleKey = "chore-tracker.auth-role.v1"

    init() {
        if UserDefaults.standard.bool(forKey: sessionKey),
           KeychainStore.shared.read("better-auth-token") != nil {
            email = UserDefaults.standard.string(forKey: emailKey) ?? ""
            name = UserDefaults.standard.string(forKey: nameKey) ?? ""
            if let savedRole = UserDefaults.standard.string(forKey: roleKey),
               let role = MemberRole(rawValue: savedRole) {
                self.role = role
            }
            stage = .signedIn
        }
    }

    var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var canSendCode: Bool {
        let value = normalizedEmail
        let parts = value.split(separator: "@")
        return parts.count == 2 && parts[0].count > 0 && parts[1].contains(".")
    }

    var canVerifyCode: Bool {
        verificationCode.filter(\.isNumber).count == 6
    }

    func sendCode() async {
        guard canSendCode else {
            errorMessage = "Enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await EmailAuthService.shared.requestCode(for: normalizedEmail)
            stage = .code
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isLoading = false
    }

    func verifyCode() async {
        guard canVerifyCode else {
            errorMessage = "Enter the 6-digit code."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = try await EmailAuthService.shared.verify(
                email: normalizedEmail,
                code: verificationCode.filter(\.isNumber)
            )
            try KeychainStore.shared.save(token, for: "better-auth-token")
            stage = .profile
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isLoading = false
    }

    private func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "You’re offline. Check your connection and try again."
            case .cannotConnectToHost, .cannotFindHost:
                return "The sign-in service isn’t reachable right now. Try again in a moment."
            case .timedOut:
                return "The sign-in request timed out. Try again."
            default:
                break
            }
        }

        return error.localizedDescription
    }

    func finishProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter your name."
            return
        }

        UserDefaults.standard.set(true, forKey: sessionKey)
        UserDefaults.standard.set(normalizedEmail, forKey: emailKey)
        UserDefaults.standard.set(trimmedName, forKey: nameKey)
        UserDefaults.standard.set(role.rawValue, forKey: roleKey)
        stage = .signedIn
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: roleKey)
        KeychainStore.shared.delete("better-auth-token")
        KeychainStore.shared.delete("auth-token")

        email = ""
        verificationCode = ""
        name = ""
        role = .parent
        errorMessage = nil
        stage = .email
    }
}

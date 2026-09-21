import Foundation

@MainActor
final class AuthStore: ObservableObject {
    enum Stage {
        case phone
        case code
        case profile
        case signedIn
    }

    @Published var stage: Stage = .phone
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var name = ""
    @Published var role: MemberRole = .parent
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionKey = "chore-tracker.auth-session.v1"
    private let phoneKey = "chore-tracker.auth-phone.v1"
    private let nameKey = "chore-tracker.auth-name.v1"
    private let roleKey = "chore-tracker.auth-role.v1"

    init() {
        if UserDefaults.standard.bool(forKey: sessionKey) {
            phoneNumber = UserDefaults.standard.string(forKey: phoneKey) ?? ""
            name = UserDefaults.standard.string(forKey: nameKey) ?? ""
            if let savedRole = UserDefaults.standard.string(forKey: roleKey),
               let role = MemberRole(rawValue: savedRole) {
                self.role = role
            }
            stage = .signedIn
        }
    }

    var normalizedPhoneNumber: String {
        let digits = phoneNumber.filter(\.isNumber)

        if digits.count == 10 {
            return "+1" + digits
        }

        if digits.count == 11 && digits.first == "1" {
            return "+" + digits
        }

        return phoneNumber.hasPrefix("+") ? phoneNumber : "+" + digits
    }

    var canSendCode: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 10
    }

    var canVerifyCode: Bool {
        verificationCode.filter(\.isNumber).count == 6
    }

    func sendCode() async {
        guard canSendCode else {
            errorMessage = "Enter a valid phone number."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await PhoneAuthService.shared.requestCode(for: normalizedPhoneNumber)
            stage = .code
        } catch {
            errorMessage = error.localizedDescription
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
            try await PhoneAuthService.shared.verify(
                phoneNumber: normalizedPhoneNumber,
                code: verificationCode.filter(\.isNumber)
            )
            stage = .profile
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func finishProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter your name."
            return
        }

        UserDefaults.standard.set(true, forKey: sessionKey)
        UserDefaults.standard.set(normalizedPhoneNumber, forKey: phoneKey)
        UserDefaults.standard.set(trimmedName, forKey: nameKey)
        UserDefaults.standard.set(role.rawValue, forKey: roleKey)
        stage = .signedIn
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: phoneKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: roleKey)

        phoneNumber = ""
        verificationCode = ""
        name = ""
        role = .parent
        errorMessage = nil
        stage = .phone
    }
}

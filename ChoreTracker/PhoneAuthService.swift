import Foundation

actor PhoneAuthService {
    static let shared = PhoneAuthService()

    enum PhoneAuthError: LocalizedError {
        case invalidCode
        case backendNotConfigured

        var errorDescription: String? {
            switch self {
            case .invalidCode:
                return "That verification code is not correct."
            case .backendNotConfigured:
                return "Phone verification backend is not connected yet."
            }
        }
    }

    // Development-only verification code.
    // Replace this service with the production SMS API before TestFlight/App Store release.
    private let developmentCode = "123456"

    func requestCode(for phoneNumber: String) async throws {
        guard phoneNumber.count >= 11 else {
            throw PhoneAuthError.backendNotConfigured
        }

        try await Task.sleep(for: .milliseconds(450))
    }

    func verify(phoneNumber: String, code: String) async throws {
        try await Task.sleep(for: .milliseconds(350))

        guard code == developmentCode else {
            throw PhoneAuthError.invalidCode
        }
    }
}

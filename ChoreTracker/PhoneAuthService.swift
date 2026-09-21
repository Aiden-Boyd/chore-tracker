import Foundation

enum AuthConfiguration {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://127.0.0.1:3000")!
    #else
    // Change this to your production VPS API URL before App Store release.
    static let apiBaseURL = URL(string: "https://auth.newlifemedia.co")!
    #endif
}

actor EmailAuthService {
    static let shared = EmailAuthService()

    enum AuthError: LocalizedError {
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The authentication server returned an invalid response."
            case .server(let message):
                return message
            }
        }
    }

    private struct RequestCodeBody: Encodable {
        let email: String
        let type = "sign-in"
    }

    private struct VerifyBody: Encodable {
        let email: String
        let otp: String
    }

        private struct ErrorResponse: Decodable {
        let message: String?
        let error: String?
    }

    func requestCode(for email: String) async throws {
        let url = AuthConfiguration.apiBaseURL.appending(path: "api/auth/email-otp/send-verification-otp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestCodeBody(email: email))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func verify(email: String, code: String) async throws -> String {
        let url = AuthConfiguration.apiBaseURL.appending(path: "api/auth/sign-in/email-otp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(VerifyBody(email: email, otp: code))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        guard let http = response as? HTTPURLResponse,
              let token = http.value(forHTTPHeaderField: "set-auth-token"),
              !token.isEmpty else {
            throw AuthError.invalidResponse
        }

        return token
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let result = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AuthError.server(result.message ?? result.error ?? "Authentication failed. Please try again.")
            }
            throw AuthError.server("Authentication failed. Please try again.")
        }
    }
}

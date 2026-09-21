import Foundation

enum AuthConfiguration {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://127.0.0.1:3000")!
    #else
    // Change this to your production VPS API URL before App Store release.
    static let apiBaseURL = URL(string: "https://api.example.com")!
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
    }

    private struct VerifyBody: Encodable {
        let email: String
        let code: String
    }

    private struct VerifyResponse: Decodable {
        let token: String
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }

    func requestCode(for email: String) async throws {
        let url = AuthConfiguration.apiBaseURL.appending(path: "auth/request-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestCodeBody(email: email))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func verify(email: String, code: String) async throws -> String {
        let url = AuthConfiguration.apiBaseURL.appending(path: "auth/verify-code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(VerifyBody(email: email, code: code))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        guard let result = try? JSONDecoder().decode(VerifyResponse.self, from: data),
              !result.token.isEmpty else {
            throw AuthError.invalidResponse
        }

        return result.token
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let result = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AuthError.server(result.error)
            }
            throw AuthError.server("Authentication failed. Please try again.")
        }
    }
}

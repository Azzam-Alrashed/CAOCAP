import Foundation
import OSLog

enum GitHubPagesError: LocalizedError {
    case invalidURL
    case invalidResponse(Int)
    case buildFailed(String)
    case buildTimedOut
    case privateRepoUnavailable
    case enableFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub Pages API URL."
        case .invalidResponse(let code):
            return "GitHub Pages returned an unexpected response (HTTP \(code))."
        case .buildFailed(let message):
            return "GitHub Pages build failed: \(message)"
        case .buildTimedOut:
            return "GitHub Pages is taking longer than expected. Try again in a minute."
        case .privateRepoUnavailable:
            return "Private repositories require GitHub Pro for GitHub Pages. Turn off \"Make repository private\" or upgrade your GitHub plan."
        case .enableFailed(let message):
            return message
        }
    }
}

/// GitHub Pages enablement and build polling for published Mini-Apps.
struct GitHubPagesService {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "GitHubPages")

    private let pollTimeoutSeconds: TimeInterval = 90
    private let initialPollDelaySeconds: TimeInterval = 2

    static func publishedURL(owner: String, repo: String) -> String {
        "https://\(owner.lowercased()).github.io/\(repo)/"
    }

    static func firebaseHost(owner: String) -> String {
        "\(owner.lowercased()).github.io"
    }

    static func userFacingError(from statusCode: Int, body: String, isPrivateRepo: Bool) -> GitHubPagesError {
        if isPrivateRepo, isPrivatePagesError(statusCode: statusCode, body: body) {
            return .privateRepoUnavailable
        }
        if let message = parseGitHubMessage(body) {
            return .enableFailed("GitHub Pages Error: \(message)")
        }
        return .enableFailed("GitHub Pages Error (HTTP \(statusCode)).")
    }

    static func isPrivatePagesError(statusCode: Int, body: String) -> Bool {
        let lowered = body.lowercased()
        if statusCode == 422 || statusCode == 403 {
            return lowered.contains("private") ||
                lowered.contains("billing") ||
                lowered.contains("upgrade") ||
                lowered.contains("pro")
        }
        return false
    }

    static func parseGitHubMessage(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return body.isEmpty ? nil : body
        }
        if let message = json["message"] as? String { return message }
        return nil
    }

    func pagesEnabled(owner: String, repo: String, token: String) async throws -> Bool {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pages") else {
            throw GitHubPagesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubPagesError.invalidResponse(0)
        }

        if httpResponse.statusCode == 404 { return false }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Self.userFacingError(from: httpResponse.statusCode, body: body, isPrivateRepo: false)
        }
        return true
    }

    func enablePages(owner: String, repo: String, token: String, isPrivateRepo: Bool) async throws {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pages") else {
            throw GitHubPagesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "source": [
                "branch": "main",
                "path": "/"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubPagesError.invalidResponse(0)
        }

        if httpResponse.statusCode == 409 {
            // Pages already enabled on this repository.
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            Self.logger.error("Enable Pages failed (\(httpResponse.statusCode)): \(responseBody)")
            throw Self.userFacingError(from: httpResponse.statusCode, body: responseBody, isPrivateRepo: isPrivateRepo)
        }
    }

    func pollUntilLive(owner: String, repo: String, token: String) async throws {
        let deadline = Date().addingTimeInterval(pollTimeoutSeconds)
        var delay = initialPollDelaySeconds

        while Date() < deadline {
            if let status = try await latestBuildStatus(owner: owner, repo: repo, token: token) {
                switch status {
                case "built":
                    return
                case "errored":
                    throw GitHubPagesError.buildFailed("The GitHub Pages build failed.")
                default:
                    break
                }
            }

            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay = min(delay * 1.5, 8)
        }

        throw GitHubPagesError.buildTimedOut
    }

    private func latestBuildStatus(owner: String, repo: String, token: String) async throws -> String? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pages/builds/latest") else {
            throw GitHubPagesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubPagesError.invalidResponse(0)
        }

        if httpResponse.statusCode == 404 { return nil }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitHubPagesError.enableFailed("GitHub Pages build status error (HTTP \(httpResponse.statusCode)): \(body)")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            return status
        }
        return nil
    }
}

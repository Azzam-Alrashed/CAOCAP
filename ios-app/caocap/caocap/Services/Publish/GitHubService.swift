import Foundation
import OSLog

enum GitHubError: Error {
    case invalidURL
    case invalidResponse
    case decodedFailed(Error)
    case unknown
}

struct GitHubRepo: Codable, Equatable {
    let id: Int
    let name: String
    let htmlUrl: String
    let `private`: Bool
    let cloneUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case htmlUrl = "html_url"
        case `private` = "private"
        case cloneUrl = "clone_url"
    }
}

/// GitHub REST API for creating repos and pushing Mini-App `index.html`.
struct GitHubService {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "GitHubService")

    func createRepository(name: String, isPrivate: Bool, token: String) async throws -> GitHubRepo {
        guard let url = URL(string: "https://api.github.com/user/repos") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": name,
            "private": isPrivate,
            "auto_init": true,
            "description": "Published from CAOCAP"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"

            if httpResponse.statusCode == 422, errorMsg.contains("name already exists") {
                return try await getRepository(name: name, token: token)
            }

            Self.logger.error("GitHub create repo failed (\(httpResponse.statusCode)): \(errorMsg)")
            throw NSError(
                domain: "GitHubService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "GitHub Repository Error: \(errorMsg)"]
            )
        }

        do {
            return try JSONDecoder().decode(GitHubRepo.self, from: data)
        } catch {
            throw GitHubError.decodedFailed(error)
        }
    }

    func createOrUpdateFile(
        owner: String,
        repo: String,
        path: String,
        content: String,
        message: String,
        token: String
    ) async throws {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let base64Content = content.data(using: .utf8)?.base64EncodedString() else {
            throw GitHubError.unknown
        }

        var body: [String: Any] = [
            "message": message,
            "content": base64Content
        ]

        if let sha = try? await getFileSHA(owner: owner, repo: repo, path: path, token: token) {
            body["sha"] = sha
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"
            Self.logger.error("GitHub file push failed (\(httpResponse.statusCode)): \(errorMsg)")
            throw NSError(
                domain: "GitHubService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "GitHub File Error: \(errorMsg)"]
            )
        }
    }

    func getAuthenticatedUser(token: String) async throws -> String {
        guard let url = URL(string: "https://api.github.com/user") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.invalidResponse
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let login = json["login"] as? String {
            return login
        }

        throw GitHubError.unknown
    }

    func getRepository(name: String, token: String) async throws -> GitHubRepo {
        let owner = try await getAuthenticatedUser(token: token)
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(name)") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(GitHubRepo.self, from: data)
        } catch {
            throw GitHubError.decodedFailed(error)
        }
    }

    private func getFileSHA(owner: String, repo: String, path: String, token: String) async throws -> String? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let sha = json["sha"] as? String {
            return sha
        }
        return nil
    }
}

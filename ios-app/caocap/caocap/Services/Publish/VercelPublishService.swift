import Foundation
import OSLog

enum VercelPublishError: LocalizedError {
    case invalidURL
    case secretsFileNotFound
    case missingVercelToken
    case invalidResponse(Int)
    case decodedFailed(Error)
    case deploymentFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Vercel API URL."
        case .secretsFileNotFound, .missingVercelToken:
            return "Publishing is not configured. Add VERCEL_API_TOKEN to Secrets.plist."
        case .invalidResponse(let code):
            return "Vercel returned an unexpected response (HTTP \(code))."
        case .decodedFailed:
            return "Could not read the Vercel deployment response."
        case .deploymentFailed(let message):
            return message
        }
    }
}

struct VercelDeploymentResponse: Codable {
    let url: String
    let id: String
    let name: String
}

/// Triggers a Vercel production deployment from a GitHub repository.
struct VercelPublishService {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "VercelPublish")

    func deployFromGitHub(repoId: Int, projectName: String) async throws -> String {
        guard let url = URL(string: "https://api.vercel.com/v13/deployments?skipAutoDetectionConfirmation=1") else {
            throw VercelPublishError.invalidURL
        }

        let token = try loadVercelToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": projectName.lowercased().replacingOccurrences(of: " ", with: "-"),
            "target": "production",
            "gitSource": [
                "type": "github",
                "repoId": repoId,
                "ref": "main"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VercelPublishError.invalidResponse(0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorMessage = "Unknown Vercel error"
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let vercelError = errorJson["error"] as? [String: Any],
               let message = vercelError["message"] as? String {
                errorMessage = message
            } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                errorMessage = text
            }

            Self.logger.error("Vercel deploy failed (\(httpResponse.statusCode)): \(errorMessage)")
            throw VercelPublishError.deploymentFailed("Vercel Error: \(errorMessage)")
        }

        do {
            let result = try JSONDecoder().decode(VercelDeploymentResponse.self, from: data)
            return "https://\(result.url)"
        } catch {
            throw VercelPublishError.decodedFailed(error)
        }
    }

    private func loadVercelToken() throws -> String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            throw VercelPublishError.secretsFileNotFound
        }

        guard let token = dict["VERCEL_API_TOKEN"] as? String,
              !token.isEmpty, token != "PASTE_YOUR_VERCEL_TOKEN_HERE" else {
            throw VercelPublishError.missingVercelToken
        }

        return token
    }
}

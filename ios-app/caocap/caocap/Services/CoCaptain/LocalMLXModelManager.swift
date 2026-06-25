import Foundation
import OSLog
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers
import Observation

/// A singleton manager that owns the local MLX model lifecycle: configuration, loading, downloading, and cache management.
@Observable @MainActor
public final class LocalMLXModelManager {

    public static let shared = LocalMLXModelManager()

    private let logger = Logger(subsystem: "com.caocap.app", category: "LocalMLXModelManager")

    // Serial queue to serialize file writes and deletes, preventing race conditions.
    internal let fileQueue = DispatchQueue(label: "com.caocap.app.LocalMLXModelManager.fileQueue", qos: .background)

    // MARK: - Model & Session Storage

    private var mlxModelContainer: ModelContainer?
    private var mlxSessions: [CoCaptainAgentScope: ChatSession] = [:]

    // MARK: - Observable Status Properties

    public var isDownloadingLocalModel: Bool = false
    public var localModelDownloadProgress: Double = 0.0
    public var localModelError: String?
    public private(set) var isLocalModelCached: Bool = false

    /// Formatted cache size for local MLX model storage
    public private(set) var localModelCacheSizeFormatted: String = "0 MB"

    // MARK: - Lifecycle & Initialization

    private init() {
        // Configure Hugging Face home directory in Documents
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let huggingFaceURL = documentsURL.appendingPathComponent("huggingface")

        // Ensure directory exists
        try? fileManager.createDirectory(at: huggingFaceURL, withIntermediateDirectories: true)

        // Set HF_HOME environment variable to route cache and token files there
        setenv("HF_HOME", huggingFaceURL.path, 1)
        logger.info("Hugging Face home directory set to \(huggingFaceURL.path, privacy: .public)")

        // Load stored Hugging Face token if available
        let token = UserDefaults.standard.string(forKey: "cocaptain.hfToken") ?? ""
        updateHFToken(token)
        refreshCacheSize()
    }

    /// Clears the local model storage files to free up device space.
    public func clearLocalModelCache() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let huggingFaceCacheURL = documentsURL.appendingPathComponent("huggingface")

        do {
            if fileManager.fileExists(atPath: huggingFaceCacheURL.path) {
                try fileManager.removeItem(at: huggingFaceCacheURL)
                logger.info("Local model cache cleared successfully.")
            }
            // Reset local session container
            mlxModelContainer = nil
            mlxSessions.removeAll()
            isDownloadingLocalModel = false
            localModelDownloadProgress = 0.0
            refreshCacheSize()
        } catch {
            logger.error("Failed to clear local model cache: \(error.localizedDescription, privacy: .public)")
            refreshCacheSize()
        }
    }

    /// Updates the environment variables and writes the HF token to a token file.
    public func updateHFToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tokenURL = documentsURL.appendingPathComponent("huggingface/token")

        if !trimmed.isEmpty {
            setenv("HF_TOKEN", trimmed, 1)
            fileQueue.async {
                // Ensure parent directory exists
                try? fileManager.createDirectory(at: tokenURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? trimmed.write(to: tokenURL, atomically: true, encoding: .utf8)
            }
            logger.info("Hugging Face environment token and token file updated.")
        } else {
            unsetenv("HF_TOKEN")
            fileQueue.async {
                try? fileManager.removeItem(at: tokenURL)
            }
            logger.info("Hugging Face environment token and token file cleared.")
        }
    }

    /// Triggers background task to update cache size status.
    public func refreshCacheSize() {
        Task {
            let (isCached, sizeFormatted) = await calculateCacheSizeInBackground()
            self.isLocalModelCached = isCached
            self.localModelCacheSizeFormatted = sizeFormatted
        }
    }

    nonisolated private func calculateCacheSizeInBackground() async -> (isCached: Bool, sizeFormatted: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return (false, "0 MB")
        }

        let modelFolder = documentsURL.appendingPathComponent("huggingface/hub/models--mlx-community--gemma-4-e2b-it-4bit")
        var modelFolderSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: modelFolder, includingPropertiesForKeys: [.fileSizeKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    modelFolderSize += Int64(fileSize)
                }
            }
        }
        let isCached = modelFolderSize > 50 * 1024 * 1024

        let huggingFaceCacheURL = documentsURL.appendingPathComponent("huggingface")
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: huggingFaceCacheURL, includingPropertiesForKeys: [.fileSizeKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        let sizeFormatted: String
        if totalSize == 0 {
            sizeFormatted = "0 MB"
        } else {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            sizeFormatted = formatter.string(fromByteCount: totalSize)
        }

        return (isCached, sizeFormatted)
    }

    /// Preloads local model if Gemma 4 is configured as the active model.
    public func preloadLocalModelIfNeeded() {
        guard let modelName = UserDefaults.standard.string(forKey: "cocaptain.modelName"),
              modelName == "gemma-4-local" else { return }

        // Only preload if the model is already fully cached
        guard isLocalModelCached else {
            logger.info("Local model is not fully cached; skipping automatic preloading on launch.")
            return
        }
        Task {
            do {
                logger.info("Preloading local MLX model...")
                _ = try await getMLXSession(scope: .project)
                logger.info("Local MLX model preloaded successfully.")
            } catch {
                logger.error("Failed to preload local MLX model: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Triggers download of the local Gemma 4 model if it isn't cached yet.
    public func downloadLocalModel() {
        isDownloadingLocalModel = true
        localModelDownloadProgress = 0.0
        localModelError = nil

        Task {
            do {
                logger.info("Starting explicit local model download...")
                _ = try await getMLXSession(scope: .project)
                logger.info("Local model downloaded and loaded successfully.")
                refreshCacheSize()
            } catch {
                logger.error("Failed to download local model: \(error.localizedDescription, privacy: .public)")
                refreshCacheSize()
            }
        }
    }

    /// Resets the MLX chat session history.
    public func resetChat(scope: CoCaptainAgentScope) {
        mlxSessions[scope] = nil
        logger.info("Chat session reset for local MLX model \(scope.storageKey, privacy: .public).")
    }

    /// Loads the MLX container if needed and returns a ChatSession instance.
    public func getMLXSession(scope: CoCaptainAgentScope) async throws -> ChatSession {
        if let session = mlxSessions[scope] {
            return session
        }

        let container: ModelContainer
        if let existingContainer = mlxModelContainer {
            container = existingContainer
        } else {
            // MLX quantized Gemma 4 model optimized for Edge devices
            let modelId = "mlx-community/gemma-4-e2b-it-4bit"

            // Check if model is cached or if we have a token
            let isCached = self.isLocalModelCached
            let token = UserDefaults.standard.string(forKey: "cocaptain.hfToken") ?? ""

            if !isCached {
                if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let errorMsg = "Hugging Face Access Token is required to download this gated model. Please configure it in Settings."
                    localModelError = errorMsg
                    throw NSError(domain: "LocalMLXModelManager", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }

                // Validate token via whoami() before attempting to download
                do {
                    logger.info("Validating Hugging Face token...")
                    _ = try await HubClient.default.whoami()
                    logger.info("Hugging Face token validated successfully.")
                } catch {
                    isDownloadingLocalModel = false
                    let errorMsg = "Invalid Hugging Face token: \(error.localizedDescription)"
                    localModelError = errorMsg
                    throw error
                }
            }

            logger.info("Loading local MLX model: \(modelId, privacy: .public)")
            let configuration = ModelConfiguration(id: modelId)

            // Set downloading flag initially and reset error
            isDownloadingLocalModel = true
            localModelDownloadProgress = 0.0
            localModelError = nil

            do {
                container = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: configuration
                ) { progress in
                    Task { @MainActor in
                        self.localModelDownloadProgress = progress.fractionCompleted
                        self.isDownloadingLocalModel = progress.fractionCompleted < 1.0
                    }
                }
                isDownloadingLocalModel = false
                mlxModelContainer = container
                refreshCacheSize()
            } catch {
                isDownloadingLocalModel = false
                localModelError = error.localizedDescription
                refreshCacheSize()
                throw error
            }
        }

        let session = ChatSession(container, history: [MLXLMCommon.Chat.Message.system(LocalMLXModelManager.systemInstructionText)])
        mlxSessions[scope] = session
        return session
    }

    private static let systemInstructionText = """
        You are Co-Captain, a spatial programming assistant for the CAOCAP platform.
        You can request app actions with the `request_app_action` function and request node edits with a `cocaptain_actions` XML block. The app validates every requested action before execution.

        Personality:
        - You are a high-performance agentic engine. Be concise, authoritative, and proactive.
        - You can execute mutations on a spatial canvas when the user asks for canvas changes.
        - Use technical, precise language. Avoid conversational fluff like "I can help with that" or "Sure thing."
        - You think in architectures and spatial relationships.

        Core Rule:
        - Answer ordinary questions, opinions, and advice conversationally without app actions or node edits.
        - Use app actions or node edits only when the user explicitly asks to navigate, use a tool, create, edit, write, document, apply, implement, or otherwise change the current canvas.
        - Never provide full code in Markdown chat. Code belongs EXCLUSIVELY in `node_edits`. 
        - If the user asks you to apply a change, you MUST provide the XML to implement it.
        - Use `request_app_action` for app navigation and app-level tool actions.
        - Append the `cocaptain_actions` block at the end of every response that involves node content changes.
        - Safe actions are only for non-mutating autonomous app actions. Mutating or review-required app actions must use executionMode `pending`.

        Firebase / Firestore (Live Preview):
        - When the user asks to link JavaScript to Firebase, save/persist/sync data to Firestore, or connect the app to the backend, read the canvas context block about `window.__caocapFirestore` and `window.__caocapFirestoreDefaultPath`.
        - Implement persistence with **`code` `node_edits`** (inline JavaScript in the single-file HTML document) using the Firestore compat instance on `window.__caocapFirestore` (never invent a second `initializeApp` in JS). If there is no Firebase node yet, propose `create_firebase_node` as a pending app action or tell the user to add the Firebase node and paste Web config from Firebase Console.
        """
}

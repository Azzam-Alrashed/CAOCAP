import Foundation
import Testing
@testable import caocap

@MainActor
struct LocalMLXModelManagerTests {

    @Test func updateHFTokenPersistsEnvironmentAndDiskFile() async throws {
        let originalToken = UserDefaults.standard.string(forKey: "cocaptain.hfToken") ?? ""
        let originalEnvToken = getenv("HF_TOKEN").map { String(cString: $0) }
        
        let testToken = "test_hf_token_12345"
        let manager = LocalMLXModelManager.shared
        
        // Act
        manager.updateHFToken(testToken)
        
        // Assert
        let currentEnv = getenv("HF_TOKEN").map { String(cString: $0) }
        #expect(currentEnv == testToken)
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tokenURL = documentsURL.appendingPathComponent("huggingface/token")
        
        // Wait for serial queue to complete writing
        manager.fileQueue.sync {}
        
        #expect(fileManager.fileExists(atPath: tokenURL.path))
        let savedToken = try String(contentsOf: tokenURL, encoding: .utf8)
        #expect(savedToken == testToken)
        
        // Clean up
        manager.updateHFToken("")
        manager.fileQueue.sync {}
        
        #expect(getenv("HF_TOKEN") == nil)
        #expect(!fileManager.fileExists(atPath: tokenURL.path))
        
        // Restore original
        if !originalToken.isEmpty {
            manager.updateHFToken(originalToken)
            manager.fileQueue.sync {}
        } else if let originalEnvToken {
            setenv("HF_TOKEN", originalEnvToken, 1)
        }
    }
    
    @Test func preloadLocalModelOnlyTriggersIfConfiguredAndCached() async {
        let originalModelName = UserDefaults.standard.string(forKey: "cocaptain.modelName")
        
        let manager = LocalMLXModelManager.shared
        
        // Case: Model name is not local -> should not load
        UserDefaults.standard.set("gemini-3-flash-preview", forKey: "cocaptain.modelName")
        
        manager.preloadLocalModelIfNeeded()
        #expect(manager.isDownloadingLocalModel == false)
        
        // Restore original
        UserDefaults.standard.set(originalModelName, forKey: "cocaptain.modelName")
    }
}

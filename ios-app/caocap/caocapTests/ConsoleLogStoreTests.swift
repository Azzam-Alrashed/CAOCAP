import XCTest
@testable import caocap

@MainActor
final class ConsoleLogStoreTests: XCTestCase {
    var store: ConsoleLogStore!
    
    override func setUp() async throws {
        store = ConsoleLogStore.shared
        store.clear()
    }
    
    func testAddLog() {
        store.addLog(type: "log", message: "Hello, console!")
        XCTAssertEqual(store.logs.count, 1)
        XCTAssertEqual(store.logs[0].type, "log")
        XCTAssertEqual(store.logs[0].message, "Hello, console!")
    }
    
    func testLogCapping() {
        for i in 0..<510 {
            store.addLog(type: "log", message: "Message \(i)")
        }
        
        XCTAssertEqual(store.logs.count, 500)
        XCTAssertEqual(store.logs.first?.message, "Message 10")
        XCTAssertEqual(store.logs.last?.message, "Message 509")
    }
    
    func testClearLogs() {
        store.addLog(type: "error", message: "Fatal crash simulation")
        XCTAssertEqual(store.logs.count, 1)
        
        store.clear()
        XCTAssertTrue(store.logs.isEmpty)
    }
    
    func testFilterByQuery() {
        store.addLog(type: "log", message: "Fetching user profile")
        store.addLog(type: "error", message: "Network connection lost")
        store.addLog(type: "warn", message: "Deprecated API usage")
        
        // Match profile query
        store.filterQuery = "profile"
        XCTAssertEqual(store.filteredLogs.count, 1)
        XCTAssertEqual(store.filteredLogs[0].message, "Fetching user profile")
        
        // Case-insensitivity match
        store.filterQuery = "API"
        XCTAssertEqual(store.filteredLogs.count, 1)
        XCTAssertEqual(store.filteredLogs[0].message, "Deprecated API usage")
    }
    
    func testFilterByType() {
        store.addLog(type: "log", message: "Normal log message")
        store.addLog(type: "error", message: "Network connection lost")
        store.addLog(type: "warn", message: "Deprecated API usage")
        
        // Filter by error type
        store.filterType = "error"
        XCTAssertEqual(store.filteredLogs.count, 1)
        XCTAssertEqual(store.filteredLogs[0].message, "Network connection lost")
        
        // Filter by warn type
        store.filterType = "warn"
        XCTAssertEqual(store.filteredLogs.count, 1)
        XCTAssertEqual(store.filteredLogs[0].message, "Deprecated API usage")
    }
    
    func testCombinedFilterAndReset() {
        store.addLog(type: "log", message: "Fetching user profile")
        store.addLog(type: "error", message: "Network connection profile failure")
        store.addLog(type: "warn", message: "Deprecated API usage")
        
        // Match query + type
        store.filterQuery = "profile"
        store.filterType = "error"
        XCTAssertEqual(store.filteredLogs.count, 1)
        XCTAssertEqual(store.filteredLogs[0].message, "Network connection profile failure")
        
        // Reset query and type
        store.filterQuery = ""
        store.filterType = nil
        XCTAssertEqual(store.filteredLogs.count, 3)
    }
}

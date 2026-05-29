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
}

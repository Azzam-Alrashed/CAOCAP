import XCTest
@testable import caocap

@MainActor
final class ReactiveGraphEngineTests: XCTestCase {
    var engine: ReactiveGraphEngine!
    
    override func setUp() async throws {
        engine = ReactiveGraphEngine()
    }
    
    func testNumericValueExtraction() {
        var node = SpatialNode(type: .text, position: .zero, title: "T1")
        
        node.textContent = "Price is 42.50 dollars"
        XCTAssertEqual(engine.numericValue(from: node), 42.50)
        
        node.textContent = nil
        node.aiResponse = "Total: -10"
        XCTAssertEqual(engine.numericValue(from: node), -10)
        
        node.aiResponse = nil
        node.subtitle = "100"
        XCTAssertEqual(engine.numericValue(from: node), 100)
        
        node.subtitle = "no numbers here"
        XCTAssertNil(engine.numericValue(from: node))
    }
    
    func testCalculationNodeAddition() {
        var input1 = SpatialNode(type: .text, position: .zero, title: "T1")
        input1.textContent = "10"
        
        var input2 = SpatialNode(type: .text, position: .zero, title: "T2")
        input2.textContent = "20"
        
        var calc = SpatialNode(type: .calculation, position: .zero, title: "Calc")
        calc.operation = .add
        calc.inputNodeIds = [input1.id, input2.id]
        
        var nodes = [input1, input2, calc]
        let changed = engine.recalculate(nodes: &nodes)
        
        XCTAssertTrue(changed)
        let updatedCalc = nodes.first { $0.id == calc.id }!
        XCTAssertEqual(updatedCalc.outputValue, 30)
    }
    
    func testMultiPassResolution() {
        var input = SpatialNode(type: .text, position: .zero, title: "T1")
        input.textContent = "5"
        
        var calc1 = SpatialNode(type: .calculation, position: .zero, title: "Calc1")
        calc1.operation = .add
        calc1.inputNodeIds = [input.id, input.id] // 5 + 5 = 10
        
        var calc2 = SpatialNode(type: .calculation, position: .zero, title: "Calc2")
        calc2.operation = .multiply
        calc2.inputNodeIds = [calc1.id, input.id] // 10 * 5 = 50
        
        var nodes = [input, calc1, calc2]
        
        // Reverse order means calc2 gets processed before calc1 on the first pass
        nodes.reverse()
        
        let changed = engine.recalculate(nodes: &nodes)
        
        XCTAssertTrue(changed)
        XCTAssertEqual(nodes.first(where: { $0.id == calc1.id })?.outputValue, 10)
        XCTAssertEqual(nodes.first(where: { $0.id == calc2.id })?.outputValue, 50)
    }
    
    func testDisplayNodeMirrorsInput() {
        var input = SpatialNode(type: .text, position: .zero, title: "T1")
        input.textContent = "123"
        
        var display = SpatialNode(type: .display, position: .zero, title: "D1")
        display.inputNodeIds = [input.id]
        
        var nodes = [input, display]
        
        let changed = engine.recalculate(nodes: &nodes)
        XCTAssertTrue(changed)
        XCTAssertEqual(nodes.first(where: { $0.id == display.id })?.outputValue, 123)
    }
}

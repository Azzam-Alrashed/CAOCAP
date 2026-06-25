import Foundation
import CoreGraphics

/// A service responsible for computing spatial layouts for canvas nodes.
///
/// Decoupled from `ProjectStore` to keep layout computations pure, testable,
/// and separate from active view state management.
public struct NodeLayoutOrganizer: Sendable {
    
    public init() {}
    
    /// Computes the visual layout for the given nodes.
    /// - Parameter nodes: The current list of nodes on the canvas.
    /// - Returns: A dictionary mapping node IDs to their calculated target positions.
    public func organize(nodes: [SpatialNode]) -> [UUID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        
        var nodePositions = [UUID: CGPoint]()
        
            // HIERARCHICAL DAG & GROUPED LAYOUT
            // 1. Group nodes by connectivity (Clusters) discovering all incoming/outgoing link types
            // Discovered in the order they appear in the nodes list to ensure deterministic output
            var clusters: [[UUID]] = []
            var unvisited = Set(nodes.map { $0.id })
            
            for node in nodes {
                let startId = node.id
                guard unvisited.contains(startId) else { continue }
                unvisited.remove(startId)
                
                var currentCluster: [UUID] = []
                var queue = [startId]
                
                while !queue.isEmpty {
                    let id = queue.removeFirst()
                    currentCluster.append(id)
                    
                    guard let clusterNode = nodes.first(where: { $0.id == id }) else { continue }
                    
                    // Outgoing connections
                    var outgoing: [UUID] = []
                    if let next = clusterNode.nextNodeId { outgoing.append(next) }
                    if let connected = clusterNode.connectedNodeIds { outgoing.append(contentsOf: connected) }
                    
                    // Incoming connections
                    let incoming = nodes.filter { target in
                        target.nextNodeId == id ||
                        (target.connectedNodeIds ?? []).contains(id)
                    }.map { $0.id }
                    
                    let relatedIds = outgoing + incoming
                    for relatedId in relatedIds {
                        if unvisited.contains(relatedId) {
                            unvisited.remove(relatedId)
                            queue.append(relatedId)
                        }
                    }
                }
                clusters.append(currentCluster)
            }
            
            // 2. Lay out each cluster hierarchically relative to (0,0)
            let horizontalSpacing: CGFloat = 400
            var localPositions = [UUID: CGPoint]()
            var clusterSizes = [Int: (width: CGFloat, height: CGFloat, localCenter: CGPoint)]()
            
            for (clusterIndex, clusterIds) in clusters.enumerated() {
                // Let's compute topological levels/ranks within this cluster
                var ranks = [UUID: Int]()
                for id in clusterIds {
                    ranks[id] = 0
                }
                
                let clusterNodeSet = Set(clusterIds)
                
                // Run Bellman-Ford style relaxation loop to find DAG depths
                for _ in 0..<clusterIds.count {
                    var changed = false
                    for id in clusterIds {
                        guard let node = nodes.first(where: { $0.id == id }) else { continue }
                        let currentRank = ranks[id] ?? 0
                        
                        let inputs = nodes.filter { A in
                            clusterNodeSet.contains(A.id) && (
                                A.nextNodeId == id ||
                                (A.connectedNodeIds ?? []).contains(id)
                            )
                        }
                        
                        for A in inputs {
                            let rankA = ranks[A.id] ?? 0
                            if rankA + 1 > currentRank {
                                ranks[id] = rankA + 1
                                changed = true
                            }
                        }
                    }
                    if !changed { break }
                }
                
                // Group cluster nodes by rank
                var nodesByRank = [Int: [UUID]]()
                for id in clusterIds {
                    let rank = ranks[id] ?? 0
                    nodesByRank[rank, default: []].append(id)
                }
                
                let sortedRanks = nodesByRank.keys.sorted()
                
                // Lay out relative to (0,0) center
                for (rankIdx, rank) in sortedRanks.enumerated() {
                    let rankNodes = nodesByRank[rank] ?? []
                    let x = CGFloat(rankIdx) * horizontalSpacing
                    
                    // Determine vertical spacing dynamically
                    let hasLargeNodes = rankNodes.contains { id in
                        if let node = nodes.first(where: { $0.id == id }) {
                            return node.type == .miniApp
                        }
                        return false
                    }
                    let verticalSpacing = hasLargeNodes ? CGFloat(300) : CGFloat(220)
                    
                    // Center vertically around y=0
                    let totalHeight = CGFloat(rankNodes.count - 1) * verticalSpacing
                    let startY = -totalHeight / 2
                    
                    for (i, id) in rankNodes.enumerated() {
                        let y = startY + CGFloat(i) * verticalSpacing
                        localPositions[id] = CGPoint(x: x, y: y)
                    }
                }
                
                // Compute local cluster bounds
                let clusterLocals = clusterIds.compactMap { localPositions[$0] }
                let localXValues = clusterLocals.map(\.x)
                let localYValues = clusterLocals.map(\.y)
                
                let minX = localXValues.min() ?? 0
                let maxX = localXValues.max() ?? 0
                let minY = localYValues.min() ?? 0
                let maxY = localYValues.max() ?? 0
                
                let width = (maxX - minX) + 320
                let height = (maxY - minY) + 240
                let localCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
                
                clusterSizes[clusterIndex] = (width, height, localCenter)
            }
            
            // 3. Stack clusters globally in 2 columns
            var columnHeights: [CGFloat] = [0.0, 0.0]
            let columnSpacing: CGFloat = 900
            let clusterGap: CGFloat = 100
            
            for (clusterIndex, clusterIds) in clusters.enumerated() {
                let col = clusterIndex % 2
                let cSize = clusterSizes[clusterIndex]!
                
                let clusterCenter = CGPoint(
                    x: CGFloat(col) * columnSpacing,
                    y: columnHeights[col] + cSize.height / 2
                )
                
                for id in clusterIds {
                    if let localPos = localPositions[id] {
                        let globalPos = CGPoint(
                            x: localPos.x - cSize.localCenter.x + clusterCenter.x,
                            y: localPos.y - cSize.localCenter.y + clusterCenter.y
                        )
                        nodePositions[id] = globalPos
                    }
                }
                
                columnHeights[col] += cSize.height + clusterGap
            }
        
        return nodePositions
    }
}

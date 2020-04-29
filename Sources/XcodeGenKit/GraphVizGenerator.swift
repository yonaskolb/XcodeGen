import DOT
import Foundation
import GraphViz
import ProjectSpec

public class GraphVizGenerator {
    
    public init() {}
    
    public func generateModuleGraphViz(targets: [Target]) -> String {
        return DOTEncoder().encode(generateGraph(targets: targets))
    }
    
    func generateGraph(targets: [Target]) -> Graph {
        var graph = Graph(directed: true)
        
        targets.forEach { target in
            target.dependencies.forEach { dependency in
                let from = Node(target.name)
                let to = Node(dependency.reference)
                let edge = Edge(from: from, to: to)
                graph.append(edge)
            }
        }
        return graph
    }
}

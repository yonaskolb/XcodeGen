import DOT
import Foundation
import GraphViz
import ProjectSpec

extension Dependency {
    var graphVizName: String {
        switch self.type {
        case .bundle, .package, .sdk, .framework, .carthage:
            return "<<external>>\\n\(reference)"
        case .target:
            return reference
        }
    }
}

extension Node {
    init(target: Target) {
        self.init(target.name)
        self.shape = .box
    }
    
    init(dependency: Dependency) {
        self.init(dependency.reference)
        self.shape = .box
        self.label = dependency.graphVizName
    }
}

public class GraphVizGenerator {
    
    public init() {}
    
    public func generateModuleGraphViz(targets: [Target]) -> String {
        return DOTEncoder().encode(generateGraph(targets: targets))
    }
    
    func generateGraph(targets: [Target]) -> Graph {
        var graph = Graph(directed: true)
        targets.forEach { target in
            target.dependencies.forEach { dependency in
                let from = Node(target: target)
                graph.append(from)
                let to = Node(dependency: dependency)
                graph.append(to)
                var edge = Edge(from: from, to: to)
                edge.style = .dashed
                graph.append(edge)
            }
        }
        return graph
    }
}

import ProjectSpec
import Spectre
@testable import XcodeGenKit
import XCTest

private let app = Target(
    name: "MyApp",
    type: .application,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
    dependencies: [Dependency(type: .target, reference: "MyFramework")]
)

private let framework = Target(
    name: "MyFramework",
    type: .framework,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
)

private let uiTest = Target(
    name: "MyAppUITests",
    type: .uiTestBundle,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_3": "VALUE"]),
    dependencies: [Dependency(type: .target, reference: "MyApp")]
)

private let targets = [app, framework, uiTest]

class GraphVizGeneratorTests: XCTestCase {

    func testGraphOutput() throws {
        describe {
            $0.it("generates the expected edges") {
                let graph = GraphVizGenerator().generateGraph(targets: targets)
                try expect(graph.edges.count) == 2
            }
            $0.it("generates the expected output") {
                let output = GraphVizGenerator().generateModuleGraphViz(targets: targets)
                try expect(output) == """
                digraph {
                  MyApp -> MyFramework
                  MyAppUITests -> MyApp
                }
                """
            }
        }
    }
}


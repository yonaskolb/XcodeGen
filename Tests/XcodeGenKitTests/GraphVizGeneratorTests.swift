import ProjectSpec
import Spectre
@testable import XcodeGenKit
import XCTest

private let app = Target(
    name: "MyApp",
    type: .application,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
    dependencies: [
        Dependency(type: .target, reference: "MyInternalFramework"),
        Dependency(type: .bundle, reference: "Resources"),
        Dependency(type: .carthage(findFrameworks: true, linkType: .static), reference: "MyStaticFramework"),
        Dependency(type: .carthage(findFrameworks: true, linkType: .dynamic), reference: "MyDynamicFramework"),
        Dependency(type: .framework, reference: "MyExternalFramework"),
        Dependency(type: .package(product: "MyPackage"), reference: "MyPackage"),
        Dependency(type: .sdk(root: "MySDK"), reference: "MySDK"),
    ]
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
            let graph = GraphVizGenerator().generateGraph(targets: targets)
            $0.it("generates the expected number of nodes") {
                try expect(graph.nodes.count) == 16
            }
            $0.it("generates box nodes") {
                try expect(graph.nodes.filter { $0.shape == .box }.count) == 16
            }
            $0.it("generates the expected carthage nodes") {
                try expect(graph.nodes.filter { $0.label?.contains("[carthage]") ?? false }.count) == 2
            }
            $0.it("generates the expected sdk nodes") {
                try expect(graph.nodes.filter { $0.label?.contains("[sdk]") ?? false }.count) == 1
            }
            $0.it("generates the expected Framework nodes") {
                try expect(graph.nodes.filter { $0.label?.contains("[framework]") ?? false }.count) == 1
            }
            $0.it("generates the expected package nodes") {
                try expect(graph.nodes.filter { $0.label?.contains("[package]") ?? false }.count) == 1
            }
            $0.it("generates the expected bundle nodes") {
                try expect(graph.nodes.filter { $0.label?.contains("[bundle]") ?? false }.count) == 1
            }
            $0.it("generates the expected edges") {
                try expect(graph.edges.count) == 8
            }
            $0.it("generates dashed edges") {
                try expect(graph.edges.filter { $0.style == .dashed }.count) == 8
            }
            $0.it("generates the expected output") {
                let output = GraphVizGenerator().generateModuleGraphViz(targets: targets)
                try expect(output) == """
                digraph {
                  MyApp [shape=box]
                  MyInternalFramework [label=MyInternalFramework shape=box]
                  MyApp [shape=box]
                  Resources [label="[bundle]\\nResources" shape=box]
                  MyApp [shape=box]
                  MyStaticFramework [label="[carthage]\\nMyStaticFramework" shape=box]
                  MyApp [shape=box]
                  MyDynamicFramework [label="[carthage]\\nMyDynamicFramework" shape=box]
                  MyApp [shape=box]
                  MyExternalFramework [label="[framework]\\nMyExternalFramework" shape=box]
                  MyApp [shape=box]
                  MyPackage [label="[package]\\nMyPackage" shape=box]
                  MyApp [shape=box]
                  MySDK [label="[sdk]\\nMySDK" shape=box]
                  MyAppUITests [shape=box]
                  MyApp [label=MyApp shape=box]
                  MyApp -> MyInternalFramework [style=dashed]
                  MyApp -> Resources [style=dashed]
                  MyApp -> MyStaticFramework [style=dashed]
                  MyApp -> MyDynamicFramework [style=dashed]
                  MyApp -> MyExternalFramework [style=dashed]
                  MyApp -> MyPackage [style=dashed]
                  MyApp -> MySDK [style=dashed]
                  MyAppUITests -> MyApp [style=dashed]
                }
                """
            }
        }
    }
}

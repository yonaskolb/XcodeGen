import ProjectSpec
import Spectre
import XCTest
import PathKit
@testable import XcodeGenKit

class CarthageDependencyResolverTests: XCTestCase {

    override func setUp() {

    }

    func testBaseBuildPath() {
        describe {
            $0.it("provides the default base build path") {
                let resolver = CarthageDependencyResolver(project: makeTestProject())

                try expect(resolver.buildPath) == "Carthage/Build"
            }

            $0.it("provides the base build path specified by the project specs") {
                let customPath = "MyCustomBuildPath/Test"
                let options = SpecOptions(carthageBuildPath: customPath)
                let resolver = CarthageDependencyResolver(project: makeTestProject(options: options))

                try expect(resolver.buildPath) == customPath
            }
        }
    }

    func testExecutablePath() {
        describe {
            $0.it("provides the default executable path for carthage") {
                let resolver = CarthageDependencyResolver(project: makeTestProject())

                try expect(resolver.executable) == "carthage"
            }

            $0.it("provides the executable path for carthage as specified by the project specs") {
                let customPath = "MyCustomBuildPath/Test/carthage"
                let options = SpecOptions(carthageExecutablePath: customPath)
                let resolver = CarthageDependencyResolver(project: makeTestProject(options: options))

                try expect(resolver.executable) == customPath
            }
        }
    }
    func testBuildPathForPlatform() {
        describe {
            $0.it("generates the build path for a given platform") {
                let resolver = CarthageDependencyResolver(project: makeTestProject())
                let allPlatforms = Platform.allCases
                let expectedByPlatform: [Platform: String] = allPlatforms.reduce(into: [:]) { result, next in
                    result[next] = "\(resolver.buildPath)/\(next.carthageName)"
                }

                try allPlatforms.forEach { platform in
                    try expect(expectedByPlatform[platform]) == resolver.buildPath(for: platform)
                }
            }
        }
    }

    func testRelatedDependenciesForPlatform() {

        let dependencyFixtureName = "CarthageTestFixture"
        let carthageBuildPath = fixturePath + "TestProject/Carthage/Build"

        describe {
            $0.it("fetches related dependencies for a given platform, sorted alphabetically") {

                let options = SpecOptions(carthageBuildPath: carthageBuildPath.string)
                let resolver = CarthageDependencyResolver(project: makeTestProject(options: options))
                let dependency = Dependency(type: .carthage(includeRelated: true), reference: dependencyFixtureName)
                let expectedDependencies: [Platform: [String]] = [
                    .macOS: ["DependencyFixtureB", "DependencyFixtureA", "CarthageTestFixture"],
                    .watchOS: ["DependencyFixtureA", "DependencyFixtureB", "CarthageTestFixture"],
                    .tvOS: ["CarthageTestFixture", "DependencyFixtureA", "DependencyFixtureB"],
                    .iOS: ["CarthageTestFixture", "DependencyFixtureA", "DependencyFixtureB"]
                ]

                try Platform.allCases.forEach { platform in
                    let expected = expectedDependencies[platform] ?? []
                    let related = resolver.relatedDependencies(for: dependency, in: platform)
                    try expect(related.map { $0.reference }) == expected.sorted(by: { $0 < $1 })
                }
            }

            $0.it("returns the main dependency when no related dependencies are found") {
                let resolver = CarthageDependencyResolver(project: makeTestProject())
                let dependency = Dependency(type: .carthage(includeRelated: true), reference: dependencyFixtureName)

                let related = resolver.relatedDependencies(for: dependency, in: .iOS)

                try expect(related.map { $0.reference }) == [dependencyFixtureName]
            }
        }
    }

    func testDependenciesForTopLevelTarget() {

        let dependencyFixtureName = "CarthageTestFixture"
        let carthageBuildPath = fixturePath + "TestProject/Carthage/Build"

        describe {

            $0.it("overrides the includeRelated dependency global flag when specified") {
                let options = SpecOptions(carthageBuildPath: carthageBuildPath.string, includeCarthageRelatedDependencies: true)
                let dependency = Dependency(type: .carthage(includeRelated: false), reference: dependencyFixtureName)

                let resolver = CarthageDependencyResolver(project: makeTestProject(options: options))
                let target = Target(name: "1", type: .application, platform: .iOS, dependencies: [dependency])
                let dependencies = resolver.dependencies(for: target)
                
                try expect(dependencies) == [dependency]
            }

            $0.it("fetches all carthage dependencies for a given target, sorted alphabetically") {
                let unsortedDependencyReferences = ["RxSwift", "RxCocoa", "RxBlocking", "RxTest", "RxAtomic"]
                let dependencies = unsortedDependencyReferences.map {
                    Dependency(type: .carthage(includeRelated: false), reference: $0)
                }
                let nonCarthageDependencies = unsortedDependencyReferences.map { Dependency(type: .target, reference: $0) }
                let target = Target(name: "1", type: .application, platform: .iOS, dependencies: dependencies + nonCarthageDependencies)
                let resolver = CarthageDependencyResolver(project: makeTestProject(with: [target]))

                let related = resolver.dependencies(for: target)

                try expect(related) == dependencies.sorted(by: { $0.reference < $1.reference })
            }
        }
    }
    
}

private func makeTestProject(with targets: [Target] = [], options: SpecOptions = SpecOptions()) -> Project {
    return Project(name: "Test Project", targets: targets, options: options)

}

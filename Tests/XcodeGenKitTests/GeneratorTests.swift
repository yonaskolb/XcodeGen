import Spectre
import XcodeGenKit
import xcodeproj
import PathKit

func generatorTests() {

    func getProject(_ spec: Spec) throws -> XcodeProj {
        let lintedSpec = SpecLinter.lint(spec)
        let generator = ProjectGenerator(spec: lintedSpec.spec, path: Path(""))
        return try generator.generateProject()
    }

    func getPbxProj(_ spec: Spec) throws -> PBXProj {
        return try getProject(spec).pbxproj
    }

    describe("Project Generator") {

        $0.it("provide defaults") {
            let spec = Spec(name: "test")
            let project = try getProject(spec)
            try expect(project.pbxproj.objects.buildConfigurations.count) == 2
        }

        $0.describe("Targets") {

            let application = Target(name: "MyApp", type: .application, platform: .iOS,
                                     buildSettings: TargetBuildSettings(buildSettings: BuildSettings(dictionary: ["SETTING_1": "VALUE"])),
                                     dependencies: [.target("MyFramework")])

            let framework = Target(name: "MyFramework", type: .framework, platform: .iOS,
                                   buildSettings: TargetBuildSettings(buildSettings: BuildSettings(dictionary: ["SETTING_2": "VALUE"])))

            let spec = Spec(name: "test", targets: [application, framework])

            $0.it("generates targets") {
                let pbxProject = try getPbxProj(spec)
                let nativeTargets = pbxProject.objects.nativeTargets
                try expect(nativeTargets.count) == 2
                try expect(nativeTargets.contains{ $0.name == application.name }).beTrue()
                try expect(nativeTargets.contains{ $0.name == framework.name}).beTrue()
            }

            $0.it("generates dependencies") {
                let pbxProject = try getPbxProj(spec)
                let nativeTargets = pbxProject.objects.nativeTargets
                let dependencies = pbxProject.objects.targetDependencies
                try expect(dependencies.count) == 1
                try expect(dependencies.first!.target) == nativeTargets.first { $0.name == framework.name }!.reference
            }
        }
    }
}


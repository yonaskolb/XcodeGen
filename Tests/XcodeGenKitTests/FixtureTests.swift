import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcproj

let fixturePath = Path(#file).parent().parent() + "Fixtures"

func generate(specPath: Path, projectPath: Path) throws -> XcodeProj {
    let spec = try ProjectSpec.Project(path: specPath)
    let generator = ProjectGenerator(project: spec)
    let project = try generator.generateProject()
    let oldProject = try XcodeProj(path: projectPath)
    let pbxProjPath = projectPath + XcodeProj.pbxprojPath(projectPath)
    let oldProjectString: String = try pbxProjPath.read()
    try project.write(path: projectPath, override: true)
    let newProjectString: String = try pbxProjPath.read()

    let newProject = try XcodeProj(path: projectPath)
    let stringDiff = newProjectString != oldProjectString
    if newProject != oldProject || stringDiff {
        var message = "\(projectPath.string) has changed. If change is legitimate commit the change and run test again"
        if stringDiff {
            message += ":\n\n\(pbxProjPath):\n\(prettyFirstDifferenceBetweenStrings(oldProjectString, newProjectString))"
        }
        throw failure(message)
    }

    return newProject
}

func fixtureTests() {

    describe("Test Project") {
        var project: XcodeProj?

        $0.it("generates") {
            project = try generate(specPath: fixturePath + "TestProject/spec.yml", projectPath: fixturePath + "TestProject/Project.xcodeproj")
        }

        $0.it("generates variant group") {
            guard let project = project else { return }

            func getFileReferences(_ path: String) -> [ObjectReference<PBXFileReference>] {
                return project.pbxproj.objects.fileReferences.objectReferences.filter { $0.object.path == path }
            }

            func getVariableGroups(_ name: String?) -> [PBXVariantGroup] {
                return project.pbxproj.objects.variantGroups.referenceValues.filter { $0.name == name }
            }

            let resourceName = "LocalizedStoryboard.storyboard"
            let baseResource = "Base.lproj/LocalizedStoryboard.storyboard"
            let localizedResource = "en.lproj/LocalizedStoryboard.strings"

            guard let variableGroup = getVariableGroups(resourceName).first else { throw failure("Couldn't find the variable group") }

            do {
                let refs = getFileReferences(baseResource)
                try expect(refs.count) == 1
                try expect(variableGroup.children.filter { $0 == refs.first?.reference }.count) == 1
            }

            do {
                let refs = getFileReferences(localizedResource)
                try expect(refs.count) == 1
                try expect(variableGroup.children.filter { $0 == refs.first?.reference }.count) == 1
            }
        }

        $0.it("generates scheme execution actions") {
            guard let project = project else { return }

            let frameworkScheme = project.sharedData?.schemes.first { $0.name == "Framework" }
            try expect(frameworkScheme?.buildAction?.preActions.first?.scriptText) == "echo Starting Framework Build"
            try expect(frameworkScheme?.buildAction?.preActions.first?.title) == "Run Script"
            try expect(frameworkScheme?.buildAction?.preActions.first?.environmentBuildable?.blueprintName) == "Framework_iOS"
            try expect(frameworkScheme?.buildAction?.preActions.first?.environmentBuildable?.buildableName) == "Framework.framework"
        }
    }
}

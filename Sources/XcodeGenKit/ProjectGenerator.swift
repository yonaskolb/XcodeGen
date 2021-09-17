import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import XcodeGenCore
import XcodeProj
import Yams

public class ProjectGenerator {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    public func generateXcodeProject(in projectDirectory: Path? = nil) throws -> XcodeProj {

        // generate PBXProj
        let pbxProjGenerator = PBXProjGenerator(project: project,
                                                projectDirectory: projectDirectory)
        Logger.shared.debug("Generating project...")
        let pbxProj = try pbxProjGenerator.generate()
        Logger.shared.debug("Project generated")

        // generate Schemes
        let schemeGenerator = SchemeGenerator(project: project, pbxProj: pbxProj)
        Logger.shared.debug("Generating schemes...")
        let schemes = try schemeGenerator.generateSchemes()
        Logger.shared.debug("Schemes generated")

        // generate Workspace
        Logger.shared.debug("Generating workspace...")
        let workspace = try generateWorkspace()
        Logger.shared.debug("Workspace generated")

        let sharedData = XCSharedData(schemes: schemes)
        return XcodeProj(workspace: workspace, pbxproj: pbxProj, sharedData: sharedData)
    }

    func generateWorkspace() throws -> XCWorkspace {
        let selfReference = XCWorkspaceDataFileRef(location: .`self`(""))
        let dataElement = XCWorkspaceDataElement.file(selfReference)
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }
}

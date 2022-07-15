import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
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
        let pbxProj = try pbxProjGenerator.generate()

        // generate Schemes
        let schemeGenerator = SchemeGenerator(project: project, pbxProj: pbxProj)
        let schemes = try schemeGenerator.generateSchemes()

        // generate Workspace
        let workspace = try generateWorkspace()

        let sharedData = XCSharedData(schemes: schemes)
        return XcodeProj(workspace: workspace, pbxproj: pbxProj, sharedData: sharedData)
    }

    func generateWorkspace() throws -> XCWorkspace {
        let selfReference = XCWorkspaceDataFileRef(location: .current(""))
        let dataElement = XCWorkspaceDataElement.file(selfReference)
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }
}

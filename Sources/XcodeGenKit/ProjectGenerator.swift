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

    public func generateXcodeProject(in projectDirectory: Path? = nil, userName: String) throws -> XcodeProj {

        // generate PBXProj
        let pbxProjGenerator = PBXProjGenerator(project: project,
                                                projectDirectory: projectDirectory)
        let pbxProj = try pbxProjGenerator.generate()

        // generate Workspace
        let workspace = try generateWorkspace()

        // generate Schemes
        let schemeGenerator = SchemeGenerator(project: project, pbxProj: pbxProj)
        let (sharedSchemes, userSchemes, schemeManagement) = try schemeGenerator.generateSchemes()

        // generate shared data
        let sharedData = XCSharedData(schemes: sharedSchemes)

        // generate user data
        let userData = userSchemes.isEmpty && schemeManagement == nil ? [] : [
            XCUserData(userName: userName, schemes: userSchemes, schemeManagement: schemeManagement)
        ]

        return XcodeProj(
            workspace: workspace,
            pbxproj: pbxProj,
            sharedData: sharedData,
            userData: userData
        )
    }

    func generateWorkspace() throws -> XCWorkspace {
        let selfReference = XCWorkspaceDataFileRef(location: .current(""))
        let dataElement = XCWorkspaceDataElement.file(selfReference)
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }
}

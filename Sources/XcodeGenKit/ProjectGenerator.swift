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
    
    public func generateSchemeManagement() -> XCSchemeManagement {
        let userStateSchemes = project.targets.map { target -> XCSchemeManagement.UserStateScheme in
            XCSchemeManagement.UserStateScheme(
                name: target.name + ".xcscheme",
                shared: true,
                orderHint: nil,
                isShown: target.scheme?.isShown ?? TargetScheme.isShownDefault
            )
        }
        
        let schemeManagement = XCSchemeManagement(
            schemeUserState: userStateSchemes,
            suppressBuildableAutocreation: nil
        )
        
        return schemeManagement
    }
    

    func generateWorkspace() throws -> XCWorkspace {
        let selfReference = XCWorkspaceDataFileRef(location: .`self`(""))
        let dataElement = XCWorkspaceDataElement.file(selfReference)
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }
}

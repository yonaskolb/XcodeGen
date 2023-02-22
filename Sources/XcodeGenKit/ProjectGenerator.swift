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

    public func generateXcodeProject(in projectDirectory: Path? = nil, completion: @escaping ((XcodeProj) -> Void)) throws {

        // generate PBXProj
        let pbxProjGenerator = PBXProjGenerator(project: project,
                                                projectDirectory: projectDirectory)
        let pbxProjGroup = DispatchGroup()
        var pbxProj: PBXProj!
        pbxProjGroup.enter()
        var pbxProjError: Error?
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                pbxProjGroup.enter()
                try pbxProjGenerator.generate { (generatedPbxProj) in
                    pbxProj = generatedPbxProj
                    pbxProjGroup.leave()
                }
            } catch {
                pbxProjError = error
                pbxProjGroup.leave()
            }
            pbxProjGroup.leave()
        }

        pbxProjGroup.wait()

        guard pbxProjError == nil else {
            throw pbxProjError!
        }
        // generate Schemes
        let schemeGenerator = SchemeGenerator(project: project, pbxProj: pbxProj)
        let schemes = try schemeGenerator.generateSchemes()

        // generate Workspace
        let workspace = try generateWorkspace()

        let sharedData = XCSharedData(schemes: schemes)
        completion(XcodeProj(workspace: workspace, pbxproj: pbxProj, sharedData: sharedData))
    }

    func generateWorkspace() throws -> XCWorkspace {
        let selfReference = XCWorkspaceDataFileRef(location: .current(""))
        let dataElement = XCWorkspaceDataElement.file(selfReference)
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }
}

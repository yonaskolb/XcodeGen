import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import xcodeproj
import Yams

public class ProjectGenerator {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    public func generateXcodeProject(validate: Bool = true) throws -> XcodeProj {
        if validate {
            try project.validate()
        }

        // generate PBXProj
        let pbxProjGenerator = PBXProjGenerator(project: project)
        let pbxProj = try pbxProjGenerator.generate()

        // generate Schemes
        let schemeGenerator = SchemeGenerator(project: project, pbxProj: pbxProj)
        let schemes = try schemeGenerator.generateSchemes()

        // generate Workspace
        let workspace = try generateWorkspace()

        let sharedData = XCSharedData(schemes: schemes)
        return XcodeProj(workspace: workspace, pbxproj: pbxProj, sharedData: sharedData)
    }

    public func generateFiles() throws {

        /*
         Default info plist attributes taken from:
         /Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/Base/Base_DefinitionsInfoPlist.xctemplate/TemplateInfo.plist
        */
        var defaultInfoPlist: [String: Any] = [:]
        defaultInfoPlist["CFBundleIdentifier"] = "$(PRODUCT_BUNDLE_IDENTIFIER)"
        defaultInfoPlist["CFBundleInfoDictionaryVersion"] = "6.0"
        defaultInfoPlist["CFBundleExecutable"] = "$(EXECUTABLE_NAME)"
        defaultInfoPlist["CFBundleName"] = "$(PRODUCT_NAME)"
        defaultInfoPlist["CFBundleDevelopmentRegion"] = "$(DEVELOPMENT_LANGUAGE)"
        defaultInfoPlist["CFBundleShortVersionString"] = "1.0"
        defaultInfoPlist["CFBundleVersion"] = "1"

        for target in project.targets {
            if let plist = target.info {
                var targetInfoPlist = defaultInfoPlist
                switch target.type {
                case .uiTestBundle,
                     .unitTestBundle:
                    targetInfoPlist["CFBundlePackageType"] = "BNDL"
                case .application,
                     .watch2App:
                    targetInfoPlist["CFBundlePackageType"] = "APPL"
                case .framework:
                    targetInfoPlist["CFBundlePackageType"] = "FMWK"
                case .bundle:
                    targetInfoPlist["CFBundlePackageType"] = "BNDL"
                case .xpcService:
                    targetInfoPlist["CFBundlePackageType"] = "XPC"
                default: break
                }
                let path = project.basePath + plist.path
                let attributes = targetInfoPlist.merged(plist.attributes)
                let data = try PropertyListSerialization.data(fromPropertyList: attributes, format: .xml, options: 0)
                try? path.delete()
                try path.parent().mkpath()
                try path.write(data)
            }

            if let plist = target.entitlements {
                let path = project.basePath + plist.path
                let data = try PropertyListSerialization.data(fromPropertyList: plist.attributes, format: .xml, options: 0)
                try? path.delete()
                try path.parent().mkpath()
                try path.write(data)
            }
        }
    }

    func generateWorkspace() throws -> XCWorkspace {
        let dataElement: XCWorkspaceDataElement = .file(XCWorkspaceDataFileRef(location: .self("")))
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }
}

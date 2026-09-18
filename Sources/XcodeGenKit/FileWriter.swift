import Foundation
import PathKit
import ProjectSpec
import XcodeProj

public class FileWriter {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    public func writeXcodeProject(_ xcodeProject: XcodeProj, to projectPath: Path? = nil) throws {
        let projectPath = projectPath ?? project.defaultProjectPath
        let tempPath = try Path.processUniqueTemporary() + "XcodeGen"
        try? tempPath.delete()
        if projectPath.exists {
            try projectPath.copy(tempPath)
        }
        let isJSON = project.projectFormat.isJSON
        if isJSON {
            // Discarded: encoding the property list is what settles XcodeProj's object identifiers,
            // without which `project.xcproj` gets fresh UUIDs per run. Drop with XcodeProj#1180.
            _ = try xcodeProject.pbxproj.dataRepresentation(outputSettings: PBXOutputSettings())
        }
        try xcodeProject.write(path: tempPath, override: true, format: isJSON ? .xcproj : .pbxproj)
        // The copy above may carry the previous format's file, which would win the next read.
        try? (isJSON ? XcodeProj.pbxprojPath(tempPath) : XcodeProj.xcprojPath(tempPath)).delete()
        try? projectPath.delete()
        try tempPath.copy(projectPath)
        try? tempPath.delete()
    }

    public func writePlists() throws {

        let infoPlistGenerator = InfoPlistGenerator()
        for target in project.targets {
            // write Info.plist
            if let plist = target.info {
                let properties = infoPlistGenerator.generateProperties(for: target).merged(plist.properties)
                try writePlist(properties, path: plist.path)
            }

            // write entitlements
            if let plist = target.entitlements {
                try writePlist(plist.properties, path: plist.path)
            }
        }
    }

    private func writePlist(_ plist: [String: Any], path: String) throws {
        let path = project.basePath + path
        if path.exists, let data: Data = try? path.read(),
            let existingPlist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any], NSDictionary(dictionary: plist).isEqual(to: existingPlist) {
            // file is the same
            return
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try? path.delete()
        try path.parent().mkpath()
        try path.write(data)
    }
}

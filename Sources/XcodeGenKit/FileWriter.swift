import Foundation
import PathKit
import ProjectSpec
import xcodeproj

public class FileWriter {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    public func writeXcodeProject(_ xcodeProject: XcodeProj, to projectPath: Path? = nil) throws {
        let projectPath = project.defaultProjectPath
        let tempPath = Path.temporary + "XcodeGen_\(Int(NSTimeIntervalSince1970))"
        try? tempPath.delete()
        if projectPath.exists {
            try projectPath.copy(tempPath)
        }
        try xcodeProject.write(path: tempPath, override: true)
        try? projectPath.delete()
        try tempPath.copy(projectPath)
        try? tempPath.delete()
    }

    public func writePlists() throws {

        let infoPlistGenerator = InfoPlistGenerator()
        for target in project.targets {
            // write Info.plist
            if let plist = target.info {
                let properties = infoPlistGenerator.generateProperties(target: target).merged(plist.properties)
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

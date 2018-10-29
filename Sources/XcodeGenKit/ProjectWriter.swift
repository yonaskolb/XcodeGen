import Foundation
import ProjectSpec
import xcodeproj
import PathKit

public class ProjectWriter {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    public func writeXcodeProject(_ xcodeProject: XcodeProj) throws {
        let projectPath = project.projectPath
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
                let path = project.basePath + plist.path
                let attributes = infoPlistGenerator.generateAttributes(target: target).merged(plist.attributes)
                let data = try PropertyListSerialization.data(fromPropertyList: attributes, format: .xml, options: 0)
                try? path.delete()
                try path.parent().mkpath()
                try path.write(data)
            }

            // write entitlements
            if let plist = target.entitlements {
                let path = project.basePath + plist.path
                let data = try PropertyListSerialization.data(fromPropertyList: plist.attributes, format: .xml, options: 0)
                try? path.delete()
                try path.parent().mkpath()
                try path.write(data)
            }
        }
    }
}

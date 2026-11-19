import PathKit
import ProjectSpec
import XcodeProj

/// `ProjectFormat` is defined in `ProjectSpec` so that spec validation can check `options.projectFormat`.
/// This alias keeps `XcodeGenKit.ProjectFormat` available to existing clients.
public typealias ProjectFormat = ProjectSpec.ProjectFormat

extension ProjectFileFormat {

    /// The path of the file the project is stored in, inside the given `.xcodeproj`
    public func projectFilePath(in xcodeprojPath: Path) -> Path {
        switch self {
        case .pbxproj: XcodeProj.pbxprojPath(xcodeprojPath)
        case .xcproj: XcodeProj.xcprojPath(xcodeprojPath)
        }
    }
}

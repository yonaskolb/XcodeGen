public extension ProjectFileFormat {
    static let `default`: ProjectFileFormat = .pbxproj
}

/// The file format the project is stored in, inside the `.xcodeproj` bundle
public enum ProjectFileFormat: String, CaseIterable {
    /// The property list format, stored in `project.pbxproj`
    case pbxproj
    /// The JSON based format introduced in Xcode 27.2, stored in `project.xcproj`. Support for this format is experimental
    case xcproj

    /// The oldest `ProjectFormat` that can be stored in this file format
    public var minimumProjectFormat: ProjectFormat? {
        switch self {
        case .pbxproj: nil
        case .xcproj: .xcode27_0
        }
    }
}

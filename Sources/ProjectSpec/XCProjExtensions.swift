import Foundation
import PathKit
import XcodeProj

extension PBXProductType {

    init?(string: String) {
        if let type = PBXProductType(rawValue: string) {
            self = type
        } else if let type = PBXProductType(rawValue: "com.apple.product-type.\(string)") {
            self = type
        } else {
            return nil
        }
    }

    public var isFramework: Bool {
        self == .framework || self == .staticFramework
    }

    public var isLibrary: Bool {
        self == .staticLibrary || self == .dynamicLibrary
    }

    public var isExtension: Bool {
        fileExtension == "appex"
    }

    public var isSystemExtension: Bool {
        fileExtension == "dext" || fileExtension == "systemextension"
    }

    public var isApp: Bool {
        fileExtension == "app"
    }

    public var isTest: Bool {
        fileExtension == "xctest"
    }

    public var isExecutable: Bool {
        isApp || isExtension || isSystemExtension || isTest || self == .commandLineTool
    }

    public var name: String {
        rawValue.replacingOccurrences(of: "com.apple.product-type.", with: "")
    }

    public var canSkipCompileSourcesBuildPhase: Bool {
        switch self {
        case .bundle, .watch2App, .stickerPack, .messagesApplication:
            // Bundles, watch apps, sticker packs and simple messages applications without sources should not include a
            // compile sources build phase. Doing so can cause Xcode to produce an error on build.
            return true
        default:
            return false
        }
    }

    /// Function to determine when a dependendency should be embedded into the target
    ///
    /// - Parameter supportsStaticFrameworkEmbedding: Whether the target Xcode version (15+) strips
    ///   the static binary when embedding a static framework bundle. When `false`, static frameworks
    ///   are only linked, never embedded by default, to avoid duplicating statically-linked code
    ///   into the product on Xcode 14 and earlier.
    public func shouldEmbed(_ dependencyTarget: Target, supportsStaticFrameworkEmbedding: Bool) -> Bool {
        // Static libraries are never embedded. Static frameworks are only embedded on Xcode 15+,
        // where the build system strips the static binary from the copied bundle.
        guard dependencyTarget.defaultLinkage != .static
            || (dependencyTarget.type.isFramework && supportsStaticFrameworkEmbedding) else {
            return false
        }

        if isApp {
            // If target is an app, all linkable dependencies should be embedded
            return true
        } else if isTest, [.framework, .staticFramework, .bundle].contains(dependencyTarget.type) {
            // If target is test, some dependencies should be embed (depending on their type)
            return true
        } else {
            // If none of the above, do not embed the dependency
            return false
        }
    }
}

extension Platform {

    public var emoji: String {
        switch self {
        case .auto: return "🤖"
        case .iOS: return "📱"
        case .watchOS: return "⌚️"
        case .tvOS: return "📺"
        case .macOS: return "🖥"
        case .visionOS: return "🕶️"
        }
    }
}

extension ProjectTarget {
    public var shouldExecuteOnLaunch: Bool {
        // This is different from `type.isExecutable`, because we don't want to "run" a test
        type.isApp || type.isExtension || type.isSystemExtension || type == .commandLineTool
    }
}

extension XCScheme.CommandLineArguments {
    // Dictionary is a mapping from argument name and if it is enabled by default
    public convenience init(_ dict: [String: Bool]) {
        let args = dict.map { tuple in
            XCScheme.CommandLineArguments.CommandLineArgument(name: tuple.key, enabled: tuple.value)
        }.sorted { $0.name < $1.name }
        self.init(arguments: args)
    }
}

extension BreakpointExtensionID {

    init(string: String) throws {
        if let id = BreakpointExtensionID(rawValue: "Xcode.Breakpoint.\(string)Breakpoint") {
            self = id
        } else if let id = BreakpointExtensionID(rawValue: string) {
            self = id
        } else {
            throw SpecParsingError.unknownBreakpointType(string)
        }
    }
}

extension BreakpointActionExtensionID {

    init(string: String) throws {
        if let type = BreakpointActionExtensionID(rawValue: "Xcode.BreakpointAction.\(string)") {
            self = type
        } else if let type = BreakpointActionExtensionID(rawValue: string) {
            self = type
        } else {
            throw SpecParsingError.unknownBreakpointActionType(string)
        }
    }
}

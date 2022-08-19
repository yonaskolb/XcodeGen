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
    public func shouldEmbed(_ dependencyTarget: Target) -> Bool {
        switch dependencyTarget.defaultLinkage {
        case .static:
            // Static dependencies should never embed
            return false
        case .dynamic, .none:
            if isApp {
                // If target is an app, all dependencies should be embed (unless they're static)
                return true
            } else if isTest, [.framework, .bundle].contains(dependencyTarget.type) {
                // If target is test, some dependencies should be embed (depending on their type)
                return true
            } else {
                // If none of the above, do not embed the dependency
                return false
            }
        }
    }
}

extension Platform {

    public var emoji: String {
        switch self {
        case .iOS: return "📱"
        case .watchOS: return "⌚️"
        case .tvOS: return "📺"
        case .macOS: return "🖥"
        }
    }
}

extension Target {
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

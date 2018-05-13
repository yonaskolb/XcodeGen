import Foundation
import JSONUtilities

public struct BuildRule {

    public static let scriptCompilerSpec = "com.apple.compilers.proxy.script"
    public static let filePatternFileType = "pattern.proxy"

    public enum FileType: Equatable {
        case type(String)
        case pattern(String)

        public var fileType: String {
            switch self {
            case .type(let fileType): return fileType
            case .pattern: return BuildRule.filePatternFileType
            }
        }

        public var pattern: String? {
            switch self {
            case .type: return nil
            case .pattern(let pattern): return pattern
            }
        }

        public static func == (lhs: FileType, rhs: FileType) -> Bool {
            switch (lhs, rhs) {
            case (.type(let lhsFileType), .type(let rhsFileType)):
                return lhsFileType == rhsFileType
            case (.pattern(let lhsPattern), .pattern(let rhsPattern)):
                return lhsPattern == rhsPattern
            default:
                return false
            }
        }
    }

    public enum Action: Equatable {
        case compilerSpec(String)
        case script(String)

        public var compilerSpec: String {
            switch self {
            case .compilerSpec(let compilerSpec): return compilerSpec
            case .script: return BuildRule.scriptCompilerSpec
            }
        }

        public var script: String? {
            switch self {
            case .compilerSpec: return nil
            case .script(let script): return script
            }
        }

        public static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.compilerSpec(let lhsCompilerSpec), .compilerSpec(let rhsCompilerSpec)):
                return lhsCompilerSpec == rhsCompilerSpec
            case (.script(let lhsScript), .script(let rhsScript)):
                return lhsScript == rhsScript
            default:
                return false
            }
        }
    }

    public var fileType: FileType
    public var action: Action
    public var outputFiles: [String]
    public var outputFilesCompilerFlags: [String]
    public var name: String?

    public init(fileType: FileType, action: Action, name: String? = nil, outputFiles: [String] = [], outputFilesCompilerFlags: [String] = []) {
        self.fileType = fileType
        self.action = action
        self.name = name
        self.outputFiles = outputFiles
        self.outputFilesCompilerFlags = outputFilesCompilerFlags
    }
}

extension BuildRule: Equatable {

    public static func == (lhs: BuildRule, rhs: BuildRule) -> Bool {
        return lhs.outputFiles == rhs.outputFiles &&
            lhs.outputFilesCompilerFlags == rhs.outputFilesCompilerFlags &&
            lhs.fileType == rhs.fileType &&
            lhs.action == rhs.action &&
            lhs.name == rhs.name
    }
}

extension BuildRule: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        
        if let fileType: String = jsonDictionary.json(atKeyPath: "fileType") {
            self.fileType = .type(fileType)
        } else {
            self.fileType = .pattern(try jsonDictionary.json(atKeyPath: "filePattern"))
        }

        if let compilerSpec: String = jsonDictionary.json(atKeyPath: "compilerSpec") {
            self.action = .compilerSpec(compilerSpec)
        } else {
            self.action = .script(try jsonDictionary.json(atKeyPath: "script"))
        }

        outputFiles = jsonDictionary.json(atKeyPath: "outputFiles") ?? []
        outputFilesCompilerFlags = jsonDictionary.json(atKeyPath: "outputFilesCompilerFlags") ?? []
        name = jsonDictionary.json(atKeyPath: "name")
    }
}

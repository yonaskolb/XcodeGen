import Foundation
import JSONUtilities

public struct BuildRule: Equatable {

    public static let scriptCompilerSpec = "com.apple.compilers.proxy.script"
    public static let filePatternFileType = "pattern.proxy"

    public enum FileType: Equatable {
        case type(String)
        case pattern(String)

        public var fileType: String {
            switch self {
            case let .type(fileType): return fileType
            case .pattern: return BuildRule.filePatternFileType
            }
        }

        public var pattern: String? {
            switch self {
            case .type: return nil
            case let .pattern(pattern): return pattern
            }
        }
    }

    public enum Action: Equatable {
        case compilerSpec(String)
        case script(String)

        public var compilerSpec: String {
            switch self {
            case let .compilerSpec(compilerSpec): return compilerSpec
            case .script: return BuildRule.scriptCompilerSpec
            }
        }

        public var script: String? {
            switch self {
            case .compilerSpec: return nil
            case let .script(script): return script
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

extension BuildRule: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {

        if let fileType: String = jsonDictionary.json(atKeyPath: "fileType") {
            self.fileType = .type(fileType)
        } else {
            fileType = .pattern(try jsonDictionary.json(atKeyPath: "filePattern"))
        }

        if let compilerSpec: String = jsonDictionary.json(atKeyPath: "compilerSpec") {
            action = .compilerSpec(compilerSpec)
        } else {
            action = .script(try jsonDictionary.json(atKeyPath: "script"))
        }

        outputFiles = jsonDictionary.json(atKeyPath: "outputFiles") ?? []
        outputFilesCompilerFlags = jsonDictionary.json(atKeyPath: "outputFilesCompilerFlags") ?? []
        name = jsonDictionary.json(atKeyPath: "name")
    }
}

extension BuildRule: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "outputFiles": outputFiles,
            "outputFilesCompilerFlags": outputFilesCompilerFlags,
            "name": name,
        ]

        switch fileType {
        case .pattern(let string):
            dict["filePattern"] = string
        case .type(let string):
            dict["fileType"] = string
        }

        switch action {
        case .compilerSpec(let string):
            dict["compilerSpec"] = string
        case .script(let string):
            dict["script"] = string
        }

        return dict
    }
}

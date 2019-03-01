import Foundation
import JSONUtilities

public enum ScriptType: Equatable {
    case path(String)
    case script(String)
}

extension ScriptType: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        if let string: String = jsonDictionary.json(atKeyPath: "script") {
            self = .script(string)
        } else {
            let path: String = try jsonDictionary.json(atKeyPath: "path")
            self = .path(path)
        }
    }
}

public struct BuildScript: Equatable {

    public var script: ScriptType
    public var name: String?
    public var shell: String?
    public var inputFiles: [String]
    public var outputFiles: [String]
    public var inputFileLists: [String]
    public var outputFileLists: [String]
    public var runOnlyWhenInstalling: Bool
    public let showEnvVars: Bool

    public init(
        script: ScriptType,
        name: String? = nil,
        inputFiles: [String] = [],
        outputFiles: [String] = [],
        inputFileLists: [String] = [],
        outputFileLists: [String] = [],
        shell: String? = nil,
        runOnlyWhenInstalling: Bool = false,
        showEnvVars: Bool = true
    ) {
        self.script = script
        self.name = name
        self.inputFiles = inputFiles
        self.outputFiles = outputFiles
        self.inputFileLists = inputFileLists
        self.outputFileLists = outputFileLists
        self.shell = shell
        self.runOnlyWhenInstalling = runOnlyWhenInstalling
        self.showEnvVars = showEnvVars
    }
}

extension BuildScript: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        name = jsonDictionary.json(atKeyPath: "name")
        inputFiles = jsonDictionary.json(atKeyPath: "inputFiles") ?? []
        outputFiles = jsonDictionary.json(atKeyPath: "outputFiles") ?? []
        inputFileLists = jsonDictionary.json(atKeyPath: "inputFileLists") ?? []
        outputFileLists = jsonDictionary.json(atKeyPath: "outputFileLists") ?? []
        script = try ScriptType(jsonDictionary: jsonDictionary)
        shell = jsonDictionary.json(atKeyPath: "shell")
        runOnlyWhenInstalling = jsonDictionary.json(atKeyPath: "runOnlyWhenInstalling") ?? false
        showEnvVars = jsonDictionary.json(atKeyPath: "showEnvVars") ?? true
    }
}

extension BuildScript: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .string("path"),
        ]
    }
}

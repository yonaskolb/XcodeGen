import Foundation
import JSONUtilities

public struct BuildScript: Equatable {

    public var script: ScriptType
    public var name: String?
    public var shell: String?
    public var inputFiles: [String]
    public var outputFiles: [String]
    public var runOnlyWhenInstalling: Bool
    public let showEnvVars: Bool

    public enum ScriptType: Equatable {
        case path(String)
        case script(String)
    }

    public init(
        script: ScriptType,
        name: String? = nil,
        inputFiles: [String] = [],
        outputFiles: [String] = [],
        shell: String? = nil,
        runOnlyWhenInstalling: Bool = false,
        showEnvVars: Bool = true
    ) {
        self.script = script
        self.name = name
        self.inputFiles = inputFiles
        self.outputFiles = outputFiles
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

        if let string: String = jsonDictionary.json(atKeyPath: "script") {
            script = .script(string)
        } else {
            let path: String = try jsonDictionary.json(atKeyPath: "path")
            script = .path(path)
        }
        shell = jsonDictionary.json(atKeyPath: "shell")
        runOnlyWhenInstalling = jsonDictionary.json(atKeyPath: "runOnlyWhenInstalling") ?? false
        showEnvVars = jsonDictionary.json(atKeyPath: "showEnvVars") ?? true
    }
}

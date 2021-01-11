import Foundation
import JSONUtilities

public struct BuildScript: Equatable {
    public static let runOnlyWhenInstallingDefault = false
    public static let showEnvVarsDefault = true
    public static let basedOnDependencyAnalysisDefault = true

    public var script: ScriptType
    public var name: String?
    public var shell: String?
    public var inputFiles: [String]
    public var outputFiles: [String]
    public var inputFileLists: [String]
    public var outputFileLists: [String]
    public var runOnlyWhenInstalling: Bool
    public let showEnvVars: Bool
    public let basedOnDependencyAnalysis: Bool

    public enum ScriptType: Equatable {
        case path(String)
        case script(String)
    }

    public init(
        script: ScriptType,
        name: String? = nil,
        inputFiles: [String] = [],
        outputFiles: [String] = [],
        inputFileLists: [String] = [],
        outputFileLists: [String] = [],
        shell: String? = nil,
        runOnlyWhenInstalling: Bool = runOnlyWhenInstallingDefault,
        showEnvVars: Bool = showEnvVarsDefault,
        basedOnDependencyAnalysis: Bool = basedOnDependencyAnalysisDefault
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
        self.basedOnDependencyAnalysis = basedOnDependencyAnalysis
    }
}

extension BuildScript: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        name = jsonDictionary.json(atKeyPath: "name")
        inputFiles = jsonDictionary.json(atKeyPath: "inputFiles") ?? []
        outputFiles = jsonDictionary.json(atKeyPath: "outputFiles") ?? []
        inputFileLists = jsonDictionary.json(atKeyPath: "inputFileLists") ?? []
        outputFileLists = jsonDictionary.json(atKeyPath: "outputFileLists") ?? []

        if let string: String = jsonDictionary.json(atKeyPath: "script") {
            script = .script(string)
        } else {
            let path: String = try jsonDictionary.json(atKeyPath: "path")
            script = .path(path)
        }
        shell = jsonDictionary.json(atKeyPath: "shell")
        runOnlyWhenInstalling = jsonDictionary.json(atKeyPath: "runOnlyWhenInstalling") ?? BuildScript.runOnlyWhenInstallingDefault
        showEnvVars = jsonDictionary.json(atKeyPath: "showEnvVars") ?? BuildScript.showEnvVarsDefault
        basedOnDependencyAnalysis = jsonDictionary.json(atKeyPath: "basedOnDependencyAnalysis") ?? BuildScript.basedOnDependencyAnalysisDefault
    }
}

extension BuildScript: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "inputFiles": inputFiles,
            "inputFileLists": inputFileLists,
            "outputFiles": outputFiles,
            "outputFileLists": outputFileLists,
            "runOnlyWhenInstalling": runOnlyWhenInstalling,
            "name": name,
            "shell": shell,
        ]

        if showEnvVars != BuildScript.showEnvVarsDefault {
            dict["showEnvVars"] = showEnvVars
        }

        if basedOnDependencyAnalysis != BuildScript.basedOnDependencyAnalysisDefault {
            dict["basedOnDependencyAnalysis"] = basedOnDependencyAnalysis
        }

        switch script {
        case .path(let string):
            dict["path"] = string
        case .script(let string):
            dict["script"] = string
        }

        return dict
    }
}

extension BuildScript: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("path"),
        ]
    }
}

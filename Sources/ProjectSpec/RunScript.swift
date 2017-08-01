//
//  RunScript.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 1/8/17.
//
//

import Foundation
import JSONUtilities

public struct RunScript: Equatable {

    public var script: ScriptType
    public var name: String?
    public var shell: String?
    public var inputFiles: [String]
    public var outputFiles: [String]

    public enum ScriptType: Equatable {
        case path(String)
        case script(String)

        public static func ==(lhs: ScriptType, rhs: ScriptType) -> Bool {
            switch (lhs, rhs) {
            case let (.path(lhs), .path(rhs)): return lhs == rhs
            case let (.script(lhs), .script(rhs)): return lhs == rhs
            default: return false
            }
        }
    }

    public init(script: ScriptType, name: String? = nil, inputFiles: [String] = [], outputFiles: [String] = [], shell: String? = nil) {
        self.script = script
        self.name = name
        self.inputFiles = inputFiles
        self.outputFiles = outputFiles
        self.shell = shell
    }

    public static func ==(lhs: RunScript, rhs: RunScript) -> Bool {
        return lhs.script == rhs.script &&
            lhs.name == rhs.name &&
            lhs.script == rhs.script &&
            lhs.inputFiles == rhs.inputFiles &&
            lhs.outputFiles == rhs.outputFiles &&
            lhs.shell == rhs.shell
    }
}

extension RunScript: JSONObjectConvertible {

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
    }
}

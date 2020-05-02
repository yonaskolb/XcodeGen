//
//  File.swift
//  
//
//  Created by Yonas Kolb on 1/5/20.
//

import Foundation
import XcodeProj
import JSONUtilities

public enum BuildPhaseSpec: Equatable {
    case sources
    case headers
    case resources
    case copyFiles(CopyFilesSettings)
    case none
    // Not currently exposed as selectable options, but used internally
    case frameworks
    case runScript
    case carbonResources

    public struct CopyFilesSettings: Equatable, Hashable {
        public static let xpcServices = CopyFilesSettings(
            destination: .productsDirectory,
            subpath: "$(CONTENTS_FOLDER_PATH)/XPCServices",
            phaseOrder: .postCompile
        )

        public enum Destination: String {
            case absolutePath
            case productsDirectory
            case wrapper
            case executables
            case resources
            case javaResources
            case frameworks
            case sharedFrameworks
            case sharedSupport
            case plugins

            public var destination: PBXCopyFilesBuildPhase.SubFolder? {
                switch self {
                case .absolutePath: return .absolutePath
                case .productsDirectory: return .productsDirectory
                case .wrapper: return .wrapper
                case .executables: return .executables
                case .resources: return .resources
                case .javaResources: return .javaResources
                case .frameworks: return .frameworks
                case .sharedFrameworks: return .sharedFrameworks
                case .sharedSupport: return .sharedSupport
                case .plugins: return .plugins
                }
            }
        }

        public enum PhaseOrder: String {
            /// Run before the Compile Sources phase
            case preCompile
            /// Run after the Compile Sources and post-compile Run Script phases
            case postCompile
        }

        public var destination: Destination
        public var subpath: String
        public var phaseOrder: PhaseOrder

        public init(
            destination: Destination,
            subpath: String,
            phaseOrder: PhaseOrder
        ) {
            self.destination = destination
            self.subpath = subpath
            self.phaseOrder = phaseOrder
        }
    }

    public var buildPhase: BuildPhase? {
        switch self {
        case .sources: return .sources
        case .headers: return .headers
        case .resources: return .resources
        case .copyFiles: return .copyFiles
        case .frameworks: return .frameworks
        case .runScript: return .runScript
        case .carbonResources: return .carbonResources
        case .none: return nil
        }
    }
}

extension BuildPhaseSpec {

    public init(string: String) throws {
        switch string {
        case "sources": self = .sources
        case "headers": self = .headers
        case "resources": self = .resources
        case "copyFiles":
            throw SpecParsingError.invalidSourceBuildPhase("copyFiles must specify a \"destination\" and optional \"subpath\"")
        case "none": self = .none
        default:
            throw SpecParsingError.invalidSourceBuildPhase(string.quoted)
        }
    }
}

extension BuildPhaseSpec: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        self = .copyFiles(try jsonDictionary.json(atKeyPath: "copyFiles"))
    }
}

extension BuildPhaseSpec: JSONEncodable {
    public func toJSONValue() -> Any {
        switch self {
        case .sources: return "sources"
        case .headers: return "headers"
        case .resources: return "resources"
        case .copyFiles(let files): return ["copyFiles": files.toJSONValue()]
        case .none: return "none"
        case .frameworks: fatalError("invalid build phase")
        case .runScript: fatalError("invalid build phase")
        case .carbonResources: fatalError("invalid build phase")
        }
    }
}

extension BuildPhaseSpec.CopyFilesSettings: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        destination = try jsonDictionary.json(atKeyPath: "destination")
        subpath = jsonDictionary.json(atKeyPath: "subpath") ?? ""
        phaseOrder = .postCompile
    }
}

extension BuildPhaseSpec.CopyFilesSettings: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "destination": destination.rawValue,
            "subpath": subpath,
        ]
    }
}

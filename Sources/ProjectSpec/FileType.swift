//
//  File.swift
//  
//
//  Created by Yonas Kolb on 1/5/20.
//

import Foundation
import JSONUtilities
import enum XcodeProj.BuildPhase

public struct FileType: Equatable {

    public enum Defaults {
        public static let file = true
    }

    public var file: Bool
    public var buildPhase: BuildPhaseSpec?
    public var attributes: [String]
    public var resourceTags: [String]
    public var compilerFlags: [String]

    public init(
        file: Bool = Defaults.file,
        buildPhase: BuildPhaseSpec? = nil,
        attributes: [String] = [],
        resourceTags: [String] = [],
        compilerFlags: [String] = []
    ) {
        self.file = file
        self.buildPhase = buildPhase
        self.attributes = attributes
        self.resourceTags = resourceTags
        self.compilerFlags = compilerFlags
    }
}

extension FileType: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        if let string: String = jsonDictionary.json(atKeyPath: "buildPhase") {
            buildPhase = try BuildPhaseSpec(string: string)
        } else if let dict: JSONDictionary = jsonDictionary.json(atKeyPath: "buildPhase") {
            buildPhase = try BuildPhaseSpec(jsonDictionary: dict)
        }
        file = jsonDictionary.json(atKeyPath: "file") ?? Defaults.file
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? []
        resourceTags = jsonDictionary.json(atKeyPath: "resourceTags") ?? []
        compilerFlags = jsonDictionary.json(atKeyPath: "compilerFlags") ?? []
    }
}

extension FileType: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "buildPhase": buildPhase?.toJSONValue(),
            "attributes": attributes,
            "resourceTags": resourceTags,
            "compilerFlags": compilerFlags,
        ]
        if file != Defaults.file {
            dict["file"] = file
        }
        return dict
    }
}

extension FileType {

    public static let defaultFileTypes: [String: FileType] = [
        // resources
        "bundle": FileType(buildPhase: .resources),
        "xcassets": FileType(buildPhase: .resources),
        "storekit": FileType(buildPhase: .resources),
        "xcstrings": FileType(buildPhase: .resources),

        // sources
        "swift": FileType(buildPhase: .sources),
        "gyb": FileType(buildPhase: .sources),
        "m": FileType(buildPhase: .sources),
        "mm": FileType(buildPhase: .sources),
        "cpp": FileType(buildPhase: .sources),
        "cp": FileType(buildPhase: .sources),
        "cxx": FileType(buildPhase: .sources),
        "c": FileType(buildPhase: .sources),
        "cc": FileType(buildPhase: .sources),
        "S": FileType(buildPhase: .sources),
        "xcdatamodeld": FileType(buildPhase: .sources),
        "xcmappingmodel": FileType(buildPhase: .sources),
        "intentdefinition": FileType(buildPhase: .sources),
        "metal": FileType(buildPhase: .sources),
        "mlmodel": FileType(buildPhase: .sources),
        "mlpackage" : FileType(buildPhase: .sources),
        "mlmodelc": FileType(buildPhase: .resources),
        "rcproject": FileType(buildPhase: .sources),
        "iig": FileType(buildPhase: .sources),
        "docc": FileType(buildPhase: .sources),

        // headers
        "h": FileType(buildPhase: .headers),
        "hh": FileType(buildPhase: .headers),
        "hpp": FileType(buildPhase: .headers),
        "ipp": FileType(buildPhase: .headers),
        "tpp": FileType(buildPhase: .headers),
        "hxx": FileType(buildPhase: .headers),
        "def": FileType(buildPhase: .headers),

        // frameworks
        "framework": FileType(buildPhase: .frameworks),

        // copyfiles
        "xpc": FileType(buildPhase: .copyFiles(.xpcServices)),

        // no build phase (not resources)
        "xcconfig": FileType(buildPhase: BuildPhaseSpec.none),
        "entitlements": FileType(buildPhase: BuildPhaseSpec.none),
        "gpx": FileType(buildPhase: BuildPhaseSpec.none),
        "lproj": FileType(buildPhase: BuildPhaseSpec.none),
        "xcfilelist": FileType(buildPhase: BuildPhaseSpec.none),
        "apns": FileType(buildPhase: BuildPhaseSpec.none),
        "pch": FileType(buildPhase: BuildPhaseSpec.none),
        "xctestplan": FileType(buildPhase: BuildPhaseSpec.none),
    ]
}

//
//  Target.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 20/7/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities

public struct Target {
    public var name: String
    public var type: PBXProductType
    public var localizedSource: String?
    public var sources: [String]
    public var sourceExludes: [String]
    public var dependancies: [Dependancy]
    public var prebuildScripts: [String]
    public var postbuildScripts: [String]
}

extension Target: NamedJSONObjectConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = PBXProductType(rawValue: typeString) {
            self.type = type
        } else {
            switch typeString {
            case "application": type = .application
            case "framework": type = .framework
            default: throw SpecError.unknownTargetType(typeString)
            }
        }
        sources = jsonDictionary.json(atKeyPath: "sources") ?? []
        sourceExludes = jsonDictionary.json(atKeyPath: "sourceExludes") ?? []
        dependancies = jsonDictionary.json(atKeyPath: "dependancies") ?? []
        prebuildScripts = jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postbuildScripts = jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
    }
}

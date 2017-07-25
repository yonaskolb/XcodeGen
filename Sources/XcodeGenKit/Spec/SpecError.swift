//
//  File.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/7/17.
//
//

import Foundation

public enum SpecError: Error, CustomStringConvertible {
    case unknownTargetType(String)
    case unknownTargetPlatform(String)
    case invalidDependency([String: Any])

    public var description: String {
        switch self {
            case let .unknownTargetType(type): return "Unknown Target type: \(type)"
            case let .unknownTargetPlatform(platform): return "Unknown Target platform: \(platform)"
            case let .invalidDependency(dependency): return "Unknown Target dependency: \(dependency)"
        }
    }
}

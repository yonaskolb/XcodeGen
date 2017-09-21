//
//  Configuration.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 20/7/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities

public struct Configuration: Equatable {
    public var name: String
    public var type: ConfigurationType?

    public init(name: String, type: ConfigurationType? = nil) {
        self.name = name
        self.type = type
    }

    public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
        return lhs.name == rhs.name && lhs.type == rhs.type
    }
}

public enum ConfigurationType: String {
    case debug
    case release
}

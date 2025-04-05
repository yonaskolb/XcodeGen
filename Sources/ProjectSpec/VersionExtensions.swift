//
//  File.swift
//
//
//  Created by Yonas Kolb on 7/2/20.
//

import Foundation
import Version

extension Version: Swift.ExpressibleByStringLiteral {

    public static func parse(_ string: String) throws -> Version {
        if let version = Version(tolerant: string) {
            return version
        } else {
            throw SpecParsingError.invalidVersion(string)
        }
    }

    public static func parse(_ double: Double) throws -> Version {
        return try Version.parse(String(double))
    }

    public init(stringLiteral value: String) {
        self.init(tolerant: value)!
    }
}

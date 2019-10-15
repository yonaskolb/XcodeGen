//
//  TargetReference.swift
//  ProjectSpec
//
//  Created by Yuta Saito on 2019/10/15.
//

import Foundation
import JSONUtilities

public struct TargetReference: Equatable, Hashable {
    public let name: String
    public let location: Location

    public enum Location: Equatable, Hashable {
        case local
        case project(String)
    }

    public init(name: String, location: Location = .local) {
        self.name = name
        self.location = location
    }
}

extension TargetReference {
    public init(string: String) throws {
        let paths = string.split(separator: "/")
        guard paths.count <= 2 && !paths.isEmpty else {
            throw SpecParsingError.invalidTargetReference(string)
        }
        switch paths.count {
        case 2:
            location = .project(String(paths[0]))
            name = String(paths[1])
        case 1:
            location = .local
            name = String(paths[0])
        default: fatalError("unreachable")
        }
    }
}

extension TargetReference: CustomStringConvertible {
    public var reference: String {
        switch location {
        case .local: return name
        case .project(let projectPath):
            return "\(projectPath)/\(name)"
        }
    }

    public var description: String {
        return reference
    }
}

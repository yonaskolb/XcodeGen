//
//  SpecLinter.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 22/7/17.
//
//

import Foundation

public struct SpecLinter {

    public static func lint(_ spec: Spec) -> (spec: Spec, appliedFixits: [SpecLinterFixit], errors: [SpecLinterError]) {
        var spec = spec
        var errors: [SpecLinterError] = []
        var fixits: [SpecLinterFixit] = []

        if spec.configs.isEmpty {
            spec.configs = [Config(name: "Debug", type: .debug), Config(name: "Release", type: .release)]
            fixits.append(.createdConfigs)
        }

        for target in spec.targets {
            for dependency in target.dependencies {
                if case .target(let target) = dependency, !spec.targets.contains(where: { $0.name == target}) {
                    errors.append(.invalidTargetDependency(target))
                }
            }
        }

        return (spec, fixits, errors)
    }
}

public enum SpecLinterError: CustomStringConvertible {
    case invalidTargetDependency(String)

    public var description: String {
        switch self {
        case let .invalidTargetDependency(dependency): return "Invalid target dependency \(dependency)"
        }
    }
}

public enum SpecLinterFixit: CustomStringConvertible {
    case createdConfigs

    public var description: String {
        switch self {
        case .createdConfigs: return "Created default debug and release configs"
        }
    }
}

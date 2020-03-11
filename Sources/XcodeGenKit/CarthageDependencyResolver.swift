//
//  CarthageDependencyResolver.swift
//  XcodeGenKit
//
//  Created by Rogerio de Paula Assis on 2/4/19.
//

import Foundation
import ProjectSpec
import PathKit

public class CarthageDependencyResolver {
    static func getBuildPath(_ project: Project) -> String {
        return project.options.carthageBuildPath ?? "Carthage/Build"
    }

    /// Carthage's base build path as specified by the
    /// project's `SpecOptions`, or `Carthage/Build` by default
    var buildPath: String {
        return CarthageDependencyResolver.getBuildPath(project)
    }

    /// Carthage's executable path as specified by the
    /// project's `SpecOptions`, or `carthage` by default
    var executable: String {
        project.options.carthageExecutablePath ?? "carthage"
    }

    private let project: Project
    let versionLoader: CarthageVersionLoader

    init(project: Project) {
        self.project = project
        versionLoader = CarthageVersionLoader(buildPath: project.basePath + CarthageDependencyResolver.getBuildPath(project))
    }

    /// Carthage's build path for the given platform
    func buildPath(for platform: Platform, linkType: Dependency.CarthageLinkType) -> String {
        switch linkType {
        case .static:
            return "\(buildPath)/\(platform.carthageName)/Static"
        case .dynamic:
            return "\(buildPath)/\(platform.carthageName)"
        }
    }

    /// Fetches all carthage dependencies for a given target
    func dependencies(for topLevelTarget: Target) -> [Dependency] {
        // this is used to resolve cyclical target dependencies
        var visitedTargets: Set<String> = []
        var frameworks: Set<Dependency> = []

        var queue: [ProjectTarget] = [topLevelTarget]
        while !queue.isEmpty {
            let projectTarget = queue.removeFirst()
            if visitedTargets.contains(projectTarget.name) {
                continue
            }

            if let target = projectTarget as? Target {
                // don't overwrite frameworks, to allow top level ones to rule
                let nonExistentDependencies = target.dependencies.filter { !frameworks.contains($0) }
                for dependency in nonExistentDependencies {
                    switch dependency.type {
                    case .carthage(let findFrameworks, _):
                        let findFrameworks = findFrameworks ?? project.options.findCarthageFrameworks
                        if findFrameworks {
                            relatedDependencies(for: dependency, in: target.platform)
                                .filter { !frameworks.contains($0) }
                                .forEach { frameworks.insert($0) }
                        } else {
                            frameworks.insert(dependency)
                        }
                    case .target:
                        if let projectTarget = project.getProjectTarget(dependency.reference) {
                            if let dependencyTarget = projectTarget as? Target {
                                if topLevelTarget.platform == dependencyTarget.platform {
                                    queue.append(projectTarget)
                                }
                            } else {
                                queue.append(projectTarget)
                            }
                        }
                    default:
                        break
                    }
                }
            } else if let aggregateTarget = projectTarget as? AggregateTarget {
                for dependencyName in aggregateTarget.targets {
                    if let projectTarget = project.getProjectTarget(dependencyName) {
                        queue.append(projectTarget)
                    }
                }
            }

            visitedTargets.update(with: projectTarget.name)
        }

        return frameworks.sorted(by: { $0.reference < $1.reference })
    }

    /// Reads the .version file generated for a given Carthage dependency
    /// and returns a list of its related dependencies including self
    func relatedDependencies(for dependency: Dependency, in platform: Platform) -> [Dependency] {
        guard
            case .carthage = dependency.type,
            let versionFile = try? versionLoader.getVersionFile(for: dependency.reference) else {
            // No .version file or we've been unable to parse
            // so fail gracefully by returning the main dependency
            return [dependency]
        }
        return versionFile.frameworks(for: platform)
            .map { Dependency(
                type: dependency.type,
                reference: $0,
                embed: dependency.embed,
                codeSign: dependency.codeSign,
                link: dependency.link,
                implicit: dependency.implicit,
                weakLink: dependency.weakLink
            ) }
            .sorted(by: { $0.reference < $1.reference })
    }
}

extension Platform {

    public var carthageName: String {
        switch self {
        case .iOS:
            return "iOS"
        case .tvOS:
            return "tvOS"
        case .watchOS:
            return "watchOS"
        case .macOS:
            return "Mac"
        }
    }
}

//
//  CarthageDependencyResolver.swift
//  XcodeGenKit
//
//  Created by Rogerio de Paula Assis on 2/4/19.
//

import Foundation
import ProjectSpec
import PathKit

public struct CarthageDependencyResolver {

    /// Carthage's base build path as specified by the
    /// project's `SpecOptions`, or `Carthage/Build` by default
    var baseBuildPath: String {
        return project.options.carthageBuildPath ?? "Carthage/Build"
    }

    /// Carthage's executable path as specified by the
    /// project's `SpecOptions`, or `carthage` by default
    var executablePath: String {
        return project.options.carthageExecutablePath ?? "carthage"
    }

    /// Carthage's build path for the given platform
    func buildPath(for platform: Platform) -> String {
        let carthagePath = Path(baseBuildPath)
        let platformName = platform.carthageDirectoryName
        return "\(carthagePath)/\(platformName)"
    }

    // Keeps a cache of previously parsed related dependencies
    private var carthageCachedRelatedDependencies: [String: CarthageVersionFile] = [:]
    private let project: Project
    
    init(project: Project) {
        self.project = project
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
                    case .carthage(let includeRelated):
                        let includeRelated = includeRelated ?? project.options.includeCarthageRelatedDependencies
                        if includeRelated {
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
            let versionFile = try? fetchCarthageVersionFile(for: dependency) else {
                // No .version file or we've been unable to parse
                // so fail gracefully by returning the main dependency
                return [dependency]
        }
        return versionFile.references(for: platform)
            .map { $0.name }
            .map { Dependency(
                type: dependency.type,
                reference: $0,
                embed: dependency.embed,
                codeSign: dependency.codeSign,
                link: dependency.link,
                implicit: dependency.implicit,
                weakLink: dependency.weakLink
            )}
            .sorted(by: { $0.reference < $1.reference })
    }

    private func fetchCarthageVersionFile(for dependency: Dependency) throws -> CarthageVersionFile {
        if let cachedVersionFile = carthageCachedRelatedDependencies[dependency.reference] {
            return cachedVersionFile
        }
        let buildPath = project.basePath + "\(self.baseBuildPath)/.\(dependency.reference).version"
        let data = try buildPath.read()
        let carthageVersionFile = try JSONDecoder().decode(CarthageVersionFile.self, from: data)
        return carthageVersionFile
    }
}

/// Decodable struct for type safe parsing of the .version file
fileprivate struct CarthageVersionFile: Decodable {

    struct Reference: Decodable, Equatable {
        public let name: String
        public let hash: String
    }

    enum Key: String, CodingKey, CaseIterable {
        case iOS
        case Mac
        case tvOS
        case watchOS
    }

    private let data: [Key: [Reference]]
    fileprivate init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        data = try Key.allCases.reduce(into: [:]) { (current, nextKey) in
            let refs = try container.decodeIfPresent([Reference].self, forKey: nextKey)
            current[nextKey] = refs
        }
    }
}

fileprivate extension CarthageVersionFile {
    fileprivate func references(for platform: Platform) -> [Reference] {
        switch platform {
        case .iOS: return data[.iOS] ?? []
        case .watchOS: return data[.watchOS] ?? []
        case .tvOS: return data[.tvOS] ?? []
        case .macOS: return data[.Mac] ?? []
        }
    }
}

    

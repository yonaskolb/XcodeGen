import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import Version

class QueryCommand: ProjectCommand {

    @Key("--type", "-t", description: "Query type. One of: targets, target, sources, settings, dependencies. Defaults to targets.")
    private var queryType: QueryType?

    @Key("--name", "-n", description: "Target name. Required for: target, sources, settings, dependencies.")
    private var targetName: String?

    @Key("--config", description: "Config name for settings queries (e.g. Debug, Release).")
    private var config: String?

    init(version: Version) {
        super.init(version: version,
                   name: "query",
                   shortDescription: "Query the resolved project spec and return focused JSON")
    }

    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {
        let type = queryType ?? .targets

        switch type {
        case .targets:
            let summaries = project.targets.map {
                TargetSummary(name: $0.name, type: $0.type.name, platform: $0.platform.rawValue)
            }
            success(try encode(summaries))

        case .target:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            success(try encode(TargetDetail(target: target)))

        case .sources:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            success(try encode(target.sources.map { $0.path }))

        case .settings:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            let settings: [String: String]
            if let config = config {
                let configSettings = target.settings.configSettings[config]?.buildSettings ?? [:]
                settings = configSettings.mapValues { $0.description }
            } else {
                settings = target.settings.buildSettings.mapValues { $0.description }
            }
            success(try encode(settings))

        case .dependencies:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            success(try encode(target.dependencies.map { DependencySummary(dependency: $0) }))
        }
    }

    private func requireName(for type: QueryType) throws -> String {
        guard let name = targetName else {
            throw QueryError.missingName(type.rawValue)
        }
        return name
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Query type

private enum QueryType: String, ConvertibleFromString {
    case targets
    case target
    case sources
    case settings
    case dependencies
}

// MARK: - Errors

private enum QueryError: Error, CustomStringConvertible, ProcessError {
    case targetNotFound(String)
    case missingName(String)

    var description: String {
        switch self {
        case let .targetNotFound(name): return #"{"error":"target '\#(name)' not found"}"#
        case let .missingName(type):    return #"{"error":"--name is required for query type '\#(type)'"}"#
        }
    }

    var message: String? { description }
    var exitStatus: Int32 { 1 }
}

// MARK: - Encodable response types

private struct TargetSummary: Encodable {
    let name: String
    let type: String
    let platform: String
}

private struct TargetDetail: Encodable {
    let name: String
    let type: String
    let platform: String
    let deploymentTarget: String?
    let sources: [String]
    let dependencies: [DependencySummary]

    init(target: Target) {
        self.name = target.name
        self.type = target.type.name
        self.platform = target.platform.rawValue
        self.deploymentTarget = target.deploymentTarget?.description
        self.sources = target.sources.map { $0.path }
        self.dependencies = target.dependencies.map { DependencySummary(dependency: $0) }
    }
}

private struct DependencySummary: Encodable {
    let type: String
    let reference: String

    init(dependency: Dependency) {
        self.reference = dependency.reference
        switch dependency.type {
        case .target:    self.type = "target"
        case .framework: self.type = "framework"
        case .sdk:       self.type = "sdk"
        case .package:   self.type = "package"
        case .carthage:  self.type = "carthage"
        case .bundle:    self.type = "bundle"
        }
    }
}

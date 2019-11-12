import Foundation
import JSONUtilities

extension Scheme {

    public struct Build: Equatable {
        public static let parallelizeBuildDefault = true
        public static let buildImplicitDependenciesDefault = true

        public var targets: [BuildTarget]
        public var parallelizeBuild: Bool
        public var buildImplicitDependencies: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            targets: [BuildTarget],
            parallelizeBuild: Bool = parallelizeBuildDefault,
            buildImplicitDependencies: Bool = buildImplicitDependenciesDefault,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.targets = targets
            self.parallelizeBuild = parallelizeBuild
            self.buildImplicitDependencies = buildImplicitDependencies
            self.preActions = preActions
            self.postActions = postActions
        }
    }
}

extension Scheme.Build: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let targetDictionary: JSONDictionary = try jsonDictionary.json(atKeyPath: "targets")
        var targets: [Scheme.BuildTarget] = []
        for (targetRepr, possibleBuildTypes) in targetDictionary {
            let buildTypes: [BuildType]
            if let string = possibleBuildTypes as? String {
                switch string {
                case "all": buildTypes = BuildType.all
                case "none": buildTypes = []
                case "testing": buildTypes = [.testing, .analyzing]
                case "indexing": buildTypes = [.testing, .analyzing, .archiving]
                default: buildTypes = BuildType.all
                }
            } else if let enabledDictionary = possibleBuildTypes as? [String: Bool] {
                buildTypes = enabledDictionary.filter { $0.value }.compactMap { BuildType.from(jsonValue: $0.key) }
            } else if let array = possibleBuildTypes as? [String] {
                buildTypes = array.compactMap(BuildType.from)
            } else {
                buildTypes = BuildType.all
            }
            let target = try TargetReference(targetRepr)
            targets.append(Scheme.BuildTarget(target: target, buildTypes: buildTypes))
        }
        self.targets = targets.sorted { $0.target.name < $1.target.name }
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        parallelizeBuild = jsonDictionary.json(atKeyPath: "parallelizeBuild") ?? Scheme.Build.parallelizeBuildDefault
        buildImplicitDependencies = jsonDictionary.json(atKeyPath: "buildImplicitDependencies") ?? Scheme.Build.buildImplicitDependenciesDefault
    }
}

extension Scheme.Build: JSONEncodable {
    public func toJSONValue() -> Any {
        let targetPairs = targets.map { ($0.target.reference, $0.buildTypes.map { $0.toJSONValue() }) }

        var dict: JSONDictionary = [
            "targets": Dictionary(uniqueKeysWithValues: targetPairs),
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
        ]

        if parallelizeBuild != Scheme.Build.parallelizeBuildDefault {
            dict["parallelizeBuild"] = parallelizeBuild
        }
        if buildImplicitDependencies != Scheme.Build.buildImplicitDependenciesDefault {
            dict["buildImplicitDependencies"] = buildImplicitDependencies
        }

        return dict
    }
}

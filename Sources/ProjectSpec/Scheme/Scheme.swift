import Foundation
import JSONUtilities
import XcodeProj

public struct Scheme: Equatable {

    public var name: String
    public var build: Build
    public var run: Run?
    public var archive: Archive?
    public var analyze: Analyze?
    public var test: Test?
    public var profile: Profile?

    public init(
        name: String,
        build: Build,
        run: Run? = nil,
        test: Test? = nil,
        profile: Profile? = nil,
        analyze: Analyze? = nil,
        archive: Archive? = nil
    ) {
        self.name = name
        self.build = build
        self.run = run
        self.test = test
        self.profile = profile
        self.analyze = analyze
        self.archive = archive
    }

    public struct BuildTarget: Equatable, Hashable {
        public var target: TargetReference
        public var buildTypes: [BuildType]

        public init(target: TargetReference, buildTypes: [BuildType] = BuildType.all) {
            self.target = target
            self.buildTypes = buildTypes
        }
    }
}

extension Scheme: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .dictionary([
                .object("test", Test.pathProperties),
            ]),
        ]
    }
}

extension Scheme: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        build = try jsonDictionary.json(atKeyPath: "build")
        run = jsonDictionary.json(atKeyPath: "run")
        test = jsonDictionary.json(atKeyPath: "test")
        analyze = jsonDictionary.json(atKeyPath: "analyze")
        profile = jsonDictionary.json(atKeyPath: "profile")
        archive = jsonDictionary.json(atKeyPath: "archive")
    }
}

extension Scheme: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "build": build.toJSONValue(),
            "run": run?.toJSONValue(),
            "test": test?.toJSONValue(),
            "analyze": analyze?.toJSONValue(),
            "profile": profile?.toJSONValue(),
            "archive": archive?.toJSONValue(),
        ] as [String: Any?]
    }
}

protocol BuildAction: Equatable {
    var config: String? { get }
}

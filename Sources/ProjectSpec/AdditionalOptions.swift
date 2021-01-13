import Foundation
import JSONUtilities

public struct AdditionalOptions: Equatable, Hashable {
    public var mallocScribble: Bool
    public var mallocGuardEdges: Bool
    public var guardMalloc: Bool
    public var zombieObjects: Bool

    public init(mallocScribble: Bool,
                mallocGuardEdges: Bool,
                guardMalloc: Bool,
                zombieObjects: Bool) {
        self.mallocScribble = mallocScribble
        self.mallocGuardEdges = mallocGuardEdges
        self.guardMalloc = guardMalloc
        self.zombieObjects = zombieObjects
    }
}

extension AdditionalOptions: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        mallocScribble = jsonDictionary.json(atKeyPath: "mallocScribble") ?? false
        mallocGuardEdges = jsonDictionary.json(atKeyPath: "mallocGuardEdges") ?? false
        guardMalloc = jsonDictionary.json(atKeyPath: "guardMalloc") ?? false
        zombieObjects = jsonDictionary.json(atKeyPath: "zombieObjects") ?? false
    }
}

extension AdditionalOptions: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "mallocScribble": mallocScribble,
            "mallocGuardEdges": mallocGuardEdges,
            "guardMalloc": guardMalloc,
            "zombieObjects": zombieObjects,
        ]
    }
}

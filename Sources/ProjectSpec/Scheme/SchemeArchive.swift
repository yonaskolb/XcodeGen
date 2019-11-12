import Foundation
import JSONUtilities

extension Scheme {

    public struct Archive: BuildAction {
        public static let revealArchiveInOrganizerDefault = true

        public var config: String?
        public var customArchiveName: String?
        public var revealArchiveInOrganizer: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            config: String? = nil,
            customArchiveName: String? = nil,
            revealArchiveInOrganizer: Bool = revealArchiveInOrganizerDefault,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.config = config
            self.customArchiveName = customArchiveName
            self.revealArchiveInOrganizer = revealArchiveInOrganizer
            self.preActions = preActions
            self.postActions = postActions
        }
    }
}

extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        customArchiveName = jsonDictionary.json(atKeyPath: "customArchiveName")
        revealArchiveInOrganizer = jsonDictionary.json(atKeyPath: "revealArchiveInOrganizer") ?? Scheme.Archive.revealArchiveInOrganizerDefault
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
    }
}

extension Scheme.Archive: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "config": config,
            "customArchiveName": customArchiveName,
        ]

        if revealArchiveInOrganizer != Scheme.Archive.revealArchiveInOrganizerDefault {
            dict["revealArchiveInOrganizer"] = revealArchiveInOrganizer
        }

        return dict
    }
}

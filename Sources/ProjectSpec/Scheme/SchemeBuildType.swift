import Foundation
import JSONUtilities
import XcodeProj

public typealias BuildType = XCScheme.BuildAction.Entry.BuildFor

extension BuildType: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> BuildType? {
        switch jsonValue {
        case "test", "testing": return .testing
        case "profile", "profiling": return .profiling
        case "run", "running": return .running
        case "archive", "archiving": return .archiving
        case "analyze", "analyzing": return .analyzing
        default: return nil
        }
    }

    public static var all: [BuildType] {
        [.running, .testing, .profiling, .analyzing, .archiving]
    }
}

extension BuildType: JSONEncodable {
    public func toJSONValue() -> Any {
        switch self {
        case .testing: return "testing"
        case .profiling: return "profiling"
        case .running: return "running"
        case .archiving: return "archiving"
        case .analyzing: return "analyzing"
        }
    }
}

import Foundation

public enum BridgingHeader: RawRepresentable, Decodable {
    public typealias RawValue = String
    case none
    case targetName(directoryPath: URL)
    case custom(URL)
    
    public init?(rawValue: String) {
        let data = rawValue.data(using: .utf8)!
        guard let value = try? JSONDecoder().decode(BridgingHeader.self, from: data) else {
            fatalError()
        }
        self = value
    }
    
    enum CodinngKeys: CodingKey {
        case none
        case targetName
        case custom
    }
    
    public var rawValue: String {
        switch self {
        case .none: return "none"
        case .targetName: return "targetName"
        case .custom(let custom):
            return custom.absoluteString
        }
    }
}

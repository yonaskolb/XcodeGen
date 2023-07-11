import Foundation
import JSONUtilities

public struct BuildToolPlugin: Equatable {
    
    public var package: String
    public var product: String
    
    public init(
        package: String,
        product: String
    ) {
        self.package = package
        self.product = product
    }
}

extension BuildToolPlugin: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let package: String = jsonDictionary.json(atKeyPath: "package") {
            self.package = package
        } else {
            throw SpecParsingError.invalidDependency(jsonDictionary)
        }
        
        if let product: String = jsonDictionary.json(atKeyPath: "product") {
            self.product = product
        } else {
            throw SpecParsingError.invalidDependency(jsonDictionary)
        }
    }
}

extension BuildToolPlugin {
    public var uniqueID: String {
        return "\(package)/\(product)"
    }
}

extension BuildToolPlugin: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(package)
    }
}

extension BuildToolPlugin: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "package": package,
            "product": product
        ]
    }
}

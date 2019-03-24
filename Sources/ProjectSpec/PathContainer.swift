import Foundation
import JSONUtilities
import PathKit

protocol PathContainer {

    static var pathProperties: [PathProperty] { get }
}

enum PathProperty {
    case string(String)
    case dictionary([PathProperty])
    case object(String, [PathProperty])
}

extension Array where Element == PathProperty {

    func resolvingPaths(in jsonDictionary: JSONDictionary, relativeTo path: Path) -> JSONDictionary {
        var result = jsonDictionary

        for pathProperty in self {
            switch pathProperty {
            case .string(let key):
                if let source = result[key] as? String {
                    result[key] = (path + source).string
                } else if let source = result[key] as? [Any] {
                    result[key] = source.map { any -> Any in
                        if let string = any as? String {
                            return (path + string).string
                        } else {
                            return any
                        }
                    }
                } else if let source = result[key] as? [String: String] {
                    result[key] = source.mapValues { (path + $0).string }
                }
            case .dictionary(let pathProperties):
                for (key, dictionary) in result {
                    if let source = dictionary as? JSONDictionary {
                        result[key] = pathProperties.resolvingPaths(in: source, relativeTo: path)
                    }
                }
            case .object(let key, let pathProperties):
                if let source = result[key] as? JSONDictionary {
                    result[key] = pathProperties.resolvingPaths(in: source, relativeTo: path)
                } else if let source = result[key] as? [Any] {
                    result[key] = source.map { any -> Any in
                        if let dictionary = any as? JSONDictionary {
                            return pathProperties.resolvingPaths(in: dictionary, relativeTo: path)
                        } else {
                            return any
                        }
                    }
                } else if let source = result[key] as? [String: JSONDictionary] {
                    result[key] = source.mapValues { pathProperties.resolvingPaths(in: $0, relativeTo: path) }
                }
            }
        }

        return result
    }
}

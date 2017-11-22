import Foundation
import xcproj

public class ReferenceGenerator {

    private var references: Set<String> = []

    public init() {
    }

    public func generate<T: PBXObject>(_ element: T.Type, _ id: String) -> String {
        var uuid: String = ""
        var counter: UInt = 0
        let characterCount = 16
        let className: String = String(describing: T.self)
            .replacingOccurrences(of: "PBX", with: "")
            .replacingOccurrences(of: "XC", with: "")
        let classAcronym = String(className.filter { String($0).lowercased() != String($0) })
        let stringID = String(abs(id.hashValue).description.prefix(characterCount - classAcronym.count - 2))
        repeat {
            uuid = "\(classAcronym)_\(stringID)\(counter > 0 ? "-\(counter)" : "")"
            counter += 1
        } while (references.contains(uuid))
        references.insert(uuid)
        return uuid
    }

    public func clear() {
        references.removeAll()
    }
}

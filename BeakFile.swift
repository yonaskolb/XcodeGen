import Foundation
import PathKit
import SourceKittenFramework

public struct BeakFile: Equatable {

    public let contents: String
    public let dependencies: [Dependency]
    public let functions: [Function]

    public init(path: Path) throws {
        guard path.exists else {
            throw BeakError.fileNotFound(path.string)
        }
        let contents: String = try path.read()
        try self.init(contents: contents)
    }

    public var libraries: [String] {
        return dependencies.reduce([]) { $0 + $1.libraries }
    }

    public init(contents: String) throws {
        self.contents = contents
        functions = try SwiftParser.parseFunctions(file: contents)
        dependencies = contents
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.hasPrefix("// beak:") }
            .map { $0.replacingOccurrences(of: "// beak:", with: "") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(Dependency.init)
    }

    public init(contents: String, dependencies: [Dependency], functions: [Function]) {
        self.contents = contents
        self.dependencies = dependencies
        self.functions = functions
    }
}

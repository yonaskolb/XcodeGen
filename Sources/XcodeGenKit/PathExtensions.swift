import Foundation
import PathKit

extension Path {

    public func byRemovingBase(path: Path) -> Path {
        return Path(normalize().string.replacingOccurrences(of: "\(path.normalize().string)/", with: ""))
    }
    
    public func relativePath(from base: Path) throws -> Path {
        enum PathArgumentError: Error {
            /// Can't back out of an unknown parent directory
            case unknownParentDirectory
            /// It's impossible to determine the path between an absolute and a relative path
            case unmatchedAbsolutePath
        }
        
        func pathComponents(for path: ArraySlice<String>, relativeTo base: ArraySlice<String>, memo: [String]) throws -> [String] {
            switch (base.first, path.first) {
            // 1. Paths are equivalent
            case (.none, .none):
                return memo
                
            // 2. No path to backtrack from
            case (.none, .some(let rhs)):
                guard rhs != "." else {
                    // Skip . instead of appending it
                    return try pathComponents(for: path.dropFirst(), relativeTo: base, memo: memo)
                }
                return try pathComponents(for: path.dropFirst(), relativeTo: base, memo: memo + [rhs])
                
            // 3. Both sides have a common parent
            case (.some(let lhs), .some(let rhs)) where lhs == rhs:
                return try pathComponents(for: path.dropFirst(), relativeTo: base.dropFirst(), memo: memo)
                
            // 4. `base` has a path to back out of
            case (.some(let lhs), _):
                guard lhs != ".." else {
                    throw PathArgumentError.unknownParentDirectory
                }
                guard lhs != "." else {
                    // Skip . instead of resolving it to ..
                    return try pathComponents(for: path, relativeTo: base.dropFirst(), memo: memo)
                }
                return try pathComponents(for: path, relativeTo: base.dropFirst(), memo: memo + [".."])
            }
        }
        
        guard isAbsolute && base.isAbsolute || !isAbsolute && !base.isAbsolute else {
            throw PathArgumentError.unmatchedAbsolutePath
        }
        
        return Path(components: try pathComponents(for: ArraySlice(normalize().components.strippingParentDirectoryReferences()),
                                                   relativeTo: ArraySlice(base.normalize().components.strippingParentDirectoryReferences()),
                                                   memo: []))
    }
}

private extension Array where Element == String {
    func strippingParentDirectoryReferences() -> [Element] {
        var backtracks = 0
        let components = reversed().filter { pathComponent in
            if pathComponent == ".." {
                backtracks += 1
                return false
            } else if backtracks > 0 {
                backtracks -= 1
                return false
            } else {
                return true
            }
        }
        
        return Array(repeating: "..", count: backtracks) + components.reversed()
    }
}

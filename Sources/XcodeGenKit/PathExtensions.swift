import Foundation
import PathKit

extension Path {

    public func byRemovingBase(path: Path) -> Path {
        return Path(normalize().string.replacingOccurrences(of: "\(path.normalize().string)/", with: ""))
    }
    
    /// Returns the relative path necessary to go from `base` to `self`.
    ///
    /// Both paths must be absolute or relative paths.
    /// - throws: Throws an error when the path types do not match, or when `base` has so many parent path components
    ///           that it refers to an unknown parent directory.
    public func relativePath(from base: Path) throws -> Path {
        enum PathArgumentError: Error {
            /// Can't back out of an unknown parent directory
            case unknownParentDirectory
            /// It's impossible to determine the path between an absolute and a relative path
            case unmatchedAbsolutePath
        }
        
        func pathComponents(for path: ArraySlice<String>, relativeTo base: ArraySlice<String>, memo: [String]) throws -> [String] {
            switch (base.first, path.first) {
            // Base case: Paths are equivalent
            case (.none, .none):
                return memo
                
            // No path to backtrack from
            case (.none, .some(let rhs)):
                guard rhs != "." else {
                    // Skip . instead of appending it
                    return try pathComponents(for: path.dropFirst(), relativeTo: base, memo: memo)
                }
                return try pathComponents(for: path.dropFirst(), relativeTo: base, memo: memo + [rhs])
                
            // Both sides have a common parent
            case (.some(let lhs), .some(let rhs)) where lhs == rhs:
                return try pathComponents(for: path.dropFirst(), relativeTo: base.dropFirst(), memo: memo)
                
            // `base` has a path to back out of
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
    /// Removes inner `..`s from an array of path components.
    ///
    /// Foundation does this in `NSString.standardizingPath`, but only for absolute paths.
    func strippingParentDirectoryReferences() -> [Element] {
        var parents = 0
        let components = reversed().filter { pathComponent in
            if pathComponent == ".." {
                parents += 1
                return false
            } else if parents > 0 {
                parents -= 1
                return false
            } else {
                return true
            }
        }
        
        return Array(repeating: "..", count: parents) + components.reversed()
    }
}

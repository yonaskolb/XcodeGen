import Foundation
import PathKit

extension Path {
    /// Returns a Path without any inner parent directory references.
    ///
    /// Similar to `NSString.standardizingPath`, but works with relative paths.
    ///
    /// ### Examples
    /// - `a/b/../c` simplifies to `a/c`
    /// - `../a/b` simplifies to `../a/b`
    /// - `a/../../c` simplifies to `../c`
    public func simplifyingParentDirectoryReferences() -> Path {
        if !string.contains("..") { // Skip simplifying if its already simple
            var string = self.string
            while string.hasSuffix(Path.separator) { // Remove all trailing path separators
                string.removeLast()
            }
            return Path(String(string))
        }
        return normalize().components.reduce(Path(), +)
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
            case (.some(let lhs), .some(let rhs)) where memo.isEmpty && lhs == rhs:
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

        return Path(components: try pathComponents(for: ArraySlice(simplifyingParentDirectoryReferences().components),
                                                   relativeTo: ArraySlice(base.simplifyingParentDirectoryReferences().components),
                                                   memo: []))
    }

    /// Returns whether `self` is a strict parent of `child`.
    ///
    /// Both paths must be asbolute or relative paths.
    public func isParent(of child: Path) throws -> Bool {
        let relativePath = try child.relativePath(from: self)
        return relativePath.components.allSatisfy { $0 != ".." }
    }
}

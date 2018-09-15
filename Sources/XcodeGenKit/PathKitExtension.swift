import Foundation
import PathKit

extension Path {

    /// Treat this as a resource instead of a normal directory.
    var isNonFolderDirectory: Bool {

        if isFile {
            return false
        }

        if let uti = try! URL(fileURLWithPath: self.string)
            .resourceValues(forKeys: [URLResourceKey.typeIdentifierKey])
            .typeIdentifier {
            // NOTE: lproj is public.folder
            return uti != "public.folder"
        }

        return false
    }

}

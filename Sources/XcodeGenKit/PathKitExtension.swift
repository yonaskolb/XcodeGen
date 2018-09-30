import Foundation
import PathKit

extension Path {

    /// Treat this as a file (resource or source) instead of a normal directory.
    var isFileDirectory: Bool {

        if isFile || self.extension == nil {
            return false
        }

        if let uti = try! URL(fileURLWithPath: self.string)
            .resourceValues(forKeys: [URLResourceKey.typeIdentifierKey])
            .typeIdentifier {

            // If uti is `public.folder` or `dyn*`, it's a normal directory in most cases.
            // But for example *.lproj appears to be a `public.folder`.
            // So make sure to filter to treat it as a special directory.
            return uti != "public.folder" && !uti.starts(with: "dyn")

        }

        return false
    }

}

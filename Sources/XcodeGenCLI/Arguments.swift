import Foundation
import PathKit
import SwiftCLI

extension Path: ConvertibleFromString {

    public static func convert(from: String) -> Path? {
        return Path(from)
    }
}

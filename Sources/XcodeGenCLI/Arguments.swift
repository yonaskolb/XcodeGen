import Foundation
import PathKit
import SwiftCLI

extension Path: SwiftCLI.ConvertibleFromString {

    public init?(input: String) {
        self.init(input)
    }
}

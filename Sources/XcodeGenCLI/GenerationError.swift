import Foundation
import PathKit
import ProjectSpec
import Rainbow
import SwiftCLI

enum GenerationError: Error, CustomStringConvertible, ProcessError {
    case missingProjectSpec(Path)
    case projectSpecParsingError(Error)
    case cacheGenerationError(Error)
    case validationError(SpecValidationError)
    case generationError(Error)
    case writingError(Error)

    var description: String {
        switch self {
        case let .missingProjectSpec(path):
            return "No project spec found at \(path.absolute())"
        case let .projectSpecParsingError(error):
            return "Parsing project spec failed: \(error)"
        case let .cacheGenerationError(error):
            return "Couldn't generate cache file: \(error)"
        case let .validationError(error):
            return error.description
        case let .generationError(error):
            return String(describing: error)
        case let .writingError(error):
            return String(describing: error)
        }
    }

    var message: String? {
        description.red
    }

    var exitStatus: Int32 {
        1
    }
}

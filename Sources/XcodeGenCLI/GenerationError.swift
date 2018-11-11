import PathKit
import Foundation
import ProjectSpec
import SwiftCLI
import Rainbow

enum GenerationError: Error, CustomStringConvertible, ProcessError {
    case missingProjectSpec(Path)
    case projectSpecParsingError(Error)
    case validationError(SpecValidationError)
    case generationError(Error)
    case writingError(Error)

    var description: String {
        switch self {
        case .missingProjectSpec(let path):
            return "No project spec found at \(path.absolute())"
        case .projectSpecParsingError(let error):
            return "Parsing project spec failed: \(error)"
        case .validationError(let error):
            return error.description
        case .generationError(let error):
            return String(describing: error)
        case .writingError(let error):
            return String(describing: error)
        }
    }

    var message: String? {
        return description.red
    }

    var exitStatus: Int32 {
        return 1
    }
}

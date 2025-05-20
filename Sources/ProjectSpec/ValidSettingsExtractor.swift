import Foundation
import JSONUtilities

struct ValidSettingsExtractor {
    let jsonDictionary: JSONDictionary

    func extract() throws -> Settings {
        do {
            return try jsonDictionary.json(atKeyPath: "settings")
        } catch let specParsingError as SpecParsingError {
            // Re-throw `SpecParsingError` to prevent the misuse of settings.configs.
            throw specParsingError
        } catch {
            // Ignore all errors except `SpecParsingError`
            return .empty
        }
    }
}

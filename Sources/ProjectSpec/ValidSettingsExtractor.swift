import Foundation
import JSONUtilities

/// A helper for extracting and validating the `Settings` object from a JSON dictionary.
struct ValidSettingsExtractor {
    let jsonDictionary: JSONDictionary

    /// Attempts to extract and parse the `Settings` from the dictionary.
    ///
    /// - Returns: A valid `Settings` object
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

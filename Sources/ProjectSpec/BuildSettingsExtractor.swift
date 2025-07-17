import Foundation
import JSONUtilities

/// A helper for extracting and validating the `Settings` object from a JSON dictionary.
struct BuildSettingsParser {
    let jsonDictionary: JSONDictionary

    /// Attempts to extract and parse the `Settings` from the dictionary.
    ///
    /// - Returns: A valid `Settings` object
    func parse() throws -> Settings {
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

    /// Attempts to extract and parse setting groups from the dictionary with fallback defaults.
    ///
    /// - Returns: Parsed setting groups or default groups if parsing fails
    func parseSettingGroups() throws -> [String: Settings] {
        do {
            return try jsonDictionary.json(atKeyPath: "settingGroups", invalidItemBehaviour: .fail)
        } catch let specParsingError as SpecParsingError {
            // Re-throw `SpecParsingError` to prevent the misuse of settingGroups.
            throw specParsingError
        } catch {
            // Ignore all errors except `SpecParsingError`
            return jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        }
    }
}

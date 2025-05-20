import ProjectSpec
import Testing
import TestSupport
import PathKit

struct invalidConfigsMappingFormatTests {
    @Test("throws invalidConfigsMappingFormat error for non-dictionary configs entries")
    func testNonDictionaryConfigsEntries() throws {
        let path = fixturePath + "invalid_configs_value_non_dict.yml"
        let expectedError = SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])

        #expect(throws: EquatableErrorBox(expectedError)) {
            try perform(path: path)
        }
    }

    private func perform(path: Path) throws {
        do {
            _ = try Project(path: path)
        } catch let error as SpecParsingError {
            throw EquatableErrorBox(error)
        } catch {
            throw error
        }
    }

    // SpecParsingError does not conform to Equatable, so we wrap its description here
    private struct EquatableErrorBox: Error, Equatable {
        let description: String

        init<E: Error & CustomStringConvertible>(_ error: E) {
            self.description = error.description
        }
    }
}

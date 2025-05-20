import ProjectSpec
import Testing
import TestSupport
import PathKit

struct invalidConfigsMappingFormatTests {
    @Test("throws invalidConfigsMappingFormat error for non-dictionary configs entries")
    func testNonDictionaryConfigsEntries() throws {
        let path = fixturePath + "invalid_configs_value_non_mapping.yml"
        let expectedError = SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])

        #expect {
            try Project(path: path)
        } throws: { actualError in
            (actualError as any CustomStringConvertible).description == expectedError.description
        }
    }
}

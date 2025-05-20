import ProjectSpec
import Testing
import TestSupport
import PathKit

struct invalidConfigsMappingFormatTests {
    let invalidConfigsFixturePath: Path = fixturePath + "invalid_configs"

    @Test("throws invalidConfigsMappingFormat for non-mapping settings.configs entries at root level")
    func testNonMappingSettingsConfigsEntries() throws {
        let path = invalidConfigsFixturePath + "invalid_configs_value_non_mapping_settings.yml"
        let expectedError = SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])

        #expect {
            try Project(path: path)
        } throws: { actualError in
            (actualError as any CustomStringConvertible).description == expectedError.description
        }
    }

    @Test("throws invalidConfigsMappingFormat for non-mapping settings.configs entries in a target")
    func testNonMappingTargetsConfigsEntries() throws {
        let path = invalidConfigsFixturePath + "invalid_configs_value_non_mapping_targets.yml"
        let expectedError = SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])

        #expect {
            try Project(path: path)
        } throws: { actualError in
            (actualError as any CustomStringConvertible).description == expectedError.description
        }
    }

    @Test("throws invalidConfigsMappingFormat for non-mapping settings.configs entries in an aggregate target")
    func testNonMappingAggregateTargetsConfigsEntries() throws {
        let path = invalidConfigsFixturePath + "invalid_configs_value_non_mapping_aggregate_targets.yml"
        let expectedError = SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])

        #expect {
            try Project(path: path)
        } throws: { actualError in
            (actualError as any CustomStringConvertible).description == expectedError.description
        }
    }
}

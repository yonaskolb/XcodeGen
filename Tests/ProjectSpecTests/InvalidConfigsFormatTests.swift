import ProjectSpec
import Testing
import TestSupport
import PathKit

struct invalidConfigsMappingFormatTests {
    struct InvalidConfigsTestArguments {
        var fixturePath: Path
        var expectedError: SpecParsingError
    }

    private static var testArguments: [InvalidConfigsTestArguments] {
        let invalidConfigsFixturePath: Path = fixturePath + "invalid_configs"
        return [
            InvalidConfigsTestArguments(
                fixturePath: invalidConfigsFixturePath + "invalid_configs_value_non_mapping_settings.yml",
                expectedError: SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])
            ),
            InvalidConfigsTestArguments(
                fixturePath: invalidConfigsFixturePath + "invalid_configs_value_non_mapping_targets.yml",
                expectedError: SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])
            ),
            InvalidConfigsTestArguments(
                fixturePath: invalidConfigsFixturePath + "invalid_configs_value_non_mapping_aggregate_targets.yml",
                expectedError: SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])
            ),
            InvalidConfigsTestArguments(
                fixturePath: invalidConfigsFixturePath + "invalid_configs_value_non_mapping_setting_groups.yml",
                expectedError: SpecParsingError.invalidConfigsMappingFormat(keys: ["invalid_key0", "invalid_key1"])
            )
        ]
    }

    @Test("throws invalidConfigsMappingFormat for non-mapping configs entries", arguments: testArguments)
    func testInvalidConfigsMappingFormat(_ arguments: InvalidConfigsTestArguments) throws {
        #expect {
            try Project(path: arguments.fixturePath)
        } throws: { actualError in
            (actualError as any CustomStringConvertible).description
            == arguments.expectedError.description
        }
    }
}

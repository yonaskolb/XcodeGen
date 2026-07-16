import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import Version

class ValidateCommand: ProjectCommand {

    init(version: Version) {
        super.init(version: version,
                   name: "validate",
                   shortDescription: "Validate the project spec without generating a project")
    }

    // Fully override execute() so that parsing errors are also captured as JSON
    override func execute() throws {
        var specPaths: [Path] = []
        if let spec = spec {
            specPaths = spec.components(separatedBy: ",").map { Path($0).absolute() }
        } else {
            specPaths = [Path("project.yml").absolute()]
        }

        var allErrors: [ValidationIssue] = []
        var allWarnings: [ValidationIssue] = []

        for specPath in specPaths {
            guard specPath.exists else {
                allErrors.append(ValidationIssue(stage: "parsing",
                                                 message: "No project spec found at \(specPath)"))
                continue
            }

            let specLoader = SpecLoader(version: version)
            let variables: [String: String] = disableEnvExpansion ? [:] : ProcessInfo.processInfo.environment

            let project: Project
            do {
                project = try specLoader.loadProject(path: specPath, projectRoot: projectRoot, variables: variables)
            } catch {
                allErrors.append(ValidationIssue(stage: "parsing", message: error.localizedDescription))
                continue
            }

            do {
                try specLoader.validateProjectDictionaryWarnings()
            } catch let e as SpecValidationError {
                allWarnings += e.errors.map { ValidationIssue(stage: "validation", message: $0.description) }
            } catch {
                allWarnings.append(ValidationIssue(stage: "validation", message: error.localizedDescription))
            }

            do {
                try project.validateMinimumXcodeGenVersion(version)
                try project.validate()
            } catch let e as SpecValidationError {
                allErrors += e.errors.map { ValidationIssue(stage: "validation", message: $0.description) }
            } catch {
                allErrors.append(ValidationIssue(stage: "validation", message: error.localizedDescription))
            }
        }

        let result = ValidationResult(valid: allErrors.isEmpty, errors: allErrors, warnings: allWarnings)
        stdout.print(try result.jsonString())

        if !result.valid {
            throw ValidationFailed()
        }
    }

    // Not called — execute() is fully overridden above
    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}
}

// MARK: - JSON output types

private struct ValidationIssue: Encodable {
    let stage: String
    let message: String
}

private struct ValidationResult: Encodable {
    let valid: Bool
    let errors: [ValidationIssue]
    let warnings: [ValidationIssue]

    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

private struct ValidationFailed: ProcessError {
    var message: String? { nil }
    var exitStatus: Int32 { 1 }
}

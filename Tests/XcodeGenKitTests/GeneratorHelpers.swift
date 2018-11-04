import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcodeproj
import XCTest
import Yams

extension Project {

    func generateXcodeProject(file: String = #file, line: Int = #line) throws -> XcodeProj {
        return try doThrowing(file: file, line: line) {
            try validate()
            let generator = ProjectGenerator(project: self)
            return try generator.generateXcodeProject()
        }
    }

    func generatePbxProj(file: String = #file, line: Int = #line) throws -> PBXProj {
        return try doThrowing(file: file, line: line) {
            let xcodeProject = try generateXcodeProject().pbxproj
            try xcodeProject.validate()
            return xcodeProject
        }
    }
}

extension PBXProj {

    // validates that a PBXProj is correct
    // TODO: Use xclint?
    func validate() throws {
        let mainGroup = try getMainGroup()

        func validateGroup(_ group: PBXGroup) throws {

            // check for duplicte children
            let dictionary = Dictionary(grouping: group.children) { $0.hashValue }
            let mostChildren = dictionary.sorted { $0.value.count > $1.value.count }
            if let first = mostChildren.first, first.value.count > 1 {
                throw failure("Group \"\(group.nameOrPath)\" has duplicated children:\n - \(group.children.map { $0.nameOrPath }.joined(separator: "\n - "))")
            }
            for child in group.children {
                if let group = child as? PBXGroup {
                    try validateGroup(group)
                }
            }
        }
        try validateGroup(mainGroup)
    }
}

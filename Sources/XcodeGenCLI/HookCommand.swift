import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj

enum GitHook {
    static let postCheckout = ".git/hooks/post-checkout"
}

class HookCommand: CommandBase {

    override var name: String {
        return "add-hook"
    }
    var shortDescription: String = "Create a post-checkout hook which triggers XcodeGen after checkout branch"

    override func execute() throws {
        // write post-checkout hook
        let projectSpecPath = try getProjectPath()

        let project: Project = try getProject(from: projectSpecPath)
        let fileWriter = FileWriter(project: project)

        let hookPath = project.basePath + GitHook.postCheckout

        info("⚙️  Writing post-checkout hook...")
        do {
            try fileWriter.writeHook(at: hookPath)
            success("Added post-checkout hook at \(hookPath)")
        } catch {
            throw GenerationError.writingError(error)
        }
    }
}

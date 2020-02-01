import Foundation
import ProjectSpec
import XcodeGenCLI

let version = Version("2.12.0")
let cli = XcodeGenCLI(version: version)
cli.execute()

import Foundation
import ProjectSpec
import XcodeGenCLI

let version = Version("2.6.0")
let cli = XcodeGenCLI(version: version)
cli.execute()

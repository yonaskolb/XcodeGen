import Foundation
import ProjectSpec
import XcodeGenCLI
import Version

let version = Version("2.22.0")
let cli = XcodeGenCLI(version: version)
cli.execute()

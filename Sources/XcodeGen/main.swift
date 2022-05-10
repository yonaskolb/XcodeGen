import Foundation
import ProjectSpec
import XcodeGenCLI
import Version

let version = Version("2.29.0")
let cli = XcodeGenCLI(version: version)
cli.execute()

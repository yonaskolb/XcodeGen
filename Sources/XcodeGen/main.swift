import Foundation
import ProjectSpec
import XcodeGenCLI
import Version

let version = Version("2.44.1")
let cli = XcodeGenCLI(version: version)
cli.execute()

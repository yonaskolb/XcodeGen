import Foundation
import ProjectSpec
import XcodeGenCLI

let version = try Version("2.2.0")
let cli = XcodeGenCLI(version: version)
cli.execute()

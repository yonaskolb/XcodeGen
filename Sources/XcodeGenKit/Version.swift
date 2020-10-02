import Foundation
import ProjectSpec

extension Project {

    var xcodeVersion: String {
        XCodeVersion.parse(options.xcodeVersion ?? "12.0")
    }

    var schemeVersion: String {
        "1.3"
    }

    var compatibilityVersion: String {
        "Xcode 10.0"
    }

    var objectVersion: UInt {
        51
    }
}

public struct XCodeVersion {

    public static func parse(_ version: String) -> String {
        if version.contains(".") {
            let parts = version.split(separator: ".").map(String.init)
            var string = ""
            let major = parts[0]
            if major.count == 1 {
                string = "0\(major)"
            } else {
                string = major
            }

            let minor = parts[1]
            string += minor

            if parts.count > 2 {
                let patch = parts[2]
                string += patch
            } else {
                string += "0"
            }
            return string
        } else if version.count == 2 {
            return "\(version)00"
        } else if version.count == 1 {
            return "0\(version)00"
        } else {
            return version
        }
    }
}

import Foundation
import ProjectSpec

extension Project {

    public var xcodeVersion: String {
        XCodeVersion.parse(options.xcodeVersion ?? "14.3")
    }

    /// Whether static frameworks should be embedded into their consumers by default.
    ///
    /// Xcode 15 changed the build system to strip the static binary out of a static framework
    /// bundle when it's embedded, so embedding no longer duplicates the statically-linked code.
    /// Xcode 14 and earlier copy the whole static archive, duplicating code and risking App Store
    /// validation failures. A project that explicitly targets Xcode 14 or earlier via
    /// `options.xcodeVersion` therefore keeps the previous link-only behavior; when no `xcodeVersion`
    /// is set the modern (embedding) behavior applies.
    public var supportsStaticFrameworkEmbedding: Bool {
        guard let xcodeVersion = options.xcodeVersion else {
            return true
        }
        return XCodeVersion.parse(xcodeVersion) >= "1500"
    }

    public var projectFormat: ProjectFormat {
        options.projectFormat.flatMap(ProjectFormat.init) ?? .default
    }

    var schemeVersion: String {
        "1.7"
    }

    var compatibilityVersion: String? {
        projectFormat.compatibilityVersion
    }

    var objectVersion: UInt {
        projectFormat.objectVersion
    }

    var preferredProjectObjectVersion: UInt? {
        projectFormat.preferredProjectObjectVersion
    }

    var minimizedProjectReferenceProxies: Int {
        1
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

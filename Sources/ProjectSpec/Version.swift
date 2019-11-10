import Foundation

public struct Version: CustomStringConvertible, Equatable, Comparable, ExpressibleByStringLiteral {

    public var major: UInt
    public var minor: UInt
    public var patch: UInt

    public init(stringLiteral value: String) {
        try! self.init(value)
    }

    public init(_ string: String) throws {
        let components = try string.split(separator: ".").map { (componentString) -> UInt in
            guard let uint = UInt(componentString) else {
                throw SpecParsingError.invalidVersion(string)
            }
            return uint
        }

        guard components.count <= 3 else {
            throw SpecParsingError.invalidVersion(string)
        }

        major = components[0]
        minor = (components.count >= 2) ? components[1] : 0
        patch = (components.count == 3) ? components[2] : 0
    }

    public init(_ double: Double) throws {
        try self.init(String(double))
    }

    public init(major: UInt, minor: UInt? = 0, patch: UInt? = 0) {
        self.major = major
        self.minor = minor ?? 0
        self.patch = patch ?? 0
    }

    public var string: String {
        "\(major).\(minor).\(patch)"
    }

    public var description: String {
        string
    }

    public func bumpingMajor() -> Version {
        Version(major: major + 1, minor: 0, patch: 0)
    }

    public func bumpingMinor() -> Version {
        Version(major: major, minor: minor + 1, patch: 0)
    }

    public func bumpingPatch() -> Version {
        Version(major: major, minor: minor, patch: patch + 1)
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        guard lhs.major == rhs.major else { return lhs.major < rhs.major }
        guard lhs.minor == rhs.minor else { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

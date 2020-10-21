import Spectre
import PathKit
import XCTest
import Core
import TestSupport

class PathExtensionsTests: XCTestCase {

    func testPathRelativeToPath() {
        func relativePath(to path: String, from base: String) throws -> String {
            try Path(path).relativePath(from: Path(base)).string
        }

        // These are based on ruby's tests for Pathname#relative_path_from:
        // https://github.com/ruby/ruby/blob/7c2bbd1c7d40a30583844d649045824161772e36/test/pathname/test_pathname.rb#L297
        describe {
            $0.it("resolves single-level paths") {
                try expect(relativePath(to: "a", from: "b")) == "../a"
                try expect(relativePath(to: "a", from: "b/")) == "../a"
                try expect(relativePath(to: "a/", from: "b")) == "../a"
                try expect(relativePath(to: "a/", from: "b/")) == "../a"
                try expect(relativePath(to: "/a", from: "/b")) == "../a"
                try expect(relativePath(to: "/a", from: "/b/")) == "../a"
                try expect(relativePath(to: "/a/", from: "/b")) == "../a"
                try expect(relativePath(to: "/a/", from: "/b/")) == "../a"
            }

            $0.it("resolves paths with a common parent") {
                try expect(relativePath(to: "a/b", from: "a/c")) == "../b"
                try expect(relativePath(to: "../a", from: "../b")) == "../a"
            }

            $0.it("resolves dot paths") {
                try expect(relativePath(to: "a", from: ".")) == "a"
                try expect(relativePath(to: ".", from: "a")) == ".."
                try expect(relativePath(to: ".", from: ".")) == "."
                try expect(relativePath(to: "..", from: "..")) == "."
                try expect(relativePath(to: "..", from: ".")) == ".."
            }

            $0.it("resolves multi-level paths") {
                try expect(relativePath(to: "/a/b/c/d", from: "/a/b")) == "c/d"
                try expect(relativePath(to: "/a/b", from: "/a/b/c/d")) == "../.."
                try expect(relativePath(to: "/e", from: "/a/b/c/d")) == "../../../../e"
                try expect(relativePath(to: "a/b/c", from: "a/d")) == "../b/c"
                try expect(relativePath(to: "/../a", from: "/b")) == "../a"
                try expect(relativePath(to: "../a", from: "b")) == "../../a"
                try expect(relativePath(to: "/a/../../b", from: "/b")) == "."
                try expect(relativePath(to: "a/..", from: "a")) == ".."
                try expect(relativePath(to: "a/../b", from: "b")) == "."
                try expect(relativePath(to: "/a/c", from: "/a/b/c")) == "../../c"
            }

            $0.it("backtracks on a non-normalized base path") {
                try expect(relativePath(to: "a", from: "b/..")) == "a"
                try expect(relativePath(to: "b/c", from: "b/..")) == "b/c"
            }

            $0.it("throws when given unresolvable paths") {
                try expect(relativePath(to: "/", from: ".")).toThrow()
                try expect(relativePath(to: ".", from: "/")).toThrow()
                try expect(relativePath(to: "a", from: "..")).toThrow()
                try expect(relativePath(to: ".", from: "..")).toThrow()
                try expect(relativePath(to: "a", from: "b/../..")).toThrow()
            }
        }
    }
}

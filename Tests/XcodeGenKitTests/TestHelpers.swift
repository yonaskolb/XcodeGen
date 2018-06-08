import Foundation
import PathKit
import ProjectSpec
import Spectre
import xcproj

let fixturePath = Path(#file).parent().parent() + "Fixtures"

func doThrowing<T>(file: String = #file, line: Int = #line, _ closure: () throws -> T) throws -> T {
    do {
        return try closure()
    } catch {
        throw failure(String(describing: error), file: file, line: line)
    }
}

func expectError<T: Error>(_ expectedError: T, function: String = #function, file: String = #file, line: Int = #line, _ closure: () throws -> Void) throws where T: CustomStringConvertible {
    do {
        try closure()
    } catch let error as T {
        try expect(error.description, file: file, line: line, function: function) == expectedError.description
        return
    } catch {
        throw failure("Supposed to fail with \"\(expectedError)\"", function: function, file: file, line: line)
    }
    throw failure("Supposed to fail with \"\(expectedError)\"", function: function, file: file, line: line)
}

struct ExpectationFailure: FailureType {
    let file: String
    let line: Int
    let function: String

    let reason: String

    init(reason: String, file: String, line: Int, function: String) {
        self.reason = reason
        self.file = file
        self.line = line
        self.function = function
    }
}

open class ArrayExpectation<T>: ExpectationType {
    public typealias ValueType = Array<T>
    public let expression: () throws -> ValueType?

    let file: String
    let line: Int
    let function: String

    open var to: ArrayExpectation<T> {
        return self
    }

    init(file: String, line: Int, function: String, expression: @escaping () throws -> ValueType?) {
        self.file = file
        self.line = line
        self.function = function
        self.expression = expression
    }

    open func failure(_ reason: String) -> FailureType {
        return ExpectationFailure(reason: reason, file: file, line: line, function: function)
    }
}

public func expect<T>(_ expression: @autoclosure @escaping () throws -> [T]?, file: String = #file, line: Int = #line, function: String = #function) -> ArrayExpectation<T> {
    return ArrayExpectation(file: file, line: line, function: function, expression: expression)
}

extension ArrayExpectation {

    public func contains(_ predicate: (T) throws -> Bool) throws {
        let value = try expression()
        if let value = value {
            if try !value.contains(where: predicate) {
                throw failure("value does not contain item: \(value)")
            }
        }
    }
}

extension ArrayExpectation where T: Named {

    public func contains(name: String) throws {
        let value = try expression()
        if let value = value {
            if !value.contains(where: { $0.name == name }) {
                throw failure("Array does not contain item with name \(name)")
            }
        }
    }
}

public protocol Named {
    var name: String { get }
}

extension XCBuildConfiguration: Named {}
extension PBXNativeTarget: Named {}
extension XCScheme: Named {}

extension Version: ExpressibleByStringLiteral {

    /// Will return nil literal not Semver
    public init(stringLiteral value: String) {
        try! self.init(value)
    }
}

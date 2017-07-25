import Foundation
import Spectre

func expectError<T: Error>(_ expectedError: T, closure: () throws -> ()) throws where T: CustomStringConvertible {
    do {
        try closure()
    } catch let error as T {
        try expect(error.description) == expectedError.description
        return
    } catch {
        throw failure("Supposed to fail with \"\(expectedError)\"")
    }
    throw failure("Supposed to fail with \"\(expectedError)\"")
}

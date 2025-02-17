//
//  CarthageVersionLoader.swift
//  XcodeGenKit
//
//  Created by Yonas Kolb on 24/3/19.
//

import Foundation
import PathKit
import ProjectSpec

class Mutex<T> {
    var value: T
    var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)

    init(_ value: T) {
        self.value = value
    }

    func get<U>(closure: (inout T) throws -> (U)) rethrows -> U {
        semaphore.wait()
        defer { semaphore.signal() }
        return try closure(&value)
    }

    func get(closure: (inout T) -> Void) {
        semaphore.wait()
        closure(&value)
        semaphore.signal()
    }
}

// Note: this class can be accessed on multiple threads. It must therefore stay thread-safe.
class CarthageVersionLoader {

    private let buildPath: Path
    private var cachedFilesMutex: Mutex<[String: CarthageVersionFile]> = Mutex([:])

    init(buildPath: Path) {
        self.buildPath = buildPath
    }

    func getVersionFile(for dependency: String) throws -> CarthageVersionFile {
        return try cachedFilesMutex.get { cachedFiles in
            if let versionFile = cachedFiles[dependency] {
                return versionFile
            }
            let filePath = buildPath + ".\(dependency).version"
            let data = try filePath.read()
            let carthageVersionFile = try JSONDecoder().decode(CarthageVersionFile.self, from: data)
            cachedFiles[dependency] = carthageVersionFile
            return carthageVersionFile
        }
    }
}

struct CarthageVersionFile: Decodable {

    private struct Reference: Decodable, Equatable {
        public let name: String
        public let hash: String
    }

    private let data: [Platform: [String]]

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Platform.self)
        data = try Platform.allCases.reduce(into: [:]) { data, platform in
            let references = try container.decodeIfPresent([Reference].self, forKey: platform) ?? []
            let frameworks = Set(references.map { $0.name }).sorted()
            data[platform] = frameworks
        }
    }
}

extension Platform: Swift.CodingKey {

    public var stringValue: String {
        carthageName
    }
}

extension CarthageVersionFile {
    func frameworks(for platform: Platform) -> [String] {
        data[platform] ?? []
    }
}

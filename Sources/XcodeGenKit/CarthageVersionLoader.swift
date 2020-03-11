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
    //var mutex: pthread_mutex_t = pthread_mutex_t()
    var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    init(_ value: T) {
        self.value = value
        //pthread_mutex_init(&mutex, nil)
    }

    func get<U>(closure: (inout T) throws -> (U)) rethrows -> U {
        semaphore.wait()
        defer { semaphore.signal() }
        //pthread_mutex_lock(&mutex)
        //defer { pthread_mutex_unlock(&mutex) }
        let newValue = try closure(&value)
        //value = newValue
        return newValue
    }

    func get(closure: (inout T) -> ()) {
        semaphore.wait()
        closure(&value)
        semaphore.signal()
    }
}

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

extension Platform: CodingKey {

    public var stringValue: String {
        carthageName
    }
}

extension CarthageVersionFile {
    func frameworks(for platform: Platform) -> [String] {
        data[platform] ?? []
    }
}

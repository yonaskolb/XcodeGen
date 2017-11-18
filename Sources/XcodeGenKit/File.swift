//
//  File.swift
//  XcodeGenKit
//
//  Created by ryohey on 2017/11/18.
//

import Foundation
import PathKit

internal struct FilePath {
    var string: String
    var basename: String { return NSString(string: string).lastPathComponent }
    var `extension`: String { return NSString(string: basename).pathExtension }
    var basenameWithoutExtension: String { return NSString(string: basename).deletingPathExtension }
}

internal indirect enum File {
    case directory(FilePath, [File]) // path, children
    case file(FilePath) // path

    var isDirectory: Bool {
        switch self {
        case .directory(_, _): return true
        case .file(_): return false
        }
    }

    var isFile: Bool {
        switch self {
        case .directory(_, _): return false
        case .file(_): return true
        }
    }

    var path: FilePath {
        switch self {
        case .directory(let path, _): return path
        case .file(let path): return path
        }
    }
}

internal extension Path {
    func getFileTree() throws -> File {
        if isFile {
            return .file(FilePath(string: string))
        }
        return .directory(FilePath(string: string), try children().map { try $0.getFileTree() })
    }
}

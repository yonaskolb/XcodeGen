//
//  Platform.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 21/7/17.
//
//

import Foundation

public enum Platform: String {
    case iOS
    case watchOS
    case tvOS
    case macOS
    public var carthageDirectoryName: String {
        switch self {
        case .macOS:
            return "Mac"
        default:
            return rawValue
        }
    }
}

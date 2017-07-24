//
//  File.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/7/17.
//
//

import Foundation

enum SpecError: Error {
    case unknownTargetType(String)
    case invalidDependency([String: Any])
}

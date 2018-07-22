//
//  ProjectTarget.swift
//  ProjectSpec
//
//  Created by Yonas Kolb on 22/7/18.
//

import Foundation

protocol ProjectTarget {

    var name: String { get }
    var settings: Settings { get }
    var buildScripts: [BuildScript] { get }
    var configFiles: [String: String] { get }
    var scheme: TargetScheme? { get }
}

extension Target {

    var buildScripts: [BuildScript] {
        return prebuildScripts + postbuildScripts
    }
}

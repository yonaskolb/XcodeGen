//
//  ReferenceGenerator.swift
//  XcodeGenKit
//
//  Created by Yonas Kolb on 11/11/17.
//

import Foundation
import xcproj

public class ReferenceGenerator {

    private var references: Set<String> = []

    public init() {
        
    }

    public func generate<T: PBXObject>(_ element: T.Type, _ id: String) -> String {
        var uuid: String = ""
        var counter: UInt = 0
        let className: String = String(describing: T.self)
            .replacingOccurrences(of: "PBX", with: "")
            .replacingOccurrences(of: "XC", with: "")
        let classAcronym = String(className.filter { String($0).lowercased() != String($0) })
        let stringID = String(abs(id.hashValue).description.prefix(10 - classAcronym.count))
        repeat {
            counter += 1
            uuid = "\(classAcronym)\(stringID)\(String(format: "%02d", counter))"
        } while (references.contains(uuid))
        references.insert(uuid)
        return uuid
    }

    public func clear() {
        references.removeAll()
    }
}

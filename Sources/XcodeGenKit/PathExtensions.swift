//
//  PathExtensions.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 24/7/17.
//
//

import Foundation
import PathKit

extension Path {

    func byRemovingBase(path: Path) -> Path {
        return Path(normalize().string.replacingOccurrences(of: "\(path.normalize().string)/", with: ""))
    }
}

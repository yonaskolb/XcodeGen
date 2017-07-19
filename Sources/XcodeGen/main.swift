//
//  main.swift
//  SwiftySwagger
//
//  Created by Yonas Kolb on 17/09/2016.
//  Copyright © 2016 Yonas Kolb. All rights reserved.
//

import Foundation
import PathKit
import Commander
import XcodeGenKit

func generate(spec: String) {
    let specPath = Path("~/Developer/XcodeGen/test_spec.yml").normalize()

    let spec: Spec
    do {
        spec = try Spec(path: specPath)
        print(spec)
        print("")

    } catch {
        print("Parsing spec failed: \(error)")
        return
    }

    do {
        try Generator.generate(spec: spec, path: Path("~/Developer/XcodeGen/test_project.xcodeproj").normalize())
        print("Generated Xcode Project")
    } catch {
        print("Generation failed: \(error)")
    }
}


command(
    Option<String>("spec", "", flag: "p", description: "The path to the spec file"),
    generate)
    .run()

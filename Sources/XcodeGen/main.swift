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
import xcodeproj
import ProjectSpec
import JSONUtilities
import Rainbow

func generate(spec: String, project: String) {

    let specPath = Path(spec).normalize()
    let projectPath = Path(project).normalize()

    let spec: ProjectSpec
    do {
        spec = try SpecLoader.loadSpec(path: specPath)
        print("📋  Loaded spec:\n  \(spec.debugDescription.replacingOccurrences(of: "\n", with: "\n  "))")
    } catch let error as JSONUtilities.DecodingError {
        print("Parsing spec failed: \(error.description)".red)
        exit(1)
    } catch {
        print("💾  Parsing spec failed: \(error.localizedDescription)".red)
        exit(1)
    }

    do {
        let projectGenerator = ProjectGenerator(spec: spec, path: specPath.parent())
        let project = try projectGenerator.generateProject()
        print("⚙️  Generated project")

        let projectFile = projectPath + "\(spec.name).xcodeproj"
        try project.write(path: projectFile, override: true)
        print("💾  Saved project to \(projectFile.string)".green)
    } catch let error as SpecValidationError {
        print(error.description.red)
    } catch {
        print("Generation failed: \(error.localizedDescription)".red)
        exit(1)
    }
}

command(
    Option<String>("spec", "project.yml", flag: "s", description: "The path to the spec file"),
    Option<String>("project", "", flag: "p", description: "The path to the folder where the project should be generated"),
    generate)
    .run()

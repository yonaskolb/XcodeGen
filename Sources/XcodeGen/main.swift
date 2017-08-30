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

func generate(spec: String, project: String) {

    let specPath = Path(spec).normalize()
    let projectPath = Path(project).normalize()

    let spec: ProjectSpec
    do {
        spec = try SpecLoader.loadSpec(path: specPath)
        print("Loaded spec: \(spec.targets.count) targets, \(spec.schemes.count) schemes, \(spec.configs.count) configs")
    } catch let error as DecodingError {
        print("Parsing spec failed: \(error.description)")
        return
    } catch {
        print("Parsing spec failed: \(error.localizedDescription)")
        return
    }

    do {
        let projectGenerator = ProjectGenerator(spec: spec, path: specPath.parent())
        let project = try projectGenerator.generateProject()
        print("Generated project")
        print("Writing project")

        let projectFile = projectPath + "\(spec.name).xcodeproj"
        try project.write(path: projectFile, override: true)
        print("Wrote project to file \(projectFile.string)")
    } catch let error as SpecValidationError {
        print(error.description)
    } catch {
        print("Project Generation failed: \(error.localizedDescription)")
    }
}

command(
    Option<String>("spec", "project.yml", flag: "s", description: "The path to the spec file"),
    Option<String>("project", "", flag: "p", description: "The path to the folder where the project should be generated"),
    generate)
    .run()

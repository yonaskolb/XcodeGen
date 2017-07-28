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

func generate(spec: String, project: String?) {

    let specPath = spec.isEmpty ? Path("xcodegen.yml") : Path(spec).normalize()
    var projectPath: Path
    if let project = project, !project.isEmpty {
        var path = Path(project).normalize()
        if path.isRelative {
            path = specPath.parent() + project
        }
        projectPath = path
    } else {
        projectPath = specPath.parent()
    }

    let spec: ProjectSpec
    do {
        spec = try ProjectSpec(path: specPath)
        print("Loaded spec: \(spec.targets.count) targets, \(spec.schemes.count) schemes, \(spec.configs.count) configs")
    } catch {
        print("Parsing spec failed: \(error.localizedDescription)")
        return
    }

    do {
        let projectGenerator = ProjectGenerator(spec: spec, path: specPath.parent())
        let project = try projectGenerator.generateProject()
        print("Generated project")
        print("Writing project")

        projectPath = projectPath + "\(spec.name).xcodeproj"
        try project.write(path: projectPath, override: true)
        print("Wrote project to file \(projectPath.string)")
    } catch let error as SpecValidationError {
        print(error.description)
    } catch {
        print("Project Generation failed: \(error.localizedDescription)")
    }
}

command(
    Option<String>("spec", "", flag: "s", description: "The path to the spec file"),
    Option<String>("project", "", flag: "p", description: "The path to the generated project"),
    generate)
    .run()

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

func generate(spec: String, project: String?) {

    let specPath = Path(spec).normalize()
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

    var spec: Spec
    do {
        spec = try Spec(path: specPath)
        print("Loaded spec: \(spec.targets.count) targets, \(spec.schemes.count) schemes, \(spec.configs.count) configs")
        let specLintingResults = SpecLinter.lint(spec)
        spec = specLintingResults.spec
        if !specLintingResults.errors.isEmpty {
            print("Spec errors: \n\t- \(specLintingResults.errors.map{$0.description}.joined(separator: "\n\t- "))")
            return
        }
        if !specLintingResults.appliedFixits.isEmpty {
            print("Applied spec fixits:\n\t- \(specLintingResults.appliedFixits.map{$0.description}.joined(separator: "\n\t- "))")
        }
    } catch {
        print("Parsing spec failed: \(error)")
        return
    }

    do {
        let projectGenerator = ProjectGenerator(spec: spec)
        let project = try projectGenerator.generate()
        print("Generated project")
        print("Writing project")

        projectPath = projectPath + "\(spec.name).xcodeproj"
        try project.write(path: projectPath, override: true)
        print("Wrote project to file \(projectPath.string)")
    } catch {
        print("Project Generation failed: \(error)")
    }
}

command(
    Option<String>("spec", "", flag: "s", description: "The path to the spec file"),
    Option<String>("project", "", flag: "p", description: "The path to the generated project"),
    generate)
    .run()

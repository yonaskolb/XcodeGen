//
//  SourceGeneratorTests.swift
//  XcodeGenKit
//
//  Created by ryohey on 2017/11/18.
//

import Spectre
import XcodeGenKit
import xcproj
import PathKit
import ProjectSpec
import Yams


func sourceGeneratorTests() {

    describe("SourceGenerator") {
        let application = Target(name: "MyApp", type: .application, platform: .iOS,
                                 settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
                                 dependencies: [])
        let options = ProjectSpec.Options(bundleIdPrefix: "com.test")
        let spec = ProjectSpec(basePath: "", name: "test", targets: [application], options: options)
        var objects: [PBXObject] = []
        let referenceGenerator = ReferenceGenerator()
        let proj = PBXProj(objectVersion: 46, rootObject: referenceGenerator.generate(PBXProject.self, "test"))
        let sourceGenerator = SourceGenerator(spec: spec, proj: proj, referenceGenerator: referenceGenerator, addObject: { objects.append($0) })

        $0.it("_") {
            let dir: File = File("Src", [
                File("main.swift"),
                File("ViewController.swift"),
                File("Base.lproj", [File("Main.storyboard")]),
                File("en.lproj", [File("Main.strings")]),
                ])
            sourceGenerator.getFileGroups(in: dir)
            try expect(sourceGenerator.knownRegions.contains("Base")).to.beTrue()
            try expect(sourceGenerator.knownRegions.contains("en")).to.beTrue()
        }
    }
}

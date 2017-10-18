import Spectre
import XcodeGenKit
import xcproj
import ProjectSpec

func projectSpecTests() {

    describe("ProjectSpec") {

        let framework = Target(name: "MyFramework", type: .framework, platform: .iOS,
                               settings: Settings(buildSettings: ["SETTING_2": "VALUE"]))
        let staticLibrary = Target(name: "MyStaticLibrary", type: .staticLibrary, platform: .iOS,
                                   settings: Settings(buildSettings: ["SETTING_2": "VALUE"]))
        let dynamicLibrary = Target(name: "MyDynamicLibrary", type: .dynamicLibrary, platform: .iOS,
                                    settings: Settings(buildSettings: ["SETTING_2": "VALUE"]))

        $0.describe("Types") {
            $0.it("is a framework when it has the right extension") {
                try expect(framework.type.isFramework).to.beTrue()
            }

            $0.it("is a library when it has the right type") {
                try expect(staticLibrary.type.isLibrary).to.beTrue()
                try expect(dynamicLibrary.type.isLibrary).to.beTrue()
            }
        }
    }
}

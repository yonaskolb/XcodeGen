import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import XCTest
@testable import XcodeGenKit

class IconComposerSupportTests: XCTestCase {
    
    func testIconComposerDetection() throws {
        let fixturePath = Path(#file).parent().parent() + "Fixtures/IconComposerTest"
        
        // Test that IconComposer-generated icons are detected
        let assetCatalogPath = fixturePath + "App/Assets.xcassets"
        XCTAssertTrue(IconComposerSupport.isIconComposerGenerated(at: assetCatalogPath))
        
        // Test that the correct app icon name is detected
        let iconName = IconComposerSupport.detectAppIconName(for: assetCatalogPath)
        XCTAssertEqual(iconName, "IconComposerAppIcon")
    }
    
    func testIconComposerBuildSettings() throws {
        let fixturePath = Path(#file).parent().parent() + "Fixtures/IconComposerTest"
        let project = try Project(path: fixturePath + "project.yml")
        
        let pbxProject = try project.generatePbxProj()
        let target = try unwrap(pbxProject.nativeTargets.first)
        let buildConfig = try unwrap(target.buildConfigurationList?.buildConfigurations.first)
        
        // Test that ASSETCATALOG_COMPILER_APPICON_NAME is set correctly for IconComposer icons
        let appIconName = buildConfig.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String
        XCTAssertEqual(appIconName, "IconComposerAppIcon")
    }
    

    
    func testIconFolderTreatedAsFileReference() throws {
        let fixturePath = Path(#file).parent().parent() + "Fixtures/IconComposerTest"
        let project = try Project(path: fixturePath + "project.yml")
        let pbxProj = try project.generatePbxProj()

        // Core test: .icon folder should be treated as a file reference, not a group
        let iconFileRef = pbxProj.fileReferences.first(where: { $0.path?.hasSuffix("TestIcon.icon") == true })
        XCTAssertNotNil(iconFileRef, ".icon folder should be a PBXFileReference")
        XCTAssertEqual(iconFileRef?.lastKnownFileType, "wrapper.icon", ".icon folder should have lastKnownFileType = wrapper.icon")
        
        // Verify it's not treated as a group
        let isGroup = pbxProj.groups.contains(where: { $0.path == iconFileRef?.path })
        XCTAssertFalse(isGroup, ".icon folder should not be a PBXGroup")
    }
}

private func unwrap<T>(_ optional: T?) throws -> T {
    guard let unwrapped = optional else {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unwrap optional"])
    }
    return unwrapped
} 
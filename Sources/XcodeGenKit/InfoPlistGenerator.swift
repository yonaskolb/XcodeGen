import Foundation
import PathKit
import ProjectSpec

public class InfoPlistGenerator {

    /**
     Default info plist attributes taken from:
     /Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/Base/Base_DefinitionsInfoPlist.xctemplate/TemplateInfo.plist
     */
    private func generateDefaultInfoPlist(for target: Target) -> [String: Any] {
        var dictionary: [String: Any] = [:]
        dictionary["CFBundleIdentifier"] = "$(PRODUCT_BUNDLE_IDENTIFIER)"
        dictionary["CFBundleInfoDictionaryVersion"] = "6.0"

        dictionary["CFBundleName"] = "$(PRODUCT_NAME)"
        dictionary["CFBundleDevelopmentRegion"] = "$(DEVELOPMENT_LANGUAGE)"
        dictionary["CFBundleShortVersionString"] = "1.0"
        dictionary["CFBundleVersion"] = "1"

        // Bundles should not contain any CFBundleExecutable otherwise they will be rejected when uploading.
        if target.type != .bundle {
            dictionary["CFBundleExecutable"] = "$(EXECUTABLE_NAME)"
        }

        return dictionary
    }

    public func generateProperties(for target: Target) -> [String: Any] {
        var targetInfoPlist = generateDefaultInfoPlist(for: target)
        switch target.type {
        case .uiTestBundle,
             .unitTestBundle:
            targetInfoPlist["CFBundlePackageType"] = "BNDL"
        case .application,
             .watch2App:
            targetInfoPlist["CFBundlePackageType"] = "APPL"
        case .framework:
            targetInfoPlist["CFBundlePackageType"] = "FMWK"
        case .bundle:
            targetInfoPlist["CFBundlePackageType"] = "BNDL"
        case .xpcService,
             .appExtension:
            targetInfoPlist["CFBundlePackageType"] = "XPC!"
        default: break
        }
        return targetInfoPlist
    }
}

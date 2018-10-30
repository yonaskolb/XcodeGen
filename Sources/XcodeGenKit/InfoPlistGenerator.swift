import Foundation
import ProjectSpec
import PathKit

public class InfoPlistGenerator {

    /**
     Default info plist attributes taken from:
     /Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/Base/Base_DefinitionsInfoPlist.xctemplate/TemplateInfo.plist
     */
    var defaultInfoPlist: [String: Any] =  {
        var dictionary: [String: Any] = [:]
        dictionary["CFBundleIdentifier"] = "$(PRODUCT_BUNDLE_IDENTIFIER)"
        dictionary["CFBundleInfoDictionaryVersion"] = "6.0"
        dictionary["CFBundleExecutable"] = "$(EXECUTABLE_NAME)"
        dictionary["CFBundleName"] = "$(PRODUCT_NAME)"
        dictionary["CFBundleDevelopmentRegion"] = "$(DEVELOPMENT_LANGUAGE)"
        dictionary["CFBundleShortVersionString"] = "1.0"
        dictionary["CFBundleVersion"] = "1"
        return dictionary
    }()

    public func generateProperties(target: Target) -> [String: Any] {
        var targetInfoPlist = defaultInfoPlist
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
        case .xpcService:
            targetInfoPlist["CFBundlePackageType"] = "XPC"
        default: break
        }
        return targetInfoPlist
    }
}

import Foundation
import XcodeProj

public enum Linkage {
    case dynamic
    case `static`
    case none
}

extension Target {

    public var defaultLinkage: Linkage {
        switch type {
        case .none,
             .appExtension,
             .application,
             .bundle,
             .commandLineTool,
             .instrumentsPackage,
             .intentsServiceExtension,
             .messagesApplication,
             .messagesExtension,
             .metalLibrary,
             .ocUnitTestBundle,
             .onDemandInstallCapableApplication,
             .stickerPack,
             .tvExtension,
             .uiTestBundle,
             .unitTestBundle,
             .watchApp,
             .watchExtension,
             .watch2App,
             .watch2AppContainer,
             .watch2Extension,
             .xcodeExtension,
             .xpcService,
             .systemExtension,
             .driverExtension:
            return .none
        case .framework, .xcFramework:
            // Check the MACH_O_TYPE for "Static Framework"
            if settings.buildSettings.machOType == "staticlib" {
                return .static
            } else {
                return .dynamic
            }
        case .dynamicLibrary:
            return .dynamic
        case .staticLibrary, .staticFramework:
            return .static
        }
    }
}

private extension BuildSettings {

    var machOType: String? {
        self["MACH_O_TYPE"] as? String
    }
}

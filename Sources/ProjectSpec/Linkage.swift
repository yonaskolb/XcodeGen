import Foundation
import XcodeProj

public enum Linkage {
    case dynamic
    case `static`
    case none
}

extension PBXProductType {

    public var defaultLinkage: Linkage {
        switch self {
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
             .xpcService:
            return .none
        case .framework, .xcFramework:
            // TODO: This should check `MACH_O_TYPE` in case this is a "Static Framework"
            return .dynamic
        case .dynamicLibrary:
            return .dynamic
        case .staticLibrary, .staticFramework:
            return .static
        }
    }
}

import Foundation

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
             .ocUnitTestBundle,
             .stickerPack,
             .tvExtension,
             .uiTestBundle,
             .unitTestBundle,
             .watchApp,
             .watchExtension,
             .watch2App,
             .watch2Extension,
             .xcodeExtension,
             .xpcService:
            return .none
        case .framework:
            // TODO: This should check `MACH_O_TYPE` in case this is a "Static Framework"
            return .dynamic
        case .dynamicLibrary:
            return .dynamic
        case .staticLibrary:
            return .static
        }
    }
}

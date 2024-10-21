import Foundation
import XcodeProj

public protocol ProjectTarget: BuildSettingsContainer {

    var name: String { get }
    var type: PBXProductType { get }
    var buildScripts: [BuildScript] { get }
    var buildToolPlugins: [BuildToolPlugin] { get }
    var scheme: TargetScheme? { get }
    var attributes: [String: Any] { get }
    var nameDividerChar: String? { get }
}

extension Target {

    public var buildScripts: [BuildScript] {
        preBuildScripts + postCompileScripts + postBuildScripts
    }
}

extension Project {

    public var projectTargets: [ProjectTarget] {
        targets.map { $0 as ProjectTarget } + aggregateTargets.map { $0 as ProjectTarget }
    }
}

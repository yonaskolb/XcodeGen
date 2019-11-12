import Foundation

public protocol ProjectTarget: BuildSettingsContainer {

    var name: String { get }
    var buildScripts: [BuildScript] { get }
    var scheme: TargetScheme? { get }
    var attributes: [String: Any] { get }
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

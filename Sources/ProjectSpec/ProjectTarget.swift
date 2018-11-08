import Foundation

public protocol ProjectTarget: BuildSettingsContainer {

    var name: String { get }
    var buildScripts: [BuildScript] { get }
    var scheme: TargetScheme? { get }
    var attributes: [String: Any] { get }
}

extension Target {

    public var buildScripts: [BuildScript] {
        return preBuildScripts + postCompileScripts + postBuildScripts
    }
}

extension Project {

    public var projectTargets: [ProjectTarget] {
        return targets.map { $0 as ProjectTarget } + aggregateTargets.map { $0 as ProjectTarget }
    }
}

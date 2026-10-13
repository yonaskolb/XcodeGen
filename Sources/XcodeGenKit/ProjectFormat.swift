import ProjectSpec

/// `ProjectFormat` is defined in `ProjectSpec` so that spec validation can check `options.projectFormat`.
/// This alias keeps `XcodeGenKit.ProjectFormat` available to existing clients.
public typealias ProjectFormat = ProjectSpec.ProjectFormat

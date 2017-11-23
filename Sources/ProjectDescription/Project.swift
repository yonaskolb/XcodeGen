import Foundation

public final class Project {
    
    // MARK: - Attributes
    
    /// Project name.
    private let name: String
    
    /// Project targets
    private let targets: [Target]
    
    // MARK: - Init
    
    public init(name: String, targets: [Target]) {
        self.name = name
        self.targets = targets
    }
    
}

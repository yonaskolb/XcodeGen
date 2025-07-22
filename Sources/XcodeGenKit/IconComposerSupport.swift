import Foundation
import PathKit
import ProjectSpec

/// Support for IconComposer-generated asset catalogs
public struct IconComposerSupport {
    
    /// Detects if an asset catalog contains IconComposer-generated icons
    /// - Parameter assetCatalogPath: Path to the asset catalog
    /// - Returns: True if the asset catalog contains IconComposer-generated icons
    public static func isIconComposerGenerated(at assetCatalogPath: Path) -> Bool {
        guard assetCatalogPath.isDirectory else { return false }
        
        // Check for IconComposer-specific directory structure
        let contentsPath = assetCatalogPath + "Contents.json"
        guard contentsPath.exists else { return false }
        
        // Look for IconComposer-specific patterns in the asset catalog
        let children = (try? assetCatalogPath.children()) ?? []
        
        // Check for IconComposer-specific naming patterns in app icon sets
        let hasIconComposerAppIcon = children.contains { child in
            guard child.extension == "appiconset" else { return false }
            let name = child.lastComponent.lowercased()
            return name.contains("iconcomposer") || 
                   name.contains("icon_composer") ||
                   name.contains("icon-composer") ||
                   name.contains("iconcomposer")
        }
        
        // Check for IconComposer-specific naming patterns in other assets
        let hasIconComposerPatterns = children.contains { child in
            let name = child.lastComponent.lowercased()
            return name.contains("iconcomposer") || 
                   name.contains("icon_composer") ||
                   name.contains("icon-composer") ||
                   name.contains("iconcomposer") ||
                   name.contains("iconcomponents") ||
                   name.contains("icon_components")
        }
        
        // Check for nested icon component structure
        let hasNestedIconStructure = children.contains { child in
            guard child.isDirectory else { return false }
            let childChildren = (try? child.children()) ?? []
            return childChildren.contains { grandChild in
                let name = grandChild.lastComponent.lowercased()
                return name.contains("icon") && (name.contains("component") || name.contains("layer"))
            }
        }
        
        return hasIconComposerAppIcon || hasIconComposerPatterns || hasNestedIconStructure
    }
    

    
    /// Determines the appropriate app icon name for the asset catalog
    /// - Parameter assetCatalogPath: Path to the asset catalog
    /// - Returns: The app icon name to use, or nil if no specific icon is found
    public static func detectAppIconName(for assetCatalogPath: Path) -> String? {
        guard isIconComposerGenerated(at: assetCatalogPath) else { return nil }
        
        let children = (try? assetCatalogPath.children()) ?? []
        
        // Look for IconComposer-specific app icon sets
        for child in children {
            let name = child.lastComponent.lowercased()
            
            // Check for IconComposer-specific naming patterns
            if name.contains("iconcomposer") && child.extension == "appiconset" {
                return child.lastComponentWithoutExtension
            }
            
            if name.contains("icon_composer") && child.extension == "appiconset" {
                return child.lastComponentWithoutExtension
            }
            
            if name.contains("icon-composer") && child.extension == "appiconset" {
                return child.lastComponentWithoutExtension
            }
            
            if name.contains("iconcomposer") && child.extension == "appiconset" {
                return child.lastComponentWithoutExtension
            }
        }
        
        // If no specific IconComposer icon set is found, look for any app icon set
        for child in children {
            if child.extension == "appiconset" {
                return child.lastComponentWithoutExtension
            }
        }
        
        return nil
    }
    

} 
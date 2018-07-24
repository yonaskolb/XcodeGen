import Foundation

public protocol BuildSettingsContainer {

    var settings: Settings { get }
    var configFiles: [String: String] { get }
}

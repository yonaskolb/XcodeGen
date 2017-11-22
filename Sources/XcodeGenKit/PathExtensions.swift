import Foundation
import PathKit

extension Path {

    func byRemovingBase(path: Path) -> Path {
        return Path(normalize().string.replacingOccurrences(of: "\(path.normalize().string)/", with: ""))
    }
}

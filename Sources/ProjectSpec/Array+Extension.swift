extension Array where Element == [String: Any?] {
    func removingEmptyArraysDictionariesAndNils() -> [[String: Any]] {
        var new: [[String: Any]] = []
        forEach { element in
            new.append(element.removingEmptyArraysDictionariesAndNils())
        }
        return new
    }
}

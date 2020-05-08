extension Dictionary where Key == String, Value == Any? {
    func removingEmptyArraysDictionariesAndNils() -> [String: Any] {
        var new: [String: Any] = [:]
        filter(outNil).forEach { pair in
            let value: Any
            if let array = pair.value as? [[String: Any?]] {
                value = array.removingEmptyArraysDictionariesAndNils()
            } else if let dictionary = pair.value as? [String: Any?] {
                value = dictionary.removingEmptyArraysDictionariesAndNils()
            } else {
                value = pair.value! // nil is filtered out :)
            }
            new[pair.key] = value
        }
        return new
            .filter(outEmptyArrays)
            .filter(outEmptyDictionaries)
    }

    func outEmptyArrays(_ pair: (key: String, value: Any)) -> Bool {
        guard let array = pair.value as? [Any] else { return true }
        return !array.isEmpty
    }

    func outEmptyDictionaries(_ pair: (key: String, value: Any)) -> Bool {
        guard let dictionary = pair.value as? [String: Any] else { return true }
        return !dictionary.isEmpty
    }

    func outNil(_ pair: (key: String, value: Any?)) -> Bool {
        return pair.value != nil
    }
}

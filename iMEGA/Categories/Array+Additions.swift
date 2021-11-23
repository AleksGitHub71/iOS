extension Array {
    func mnz_chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
    
    subscript (safe index: Int) -> Element? {
        return self.indices ~= index ? self[index] : nil
    }
}

extension Array where Element: Equatable {
    mutating func move(_ item: Element, to newIndex: Index) {
        if let index = firstIndex(of: item) {
            move(at: index, to: newIndex)
        }
    }

    mutating func bringToFront(item: Element) {
        move(item, to: 0)
    }

    mutating func sendToBack(item: Element) {
        move(item, to: endIndex-1)
    }
    
    func shifted(_ distance: Int = 1) -> Array<Element> {
        let offsetIndex = distance >= 0 ?
                                index(startIndex, offsetBy: distance, limitedBy: endIndex) :
                                index(endIndex, offsetBy: distance, limitedBy: startIndex)

        guard let index = offsetIndex else { return self }
        return Array(self[index ..< endIndex] + self[startIndex ..< index])
    }

    mutating func shift(_ distance: Int = 1) {
        self = shifted(distance)
    }
}

extension Array {
    mutating func move(at index: Index, to newIndex: Index) {
        insert(remove(at: index), at: newIndex)
    }
}

extension Array where Element: Hashable {
    func removeDuplicatesWhileKeepingTheOriginalOrder() -> [Element] {
        NSOrderedSet(array: self).array as? [Element] ?? []
    }
}

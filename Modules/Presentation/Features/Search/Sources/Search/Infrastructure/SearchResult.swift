import Foundation

public struct SearchResult: Identifiable, Sendable {
    public let id: ResultId
    public let title: String
    public let description: String
    public let properties: [Property]
    public let thumbnailImageData: @Sendable () async -> Data
    public let type: ResultType
    
    public init(
        id: ResultId,
        title: String,
        description: String,
        properties: [Property],
        thumbnailImageData: @Sendable @escaping () async -> Data,
        type: ResultType
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.properties = properties
        self.thumbnailImageData = thumbnailImageData
        self.type = type
    }
}

public typealias ResultId = UInt64

extension SearchResult: Equatable {
    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description &&
        lhs.properties == rhs.properties &&
        lhs.type == rhs.type
    }
}

extension Property: Equatable {
    public static func == (lhs: Property, rhs: Property) -> Bool {
        lhs.icon == rhs.icon
    }
}
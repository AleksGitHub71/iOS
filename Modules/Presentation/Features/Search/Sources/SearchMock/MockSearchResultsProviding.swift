import Search

public class MockSearchResultsProviding: SearchResultsProviding {
    public var refreshedSearchResultsToReturn: Search.SearchResultsEntity?
    public func refreshedSearchResults(queryRequest: Search.SearchQuery) async -> Search.SearchResultsEntity? {
        refreshedSearchResultsToReturn
    }
    
    public func currentResultIds() -> [Search.ResultId] {
        currentResultIdsToReturn
    }
    
    public var passedInQueries: [SearchQuery] = []
    public var currentResultIdsToReturn: [ResultId] = []
    public var resultFactory: (_ query: SearchQuery) async -> SearchResultsEntity?
    
    public init() {
        resultFactory = { _ in
            .resultWithNoItemsAndSingleChip
        }
    }

    public func search(
        queryRequest: SearchQuery,
        lastItemIndex: Int?
    ) async -> SearchResultsEntity? {
        passedInQueries.append(queryRequest)
        return await resultFactory(queryRequest)
    }
}

extension SearchResultsEntity {
    public static var resultWithSingleItemAndChip: Self {
        .init(
            results: [.resultWith(id: 1)],
            availableChips: [.chipWith(id: 2)],
            appliedChips: []
        )
    }
    public static var resultWithNoItemsAndSingleChip: Self {
        .init(
            results: [],
            availableChips: [.chipWith(id: 2)],
            appliedChips: []
        )
    }
}

extension SearchChipEntity {
    public static func chipWith(id: Int) -> Self {
        .init(
            type: .nodeFormat(id),
            title: "chip_\(id)",
            icon: nil
        )
    }
}

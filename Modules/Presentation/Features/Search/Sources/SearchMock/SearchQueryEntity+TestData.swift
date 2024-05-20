import Search

extension SearchQueryEntity {
    public static func query(
        _ string: String = "",
        isSearchActive: Bool = true,
        chips: [SearchChipEntity] = []
    ) -> Self {
        .init(
            query: string,
            sorting: .nameAscending,
            mode: .home,
            isSearchActive: isSearchActive,
            chips: chips
        )
    }
}

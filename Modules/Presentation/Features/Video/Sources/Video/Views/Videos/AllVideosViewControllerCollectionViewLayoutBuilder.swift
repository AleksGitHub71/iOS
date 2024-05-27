import UIKit

struct AllVideosViewControllerCollectionViewLayoutBuilder {
    
    let viewType: AllVideosCollectionViewRepresenter.ViewType
    
    func build() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout(
            sectionProvider: { makeCollectionViewLayoutSection(for: $1, viewType: viewType) },
            configuration: UICollectionViewCompositionalLayoutConfiguration()
        )
    }
    
    private func makeCollectionViewLayoutSection(
        for layoutEnvironment: some NSCollectionLayoutEnvironment,
        viewType: AllVideosCollectionViewRepresenter.ViewType
    ) -> NSCollectionLayoutSection {
        switch viewType {
        case .allVideos, .playlists:
            allVideosLayoutSection(layoutEnvironment: layoutEnvironment)
        case .playlistContent:
            makeSingleColumnLayout()
        }
    }
    
    private func allVideosLayoutSection(layoutEnvironment: some NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let horizontalSizeClass = layoutEnvironment.traitCollection.horizontalSizeClass
        let verticalSizeClass = layoutEnvironment.traitCollection.verticalSizeClass
        
        switch (horizontalSizeClass, verticalSizeClass) {
        case (.compact, .regular):
            return makeSingleColumnLayout()
        case  (.regular, .compact), (.compact, .compact):
            return makeMultiColumnLayout(columnCount: 2)
        default:
            return makeMultiColumnLayout(columnCount: 3)
        }
    }
    
    private func makeSingleColumnLayout() -> NSCollectionLayoutSection {
        let cellHeight: CGFloat = 80
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(cellHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(cellHeight))
        let group = makeSingleColumnLayoutGroup(from: groupSize, item: item)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 8, bottom: 16, trailing: 8)
        
        return section
    }
    
    private func makeSingleColumnLayoutGroup(from groupSize: NSCollectionLayoutSize, item: NSCollectionLayoutItem) -> NSCollectionLayoutGroup {
        if #available(iOS 16.0, *) {
            NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 1)
        } else {
            NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        }
    }
    
    private func makeMultiColumnLayout(columnCount: Int) -> NSCollectionLayoutSection {
        let cellHeight: CGFloat = 80
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(cellHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(cellHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columnCount)
        group.interItemSpacing = .fixed(24)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 24
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        
        return section
    }
}

import MEGADesignToken
import SwiftUI

struct PhotosBrowserCollectionViewRepresenter: UIViewRepresentable {
    let viewModel: PhotosBrowserCollectionViewModel
    
    func makeCoordinator() -> PhotosBrowserCollectionViewCoordinator {
        PhotosBrowserCollectionViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: PhotosBrowserCollectionViewLayout())
        collectionView.backgroundColor = TokenColors.Background.page
        collectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        
        context.coordinator.configureDataSource(for: collectionView)
        
        return collectionView
    }
    
    func updateUIView(_ uiView: UICollectionView, context: Context) {
        guard let dataSource = context.coordinator.dataSource else { return }
        
        dataSource.apply(context.coordinator.snapshot(), animatingDifferences: true)
    }
}

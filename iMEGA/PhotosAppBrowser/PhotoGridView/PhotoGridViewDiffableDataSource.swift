import UIKit
import Photos

@available(iOS 13.0, *)
final class PhotoGridViewDiffableDataSource: PhotoGridViewBaseDataSource {
    private enum Section {
        case main
    }
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, PHAsset>?
    
    func load(assets: [PHAsset]) {
        selectedAssets = selectedAssets.reduce(into: []) { result, asset in
            if assets.contains(asset) {
                result.append(asset)
            }
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, PHAsset>()
        snapshot.appendSections([.main])
        snapshot.appendItems(assets)
        snapshot.reloadItems(selectedAssets)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
    
    func reload(assets: [PHAsset]) {
        guard var newSnapshot = dataSource?.snapshot() else { return }
        newSnapshot.reloadItems(assets)
        dataSource?.apply(newSnapshot)
    }
    
    func configureDataSource() {
        guard let collectionView = collectionView else { return }
        
        dataSource = UICollectionViewDiffableDataSource<Section, PHAsset>(collectionView: collectionView) { [weak self]
            (collectionView: UICollectionView, indexPath: IndexPath, asset: PHAsset) -> UICollectionViewCell? in
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoGridViewCell.reuseIdentifier,
                                                                for: indexPath) as? PhotoGridViewCell else {
                return UICollectionViewCell()
            }
            
            self.configureCell(cell: cell, indexPath: indexPath, asset: asset)
            return cell
        }
    }
    
    func didSelect(asset: PHAsset) {
        let reloadAssets: [PHAsset]
        if let index = selectedAssets.firstIndex(of: asset) {
            reloadAssets = Array(selectedAssets[index..<selectedAssets.count])
            selectedAssets.remove(at: index)
        } else {
            selectedAssets.append(asset)
            reloadAssets = [asset]
        }
        
        reload(assets: reloadAssets)
    }
}

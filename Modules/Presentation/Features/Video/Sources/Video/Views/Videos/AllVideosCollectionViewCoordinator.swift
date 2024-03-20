import Foundation
import MEGADomain
import SwiftUI

final class AllVideosCollectionViewCoordinator: NSObject {
    
    private enum Section {
        case allVideos
    }
    
    /// Row Item type to support diffable data source diffing while protecting `NodeEntity` agasint the `DiffableDataSource` API.
    private struct RowItem: Hashable {
        let node: NodeEntity
        
        init(node: NodeEntity) {
            self.node = node
        }
        
        static func == (lhs: RowItem, rhs: RowItem) -> Bool {
            lhs.node.id == rhs.node.id
            && lhs.node.isFavourite == rhs.node.isFavourite
            && lhs.node.name == rhs.node.name
            && lhs.node.label == rhs.node.label
            && lhs.node.isExported == rhs.node.isExported
        }
    }
    
    private let videoConfig: VideoConfig
    private let representer: AllVideosCollectionViewRepresenter
    
    private var dataSource: DiffableDataSource?
    private typealias CellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Item>
    private typealias DiffableDataSource = UICollectionViewDiffableDataSource<Section, Item>
    private typealias DiffableDataSourceSnapshot = NSDiffableDataSourceSnapshot<Section, Item>
    private typealias Item = RowItem
    
    init(_ representer: AllVideosCollectionViewRepresenter) {
        self.representer = representer
        self.videoConfig = representer.videoConfig
    }
    
    func configureDataSource(for collectionView: UICollectionView) {
        collectionView.delegate = self
        
        dataSource = makeDataSource(for: collectionView)
        collectionView.dataSource = dataSource
    }
    
    private func makeDataSource(for collectionView: UICollectionView) -> DiffableDataSource {
        let cellRegistration = CellRegistration { [weak self] cell, _, rowItem in
            guard let self else { return }
            
            let cellViewModel = VideoCellViewModel(
                thumbnailUseCase: representer.viewModel.thumbnailUseCase,
                nodeEntity: rowItem.node,
                onTapMoreOptions: { [weak self] in self?.onTapMoreOptions($0, sender: cell) }
            )
            configureCell(cell, cellViewModel: cellViewModel)
        }
        
        return DiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }
    
    func reloadData(with videos: [NodeEntity]) {
        var snapshot = DiffableDataSourceSnapshot()
        snapshot.appendSections([.allVideos])
        snapshot.appendItems(videos.map(RowItem.init(node:)), toSection: .allVideos)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
    
    // MARK: - Cell setup
    
    private func configureCell(_ cell: UICollectionViewCell, cellViewModel: VideoCellViewModel) {
        if #available(iOS 16.0, *) {
            cell.contentConfiguration = UIHostingConfiguration {
                VideoCellView(
                    viewModel: cellViewModel,
                    selection: self.representer.selection,
                    videoConfig: videoConfig
                )
                    .background(videoConfig.colorAssets.pageBackgroundColor)
            }
            .margins(.all, 0)
            cell.clipsToBounds = true
        } else {
            configureCellBelowiOS16(cellViewModel: cellViewModel, cell: cell)
        }
    }
    
    private func configureCellBelowiOS16(cellViewModel: VideoCellViewModel, cell: UICollectionViewCell) {
        let cellView = VideoCellView(
            viewModel: cellViewModel,
            selection: self.representer.selection,
            videoConfig: videoConfig
        )
        
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let cellHostingController = UIHostingController(rootView: cellView)
        cellHostingController.view.backgroundColor = .clear
        cellHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(cellHostingController.view)
        cell.contentView.backgroundColor = UIColor(videoConfig.colorAssets.pageBackgroundColor)
        
        NSLayoutConstraint.activate([
            cellHostingController.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            cellHostingController.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            cellHostingController.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            cellHostingController.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
        ])
    }
    
    private func onTapMoreOptions(_ video: NodeEntity, sender: Any) {
        representer.router.openMoreOptions(for: video, sender: sender)
    }
}

// MARK: - AllVideosCollectionViewCoordinator+UICollectionViewDelegate

extension AllVideosCollectionViewCoordinator: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let videos = (dataSource?.snapshot().itemIdentifiers ?? []).map(\.node)
        guard let video = videos[safe: indexPath.item] else { return }
        representer.router.openMediaBrowser(for: video, allVideos: videos)
    }
}

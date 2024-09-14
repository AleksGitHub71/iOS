import MEGADesignToken
import MEGADomain
import MEGASDKRepo

extension ThumbnailViewerTableViewCell {
    @objc func updateAppearance(with traitCollection: UITraitCollection) {
        backgroundColor = UIColor.mnz_backgroundElevated(traitCollection)
        thumbnailViewerCollectionView?.backgroundColor = UIColor.mnz_backgroundElevated(traitCollection)
        addedByLabel?.textColor = UIColor.cellTitleColor(for: traitCollection)
        timeLabel?.textColor = UIColor.mnz_subtitles()
        infoLabel?.textColor = UIColor.mnz_subtitles()
        indicatorImageView.tintColor = indicatorTintColor()
    }
    
    @objc func indicatorTintColor() -> UIColor {
        TokenColors.Icon.secondary
    }
    
    @objc func createViewModel(nodes: [MEGANode]) -> ThumbnailViewerTableViewCellViewModel {
        .init(nodes: nodes.toNodeEntities(),
              nodeUseCase: NodeUseCase(
                nodeDataRepository: NodeDataRepository.newRepo,
                nodeValidationRepository: NodeValidationRepository.newRepo,
                nodeRepository: NodeRepository.newRepo), 
              nodeIconUseCase: NodeIconUseCase(nodeIconRepo: NodeAssetsManager.shared),
              thumbnailUseCase: ThumbnailUseCase(repository: ThumbnailRepository.newRepo))
    }
    
    @objc func configureItem(at indexPath: NSIndexPath, cell: ItemCollectionViewCell) {
        
        guard let itemViewModel = viewModel.item(for: indexPath.row) else {
            return
        }
        
        cell.bind(viewModel: itemViewModel)
    }
}

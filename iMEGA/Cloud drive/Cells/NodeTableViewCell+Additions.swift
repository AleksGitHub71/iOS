import MEGADesignToken
import MEGADomain
import MEGAL10n
import MEGAPresentation
import MEGASDKRepo
import MEGAUIKit

extension NodeTableViewCell {
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        
        viewModel = nil
        cancellables = nil

        thumbnailImageView.removeBlurFromView()
        [thumbnailContainer, topContainerStackView, bottomContainerStackView]
            .forEach { $0?.alpha = 1 }        
    }
    
    @objc func setTitleAndFolderName(for recentActionBucket: MEGARecentActionBucket,
                                     withNodes nodes: [MEGANode]) {
        
        guard let firstNode = nodes.first else {
            infoLabel.text = ""
            nameLabel.text = ""
            return
        }
        
        let isNodeUndecrypted = firstNode.isUndecrypted(ownerEmail: recentActionBucket.userEmail ?? "",
                                                        in: .shared)
        guard !isNodeUndecrypted else {
            infoLabel.text = Strings.Localizable.SharedItems.Tab.Incoming.undecryptedFolderName
            nameLabel.text = Strings.Localizable.SharedItems.Tab.Recents.undecryptedFileName(nodes.count)
            return
        }
        
        let firstNodeName = firstNode.name ?? ""
        let nodesCount = nodes.count
        nameLabel.text = nodesCount == 1 ? firstNodeName : Strings.Localizable.Recents.Section.MultipleFile.title(nodesCount - 1).replacingOccurrences(of: "[A]", with: firstNodeName)
        
        let parentNode = MEGASdk.shared.node(forHandle: recentActionBucket.parentHandle)
        let parentNodeName = parentNode?.name ?? ""
        infoLabel.text = "\(parentNodeName) ・"
    }
    
    @objc func configureMoreButtonUI() {
        moreButton.tintColor = UIColor.isDesignTokenEnabled() ? TokenColors.Icon.secondary : UIColor.grayBBBBBB
    }
    
    @objc func setAccessibilityLabelsForIcons(in node: MEGANode) {
        labelImageView?.accessibilityLabel = MEGANode.string(for: node.label)
        favouriteImageView?.accessibilityLabel = Strings.Localizable.favourite
        linkImageView?.accessibilityLabel = Strings.Localizable.shared
    }
    
    @objc func configureIconsImageColor() {
        guard UIColor.isDesignTokenEnabled() else { return }
        
        configureIconImageColor(for: favouriteImageView)
        configureIconImageColor(for: linkImageView)
        configureIconImageColor(for: versionedImageView)
        configureIconImageColor(for: downloadedImageView)
    }
    
    @objc func createViewModel(node: MEGANode?) -> NodeTableViewCellViewModel {
        createViewModel(nodes: [node].compactMap { $0 })
    }
    
    @objc func createViewModel(nodes: [MEGANode]) -> NodeTableViewCellViewModel {
        .init(nodes: nodes.toNodeEntities(),
              flavour: cellFlavor,
              nodeUseCase: NodeUseCase(
                nodeDataRepository: NodeDataRepository.newRepo,
                nodeValidationRepository: NodeValidationRepository.newRepo,
                nodeRepository: NodeRepository.newRepo))
    }
    
    @objc func bind(viewModel: NodeTableViewCellViewModel) {
        
        self.viewModel = viewModel
        
        viewModel.configureCell()
        
        cancellables = [
            viewModel
                .$isSensitive
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.configureBlur(isSensitive: $0) }
        ]
    }
    
    private func configureBlur(isSensitive: Bool) {
        let alpha: CGFloat = isSensitive ? 0.5 : 1
        [
            viewModel.hasThumbnail ? nil : thumbnailContainer,
            topContainerStackView,
            bottomContainerStackView
        ].forEach { $0?.alpha = alpha }
        
        if viewModel.hasThumbnail, isSensitive {
            thumbnailImageView?.addBlurToView(style: .systemUltraThinMaterial)
        } else {
            thumbnailImageView?.removeBlurFromView()
        }
    }
    
    private func configureIconImageColor(for imageView: UIImageView?) {
        guard let imageView else { return }
        imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = TokenColors.Icon.secondary
    }
    
    @objc func setCellBackgroundColor(with traitCollection: UITraitCollection) {
        var bgColor: UIColor = .black
        
        if UIColor.isDesignTokenEnabled() {
            bgColor = TokenColors.Background.page
        } else {
            bgColor = traitCollection.userInterfaceStyle == .dark ? UIColor.black1C1C1E : UIColor.whiteFFFFFF
        }
        
        backgroundColor = bgColor
    }
}

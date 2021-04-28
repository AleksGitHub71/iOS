import UIKit

class FilesExplorerGridViewController: FilesExplorerViewController {
    
    private lazy var layout: CHTCollectionViewWaterfallLayout = CHTCollectionViewWaterfallLayout()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        return collectionView
    }()
    
    private lazy var searchBarView = UIView()

    private var gridSource: FilesExplorerGridSource? {
        didSet {
            guard let gridSource = gridSource else { return }
            
            collectionView.dataSource = gridSource
            collectionView.delegate = self
            collectionView.emptyDataSetSource = self
            collectionView.reloadData()
            collectionView.reloadEmptyDataSet()
        }
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        addCollectionView()
        configureLayout()
        collectionView.register(
            FileExplorerGridCell.nib,
            forCellWithReuseIdentifier: FileExplorerGridCell.reuseIdentifier
        )
        
        viewModel.invokeCommand = { [weak self] command in
            self?.executeCommand(command)
        }
        
        viewModel.dispatch(.onViewReady)
        delegate?.updateSearchResults()
        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false
    }
    
    override func toggleSelectAllNodes() {
        gridSource?.toggleSelectAllNodes()
        configureToolbarButtons()
        delegate?.didSelectNodes(withCount: gridSource?.selectedNodes?.count ?? 0)
    }
    
    override func removeSearchController(_ searchController: UISearchController) {
        guard let searchBar = searchBarView.subviews.first,
              searchBar == searchController.searchBar else {
            return
        }
        
        searchController.searchBar.removeFromSuperview()
        searchBarView.removeFromSuperview()
        collectionView.autoPinEdge(toSuperviewEdge: .top)
    }
    
    override func setEditingMode() {
        setEditing(true, animated: true)
        audioPlayer(hidden: true)
    }
    
    override func endEditingMode() {
        super.endEditingMode()
        setEditing(false, animated: true)
        audioPlayer(hidden: false)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        collectionView.allowsMultipleSelection = editing
        
        if #available(iOS 14, *) {
            collectionView.allowsMultipleSelectionDuringEditing = editing;
        }
        
        collectionView.alwaysBounceVertical = !editing
        gridSource?.allowsMultipleSelection = editing
        
        if editing {
            configureToolbarButtons()
            showToolbar()
        } else {
            hideToolbar()
            collectionView.clearSelectedItems()
        }
        
        super.setEditing(editing, animated: animated)
    }
    
    override func selectedNodes() -> [MEGANode]? {
        return gridSource?.selectedNodes
    }
    
    override func updateContentView(_ height: CGFloat) {
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
    }
    
    private func addCollectionView() {
        view.addSubview(collectionView)
        collectionView.autoPinEdgesToSuperviewSafeArea()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { (_) in
            self.layout.configThumbnailListColumnCount()
        }
    }

    private func configureLayout() {
        // Change individual layout attributes for the spacing between cells
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        layout.minimumColumnSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.configThumbnailListColumnCount()
    }
    
    // MARK: - Execute command
    private func executeCommand(_ command: FilesExplorerViewModel.Command) {
        switch command {
        case .reloadNodes(let nodes, let searchText):
            configureView(withSearchText: searchText, nodes: nodes)
            gridSource = FilesExplorerGridSource(
                collectionView: collectionView,
                nodes: nodes,
                allowsMultipleSelection: gridSource?.allowsMultipleSelection ?? false,
                selectedNodes: gridSource?.selectedNodes
            ) { [weak self] node, button in
                self?.showMoreOptions(forNode: node, sender: button)
            }
        case .onNodesUpdate(let updatedNodes):
            gridSource?.updateCells(forNodes: updatedNodes)
        case .reloadData:
            delegate?.updateSearchResults()
        case .setViewConfiguration(let configuration):
            self.configuration = configuration
        default:
            break
        }
    }
}

extension FilesExplorerGridViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if gridSource?.allowsMultipleSelection ?? false {
            gridSource?.select(indexPath: indexPath)
            configureToolbarButtons()
            delegate?.didSelectNodes(withCount: gridSource?.selectedNodes?.count ?? 0)
        } else {
            if let nodes = gridSource?.nodes {
                viewModel.dispatch(.didSelectNode(nodes[indexPath.item], nodes))
            }
            
            collectionView.clearSelectedItems(animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if gridSource?.allowsMultipleSelection ?? false {
            gridSource?.deselect(indexPath: indexPath)
            configureToolbarButtons()
            delegate?.didSelectNodes(withCount: gridSource?.selectedNodes?.count ?? 0)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        gridSource?.collectionView(collectionView, willDisplay: cell, forItemAt: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        true
    }
    
    func collectionView(_ collectionView: UICollectionView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        setEditingMode()
        delegate?.showSelectButton(true)
    }
    
    func collectionViewDidEndMultipleSelectionInteraction(_ collectionView: UICollectionView) {
        collectionView.alwaysBounceVertical = true
    }
}

// MARK:- Scrollview delegate
extension FilesExplorerGridViewController {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.didScroll(scrollView: scrollView)
    }
}

// MARK: - CollectionView Waterfall Layout Delegate Methods (Required)
extension FilesExplorerGridViewController: CHTCollectionViewDelegateWaterfallLayout {
    // ** Size for the cells in the Waterfall Layout */
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // create a cell size from the image size, and return the size
        return CGSize(width: CGFloat(ThumbnailSize.width.rawValue), height: CGFloat(ThumbnailSize.heightFile.rawValue))
    }
}

import UIKit

final class MiniPlayerViewController: UIViewController {
    @IBOutlet weak var progressBarView: MEGAProgressBarView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var playPauseButtonImageView: UIImageView!
    @IBOutlet weak var closeButtonImageView: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var containerViewLeadingConstraint: NSLayoutConstraint!
    
    // MARK: - Private properties
    private var miniPlayerSource: MiniPlayerDataSource? {
        didSet {
            collectionView.dataSource = miniPlayerSource
        }
    }
    private var miniPlayerDelegate: MiniPlayerDelegate? {
        didSet {
            collectionView.delegate = miniPlayerDelegate
        }
    }
    private var lastMovementIndexPath: IndexPath?
    private let containerViewDefaultMargin: CGFloat = 12.0
    
    // MARK: - Internal properties
    var viewModel: MiniPlayerViewModel!
    
    // MARK: - View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateAppearance()
        
        viewModel.invokeCommand = { [weak self] command in
            DispatchQueue.main.async { self?.executeCommand(command) }
        }
        
        viewModel.dispatch(.onViewDidLoad)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
        updateAppearance()
        progressBarView.setNeedsDisplay()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            if let nav = navigationController {
                AppearanceManager.forceNavigationBarUpdate(nav.navigationBar, traitCollection: traitCollection)
            }
            
            updateAppearance()
            collectionView.reloadData()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            self.updateAppearance()
        })
    }
    
    deinit {
        viewModel.dispatch(.deinit)
    }
    
    // MARK: - Private functions
    private func updatePlayback(_ percentage: Float, _ isPlaying: Bool) {
        progressBarView.setProgress(progress: CGFloat(percentage), animated: false)
        playPauseButtonImageView.image = isPlaying ? Asset.Images.AudioPlayer.MiniPlayer.miniplayerPause.image : Asset.Images.AudioPlayer.MiniPlayer.miniplayerPlay.image
    }
    
    private func updatePlaybackTracks(_ currentItem: AudioPlayerItem, queue: [AudioPlayerItem]?, loopMode: Bool) {
        miniPlayerSource = MiniPlayerDataSource(currentTrack: currentItem, queue: queue, loopMode: loopMode)
        miniPlayerDelegate = MiniPlayerDelegate(delegate: self, loopMode: loopMode, itemsNumber: queue?.count ?? 0)
        imageView.image = Asset.Images.AudioPlayer.defaultArtwork.image
        
        collectionView.reloadData()
        collectionView.performBatchUpdates(nil) { (result) in
            let indexPath = IndexPath(row: queue?.firstIndex(of: currentItem) ?? 0, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }
    }
    
    private func updateCurrent(indexPath: IndexPath, item: AudioPlayerItem) {
        guard let cell = collectionView.visibleCells.first as? MiniPlayerItemCollectionViewCell,
              let currentItem = cell.item else { return }

        if item != currentItem, (lastMovementIndexPath == nil || lastMovementIndexPath == indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
    
    private func updateCurrent(item: AudioPlayerItem) {
        guard let cell = collectionView.visibleCells.first as? MiniPlayerItemCollectionViewCell,
              let indexPath = collectionView.indexPathsForVisibleItems.first,
              cell.item == item else { return }
        
        collectionView.reloadItems(at: [indexPath])
    }
    
    private func updateCurrent(thumbnail: UIImage?) {
        if let thumbnailImage = thumbnail {
            imageView.image = thumbnailImage
        } else {
            imageView.image = Asset.Images.AudioPlayer.defaultArtwork.image
        }
    }
    
    private func userInteraction(enabled: Bool) {
        collectionView.isUserInteractionEnabled = enabled
    }
    
    private func refreshStateOfLoadingView(_ enable: Bool) {
        activityIndicatorView.isHidden = !enable
        enable ? activityIndicatorView.startAnimating() : activityIndicatorView.stopAnimating()
        playPauseButtonImageView.isHidden = enable
        collectionView.isUserInteractionEnabled = !enable
    }
    
    // MARK: - UI configurations
    private func updateAppearance() {
        view.backgroundColor = .mnz_mainBars(for: traitCollection)
        collectionView.backgroundColor = .clear
        progressBarView.backgroundColor = UIColor.mnz_gray848484().withAlphaComponent(0.35)
        imageView.layer.cornerRadius = 8.0
        
        separatorView.backgroundColor = UIColor.mnz_gray848484().withAlphaComponent(0.35)
        separatorHeightConstraint.constant = 0.5
        
        containerViewLeadingConstraint.constant = UIDevice.current.orientation.isLandscape && UIDevice.current.iPhoneDevice ?
            containerViewDefaultMargin + (UIApplication.shared.keyWindow?.safeAreaInsets.left ?? 0.0) : containerViewDefaultMargin
    }
    
    // MARK: - UI actions
    @IBAction func playPauseButtonAction(_ sender: Any) {
        if activityIndicatorView.isHidden {
            viewModel.dispatch(.onPlayPause)
        }
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        viewModel.dispatch(.onClose)
    }
    
    // MARK: - Execute command
    func executeCommand(_ command: MiniPlayerViewModel.Command) {
        switch command {
        case .reloadPlayerStatus(let percentage, let isPlaying):
            updatePlayback(percentage, isPlaying)
        case .reloadNodeInfo(let thumbnail):
            updateCurrent(thumbnail: thumbnail)
        case .reload(let currentItem):
            updateCurrent(item: currentItem)
        case .initTracks(let currentItem, let queue, let loopMode):
            updatePlaybackTracks(currentItem, queue: queue, loopMode: loopMode)
        case .change(let currentItem, let indexPath):
            updateCurrent(indexPath: indexPath, item: currentItem)
        case .showLoading(let show):
            refreshStateOfLoadingView(show)
        case .enableUserInteraction(let enabled):
            userInteraction(enabled: enabled)
        }
    }
}

extension MiniPlayerViewController: MiniPlayerActionsDelegate {
    func play(index: IndexPath) {
        guard let cell = collectionView.cellForItem(at: index) as? MiniPlayerItemCollectionViewCell,
              let item = cell.item else { return }
        
        viewModel.dispatch(.playItem(item))
        
        lastMovementIndexPath = index
    }
    
    func showPlayer(node: MEGANode, filePath: String?) {
        viewModel.dispatch(.showPlayer(node, filePath))
    }
    
    func showPlayer(filePath: String?) {
        viewModel.dispatch(.showPlayer(nil, filePath))
    }
}

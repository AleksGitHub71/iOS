import MessageKit

class ChatVoiceClipCollectionViewCell: AudioMessageCell {
    
    var currentNode: MEGANode?
    weak var messagesCollectionView: MessagesCollectionView?
    
    open var waveView: UIImageView = {
        let waveView = UIImageView(image: UIImage(named: "waveform_0000"))
        waveView.animationDuration = 1
        waveView.frame = CGRect(x: 0, y: 0, width: 42, height: 25)
        return waveView
    }()
    
    open var loadingIndicator: UIActivityIndicatorView = {
        let loadingIndicator = UIActivityIndicatorView()
        loadingIndicator.startAnimating()
        loadingIndicator.isHidden = true
        return loadingIndicator
    }()
    
    // MARK: - Methods
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setupConstraints() {
        playButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 10)
        playButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        playButton.autoSetDimensions(to: CGSize(width: 15, height: 15))
        durationLabel.autoPinEdge(.leading, to: .trailing, of: playButton, withOffset: 10)
        durationLabel.autoPinEdge(.trailing, to: .leading, of: waveView, withOffset: 10)
        durationLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        waveView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 10)
        waveView.autoAlignAxis(toSuperviewAxis: .horizontal)
        waveView.autoSetDimensions(to: CGSize(width: 42, height: 25))

        loadingIndicator.autoPinEdge(.left, to: .left, of: playButton)
        loadingIndicator.autoPinEdge(.right, to: .right, of: playButton)
        loadingIndicator.autoPinEdge(.top, to: .top, of: playButton)
        loadingIndicator.autoPinEdge(.bottom, to: .bottom, of: playButton)
    }
    
    open override func setupSubviews() {
        messageContainerView.addSubview(waveView)
        messageContainerView.addSubview(loadingIndicator)
        super.setupSubviews()
        playButton.setImage(UIImage(named: "playVoiceClip")?.withRenderingMode(.alwaysTemplate), for: .normal)
        playButton.setImage(UIImage(named: "pauseVoiceClip")?.withRenderingMode(.alwaysTemplate), for: .selected)
        progressView.isHidden = true
        durationLabel.textAlignment = .left
        durationLabel.font = UIFont.systemFont(ofSize: 15)
    }
    
    override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        guard let chatMessage = message as? ChatMessage else {
            return
        }
        self.messagesCollectionView = messagesCollectionView
        let megaMessage = chatMessage.message
        
        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            return
            
        }
        
        let textColor = displayDelegate.textColor(for: message, at: indexPath, in: messagesCollectionView)
        messageContainerView.tintColor = textColor
        durationLabel.textColor = textColor
        progressView.trackTintColor = .lightGray
        var imageData:[UIImage] = []
        for i in 0...59 {
            let name = "waveform_000\(i)"
            guard let data = UIImage(named: name)?.withRenderingMode(.alwaysTemplate).byTintColor(textColor) else {
                return
            }
            imageData.append(data)
        }
        waveView.animationImages = imageData
        
        loadingIndicator.color = textColor
        
        if let transfer = chatMessage.transfer {
            if transfer.type == .download {
                guard let nodeList = megaMessage.nodeList, let currentNode = nodeList.node(at: 0) else { return }
                self.currentNode = currentNode
                let duration = max(currentNode.duration, 0)
                durationLabel.text = NSString.mnz_string(fromTimeInterval: TimeInterval(duration))
                if transfer.state.rawValue < MEGATransferState.complete.rawValue {
                    configureLoadingView()
                } else {
                    configureLoadedView()
                }
            } else if let path = transfer.path {
                guard FileManager.default.fileExists(atPath: path) else {
                    MEGALogInfo("Failed to create audio player for URL: \(path)")
                    return
                }
                let asset = AVAsset(url: URL(fileURLWithPath: path))
                durationLabel.text = NSString.mnz_string(fromTimeInterval: CMTimeGetSeconds(asset.duration))
            }
        } else {
            guard let nodeList = megaMessage.nodeList, let currentNode = nodeList.node(at: 0) else { return }
            self.currentNode = currentNode
            let duration = max(currentNode.duration, 0)
            durationLabel.text = NSString.mnz_string(fromTimeInterval: TimeInterval(duration))
            let nodePath = currentNode.mnz_voiceCachePath()
            if !FileManager.default.fileExists(atPath: nodePath) {
                let appData = NSString().mnz_appDataToDownloadAttach(toMessageID: megaMessage.messageId)
                MEGASdkManager.sharedMEGASdk().startDownloadTopPriority(with: currentNode, localPath: nodePath, appData: appData, delegate: MEGAStartDownloadTransferDelegate(start: nil, progress: nil, completion: nil, onError: nil))
                configureLoadingView()
            } else {
                configureLoadedView()
            }
        }
    }
    
    private func configureLoadingView() {
        loadingIndicator.startAnimating()
        loadingIndicator.isHidden = false
        playButton.isHidden = true
    }
     
    private func configureLoadedView() {
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
        playButton.isHidden = false
    }
    
}

open class ChatVoiceClipCollectionViewSizeCalculator: MessageSizeCalculator {
    public override init(layout: MessagesCollectionViewFlowLayout? = nil) {
        super.init(layout: layout)
        configureAccessoryView()
        outgoingMessageBottomLabelAlignment = LabelAlignment(textAlignment: .right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8))
        incomingMessageBottomLabelAlignment = LabelAlignment(textAlignment: .left, textInsets:  UIEdgeInsets(top: 0, left: 34, bottom: 0, right: 0))

    }
    
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        return CGSize(width: 140, height: 40)
    }
}

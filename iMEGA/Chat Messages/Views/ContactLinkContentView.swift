import MEGASDKRepo
import MEGAUIKit
import UIKit

class ContactLinkContentView: UIView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageViewContainer: UIView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    var message: MEGAChatMessage? {
        didSet {
            configureView()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        updateAppearance(with: traitCollection)
    }
    
    private func updateAppearance(with trait: UITraitCollection) {
        backgroundColor = .mnz_chatRichLinkContentBubble(trait)
        titleLabel.textColor = UIColor.label
        descriptionLabel.textColor = UIColor.mnz_subtitles(for: trait)
    }
    
    func configureView() {
        guard let message = message else { return }
        
        titleLabel.text = message.richTitle
        descriptionLabel.text = message.richString
        
        imageView.image = UIImage.mnz_image(forUserHandle: message.userHandle, 
                                            name: message.richString ?? "",
                                            size: CGSize(width: 40, height: 40),
                                            delegate: RequestDelegate { [weak self] result in
            guard let self else { return }
            
            if case .failure = result {
                self.imageView.isHidden = true
            }
        })
        
        if imageView.image != nil {
            self.imageView.layer.cornerRadius = imageView.frame.size.height / 2
            self.imageView.clipsToBounds = true
        }
    }
    
    func showLoading() {
        activityIndicatorView.isHidden = false
        activityIndicatorView.startAnimating()
    }
    
    func hideLoading() {
        activityIndicatorView.stopAnimating()
        activityIndicatorView.isHidden = true
    }
}

extension ContactLinkContentView: TraitEnvironmentAware {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        traitCollectionChanged(to: traitCollection, from: previousTraitCollection)
    }

    func colorAppearanceDidChange(to currentTrait: UITraitCollection, from previousTrait: UITraitCollection?) {
        updateAppearance(with: currentTrait)
    }
}

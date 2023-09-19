import MEGAL10n
import UIKit

class GetLinkStringTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var rightImageView: UIImageView!

    var viewModel: GetLinkStringCellViewModel? {
        didSet {
            viewModel?.invokeCommand = { [weak self] in
                self?.executeCommand($0)
            }
            viewModel?.dispatch(.onViewReady)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel = nil
    }
    
    func configureLinkCell(link: String) {
        nameLabel.text = link
        leftImageView.image = Asset.Images.GetLinkView.linkGetLink.image
        rightImageView.isHidden = true
        configureAccessibility(value: link)
    }
    
    func configureKeyCell(key: String) {
        nameLabel.text = key
        leftImageView.image = Asset.Images.Generic.iconKeyOnly.image
        rightImageView.isHidden = true
        configureAccessibility(value: key)
    }
    
    func configureAccessibility(value: String) {
        accessibilityIdentifier = "GetLink.TableView.LinkSection.LinkCell"
        accessibilityTraits = [.link]
        accessibilityLabel = Strings.Localizable.tapToCopy
        accessibilityValue = value
    }
    
    @MainActor
    private func executeCommand(_ command: GetLinkStringCellViewModel.Command) {
        switch command {
        case .configView(let title, let leftImage, let isRightImageViewHidden):
            nameLabel.text = title
            leftImageView.image = leftImage
            rightImageView.isHidden = isRightImageViewHidden
        }
    }
}

import MEGADesignToken
import MEGAL10n
import UIKit

class DocScannerActionTableViewCell: UITableViewCell {
    @IBOutlet weak var actionImageView: UIImageView!
    @IBOutlet weak var actionLabel: UILabel!

    enum CellType: Int {
        case upload
        case sendMessage
    }
    
    var cellType: CellType = .upload {
        didSet {
            configure()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = TokenColors.Background.page
        actionLabel.textColor = TokenColors.Text.primary
    }
    
    private func configure() {
        switch cellType {
        case .upload:
            actionImageView.image = UIImage.upload
            actionLabel.text = Strings.Localizable.uploadToMega
        case .sendMessage:
            actionImageView.tintColor = .mnz_primaryGray()
            actionImageView.image = UIImage.sendToChat
            actionLabel.text = Strings.Localizable.General.sendToChat
        }
    }
}

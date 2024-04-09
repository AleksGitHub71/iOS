import MEGADesignToken
import UIKit

final class PlaylistHeaderFooterView: UITableViewHeaderFooterView {
    
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        updateAppearance()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        updateAppearance()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
        }
    }
    
    func configure(title: String) {
        typeLabel.text = title
    }
    
    // MARK: - Private functions
    private func updateAppearance() {
        if UIColor.isDesignTokenEnabled() {
            typeLabel.textColor = TokenColors.Text.primary
            contentView.backgroundColor = TokenColors.Background.page
            separatorView.backgroundColor = TokenColors.Border.strong
        } else {
            typeLabel.textColor = UIColor.mnz_green00A886()
            contentView.backgroundColor = UIColor.mnz_backgroundElevated(traitCollection)
            separatorView.backgroundColor = UIColor.mnz_gray3C3C43().withAlphaComponent(0.29)
        }
    }
}

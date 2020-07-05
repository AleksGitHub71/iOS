
protocol MessageOptionItemTableCellDelegate: class {
    func setImageView(_ imageView: UIImageView, forIndex index: Int)
    func setLabel(_ label: UILabel, forIndex index: Int)
}

class MessageOptionItemTableCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var optionItemImageView: UIImageView!
    @IBOutlet weak var seperatorView: UIView!
    
    var index: Int = -1
    weak var delegate: MessageOptionItemTableCellDelegate? {
        didSet {
            guard let delegate = delegate else {
                return
            }

            delegate.setLabel(titleLabel, forIndex: index)
            delegate.setImageView(optionItemImageView, forIndex: index)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        updateAppearance()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        index = -1
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *),
            traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        seperatorView.backgroundColor = UIColor.mnz_separator(for: traitCollection)
        backgroundColor = UIColor.mnz_backgroundElevated(traitCollection)
    }
    
    
}

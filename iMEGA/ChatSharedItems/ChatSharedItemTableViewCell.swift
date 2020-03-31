
import UIKit

class ChatSharedItemTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbnailImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var ownerNameLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var moreButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        selectedBackgroundView = UIView()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
    
        self.moreButton.isHidden = editing;
                
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.separatorInset = UIEdgeInsets(top: 0, left: CGFloat(editing ? 100 : 60), bottom: 0, right: 0)
            self?.layoutIfNeeded()
        }
    }
    
    func configure(for node:MEGANode, owner: String) {
        nameLabel.text = node.name
        ownerNameLabel.text = owner
        infoLabel.text = Helper.sizeAndDate(for: node, api: MEGASdkManager.sharedMEGASdk())
        if node.hasThumbnail() {
            let thumbnailFilePath = Helper.path(for: node, inSharedSandboxCacheDirectory: "thumbnailsV3")
            if FileManager.default.fileExists(atPath: thumbnailFilePath) {
                thumbnailImage.image = UIImage(contentsOfFile: thumbnailFilePath)
            } else {
                MEGASdkManager.sharedMEGASdk()?.getThumbnailNode(node, destinationFilePath: thumbnailFilePath, delegate: MEGAGetThumbnailRequestDelegate.init(completion: { [weak self] request in
                    if request.nodeHandle == node.handle {
                        self?.thumbnailImage.image = UIImage(contentsOfFile: request.file)
                    }
                }))
            }
        } else {
            thumbnailImage.mnz_image(for: node)
        }
    }
    
    @IBAction func moreButtonTapped(_ sender: Any) {
        print("tapped more button")
    }
}

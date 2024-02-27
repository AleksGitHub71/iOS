import MEGAAssets
import MEGADomain
import SwiftUI

struct VideoCellTitleText: View {
    
    let videoConfig: VideoConfig
    let title: String
    let labelImage: UIImage?
    
    var body: some View {
        VideoCellTitleTextRepresentable(
            text: title,
            labelImage: labelImage,
            foregroundColor: UIColor(videoConfig.colorAssets.primaryTextColor),
            backgroundColor: UIColor(videoConfig.colorAssets.pageBackgroundColor)
        )
    }
}

#Preview {
    VideoCellTitleText(
        videoConfig: .preview,
        title: "This a short text",
        labelImage: MEGAAssetsPreviewImageProvider.image(named: "RedSmall")!
    )
}

#Preview {
    VideoCellTitleText(
        videoConfig: .preview,
        title: "This is a long long long text that needs second line probabaly line probabaly",
        labelImage: MEGAAssetsPreviewImageProvider.image(named: "RedSmall")!
    )
}

/// A UIViewRepresentable to display the title of a video cell.
/// Unfortunately, `SwiftUI.Text` does not render `NSAttachment`when using `AttributedString`. So this component is needed.
/// This view is used to display the title of a video cell.that contains specific rule :
/// - The title is displayed with a maximum of 2 lines.
/// - Always display labelImage if any after the end of the text.
private struct VideoCellTitleTextRepresentable: UIViewRepresentable {
    private var text: String
    private var labelImage: UIImage?
    private var foregroundColor: UIColor
    private var backgroundColor: UIColor
    
    init(
        text: String,
        labelImage: UIImage?,
        foregroundColor: UIColor,
        backgroundColor: UIColor
    ) {
        self.text = text
        self.labelImage = labelImage
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView: UITextView = if #available(iOS 16, *) { UITextView() } else { iOS15SupportTextView() }
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainer.maximumNumberOfLines = 2
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        removeContentInset(of: textView)
        return textView
    }
    
    private func removeContentInset(of textView: UITextView) {
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = createAttributedTitle()
    }
    
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let proposedSize = proposal.replacingUnspecifiedDimensions(by: .init(
            width: CGFloat.greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude))
        
        return uiView.sizeThatFits(proposedSize)
    }
    
    private func createAttributedTitle() -> NSAttributedString {
        let attributedTitle = NSMutableAttributedString(string: text, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: foregroundColor,
            .backgroundColor: backgroundColor
        ])
        
        if let labelImage {
            let label = createImageAttachmentWithPadding(by: labelImage)
            attributedTitle.append(label)
        }
        
        return attributedTitle
    }
    
    private func createImageAttachmentWithPadding(by image: UIImage, leadingPadding: Double = 4) -> NSAttributedString {
        let attachmentString = NSMutableAttributedString()
        if leadingPadding > 0 {
            let space = createSpace(leadingPadding)
            attachmentString.append(space)
        }
        let imageAttachment = createImageAttachment(by: image)
        attachmentString.append(imageAttachment)
        return attachmentString
    }
    
    private func createSpace(_ width: Double = 4) -> NSAttributedString {
        let spaceAttachment = NSTextAttachment()
        spaceAttachment.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        return NSAttributedString(attachment: spaceAttachment)
    }
    
    private func createImageAttachment(by image: UIImage) -> NSAttributedString {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = image
        imageAttachment.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
        return NSAttributedString(attachment: imageAttachment)
    }
}

private class iOS15SupportTextView: UITextView {
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        
        guard superview?.frame != .zero else {
            return
        }
        
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: CGSize {
        var sizeToFit = super.superview?.frame.size ?? super.intrinsicContentSize
        sizeToFit.height = .greatestFiniteMagnitude
        return sizeThatFits(sizeToFit)
    }
}

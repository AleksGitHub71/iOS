import MEGADesignToken
import MEGAUI
import UIKit

final class NodeDescriptionTextContentView: UIView, UIContentView {
    var configuration: any UIContentConfiguration
    private let textView = UITextView()
    private let viewModel: NodeDescriptionTextContentViewModel

    init(
        configuration: some UIContentConfiguration,
        viewModel: NodeDescriptionTextContentViewModel
    ) {
        self.configuration = configuration
        self.viewModel = viewModel

        super.init(frame: .zero)

        configure(editingDisabled: viewModel.editingDisabled)
        wrap(textView, edgeInsets: viewModel.textViewEdgeInsets)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(editingDisabled: Bool) {
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = false
        textView.returnKeyType = .done
        textView.delegate = self
        textView.isEditable = !editingDisabled

        if let configuration = nodeDescriptionConfiguration() {
            textView.text = configuration.description.text
            textView.textColor = textColor(isPlaceholderText: configuration.description.isPlaceholder)
        }
    }

    private func textColor(isPlaceholderText: Bool) -> UIColor {
        UIColor.isDesignTokenEnabled()
        ? isPlaceholderText ? TokenColors.Text.secondary : TokenColors.Text.primary
        : isPlaceholderText ? UIColor.secondaryLabel : UIColor.label
    }

    private func nodeDescriptionConfiguration() -> NodeDescriptionContentConfiguration? {
        guard let configuration = configuration as? NodeDescriptionContentConfiguration else { return nil }
        return configuration
    }
}

extension NodeDescriptionTextContentView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if let configuration = nodeDescriptionConfiguration(), configuration.description.isPlaceholder {
            textView.text = nil
            textView.textColor = textColor(isPlaceholderText: false)
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if let configuration = nodeDescriptionConfiguration(), configuration.description.isPlaceholder {
            textView.text = configuration.description.text
            textView.textColor = textColor(isPlaceholderText: true)
        }
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        let textViewText = textView.text ?? ""
        guard viewModel.shouldEndEditing(for: text) == false else {
            textView.endEditing(true)
            viewModel.saveDescription(textViewText)
            return false
        }

        guard viewModel.shouldChangeTextIn(in: range, currentText: textViewText, replacementText: text) else {
            let replacementText = viewModel.truncateAndReplaceText(in: range, of: textViewText, with: text)
            textView.text = replacementText ?? textViewText
            return false
        }

        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        viewModel.descriptionUpdated(textView.text)
    }
}

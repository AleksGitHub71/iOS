import UIKit

final class SegmentTitleView: UIView {

    struct SegmentTitleViewModel {
        struct Title {
            let text: String
            let index: Int
        }

        let titles: [Title]
    }

    private var buttons: [UIButton] = []

    private var horizontalStackContainer: UIStackView?

    private var model: SegmentTitleViewModel?

    var selectAction: ((SegmentTitleViewModel.Title) -> Void)?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView(with: traitCollection)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView(with: traitCollection)
    }

    // MARK: - Public Interface

    func setSegmentTitleViewModel(model: SegmentTitleViewModel) {
        self.model = model
        setTitles(model.titles)
    }

    private func setTitles(_ titles: [SegmentTitleViewModel.Title]) {
        let titleButtonStyler = traitCollection.theme.buttonStyle.styler(of: .segmentTitleButton)
        let buttons: [UIButton] = titles.enumerated().map { index, title in
            let button = UIButton(type: .custom)
            button.setTitle(title.text, for: .normal)
            button.tag = title.index
            if index == 0 { button.isSelected = true }
            button.addTarget(self, action: #selector(didTap(button:)), for: .touchUpInside)
            titleButtonStyler(button)
            button.widthAnchor.constraint(
                equalToConstant: button.intrinsicContentSize.width + Constants.reservedWidthForLargeFont
            ).isActive = true
            return button
        }

        self.buttons = buttons
        horizontalStackContainer = createStackView(with: buttons)
    }

    private func setSelected(at index: Int, of buttons: [UIButton]) {
        deselect(buttons: buttons)
        select(index: index, in: buttons)
    }

    private func deselect(buttons: [UIButton]) {
        buttons.forEach { $0.isSelected = false }
    }

    private func select(index: Int, in buttons: [UIButton]) {
        guard index < buttons.count else { return }
        buttons[index].isSelected = true
    }

    // MARK: - Actions

    @objc private func didTap(button: UIButton) {
        guard let index = buttons.firstIndex(of: button) else { return }
        setSelected(at: index, of: buttons)
        let titleButtonStyler = traitCollection.theme.buttonStyle.styler(of: .segmentTitleButton)
        buttons.forEach(titleButtonStyler)

        if let titles = model?.titles {
            selectAction?(titles[index])
        }
    }

    // MARK: - View Setup

    private func setupView(with trait: UITraitCollection) {
        updateView(with: trait)
    }

    private func updateView(with trait: UITraitCollection) {
        updateButtons(buttons, withTrait: trait)
    }

    private func updateButtons(_ buttons: [UIButton], withTrait trait: UITraitCollection) {
        let styleTitleButton = traitCollection.theme.buttonStyle.styler(of: .segmentTitleButton)
        buttons.forEach(styleTitleButton)

        switch trait.theme {
        case .dark: backgroundColor = .mnz_black1C1C1E()
        case .light: backgroundColor = .white
        }
    }

    private func createStackView(with buttons: [UIView]) -> UIStackView {
        let horizontalStackContainer = (buttons).embedInStackView(
            axis: .horizontal,
            distribution: .fill,
            spacing: Constants.spacingBetweenButtons
        )
        pinStackView(horizontalStackContainer)
        return horizontalStackContainer
    }

    private func pinStackView(_ stackView: UIStackView) {
        stackView.configureForAutoLayout()
        addSubview(stackView)
        stackView.autoPinEdge(toSuperviewMargin: .leading, withInset: Constants.stackViewInset)
        stackView.autoPinEdge(toSuperviewEdge: .top)
    }

    private enum Constants {
        static let spacingBetweenButtons: CGFloat = 8
        static let stackViewInset: CGFloat = 16
        static let reservedWidthForLargeFont: CGFloat = 20
    }
}

// MARK: - TraitEnviromentAware

extension SegmentTitleView: TraitEnviromentAware {

    func colorAppearanceDidChange(to currentTrait: UITraitCollection, from previousTrait: UITraitCollection?) {
        updateView(with: currentTrait)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        colorAppearanceDidChange(to: traitCollection, from: previousTraitCollection)
    }
}

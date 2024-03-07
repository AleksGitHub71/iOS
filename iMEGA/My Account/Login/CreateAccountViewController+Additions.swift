import MEGADesignToken
import MEGAL10n

extension CreateAccountViewController {
    
    // MARK: - Login
    @objc func setLoginAttributedText() {
        let font = UIFont.mnz_preferredFont(withStyle: .caption1, weight: .regular)
        let accountAttributedString = NSMutableAttributedString(string: Strings.Localizable.Account.CreateAccount.alreadyHaveAnAccount,
                                                                attributes: [NSAttributedString.Key.foregroundColor: termPrimaryTextColor(),
                                                                             NSAttributedString.Key.font: font])
        let loginAttributedString = NSAttributedString(string: Strings.Localizable.login,
                                                       attributes: [NSAttributedString.Key.foregroundColor: termLinkTextColor(),
                                                                    NSAttributedString.Key.font: font])
        accountAttributedString.append(NSAttributedString(string: " "))
        accountAttributedString.append(loginAttributedString)
        loginLabel.attributedText = accountAttributedString
    }
    
    @objc func didTapLogin() {
        self.dismiss(animated: true) {
            if let onboardingVC = UIApplication.mnz_visibleViewController() as? OnboardingViewController {
                onboardingVC.presentLoginViewController()
            }
        }
    }
    
    @objc func setUpCheckBoxButton() {
        if UIColor.isDesignTokenEnabled() {
            termsCheckboxButton.setImage(UIImage.checkBoxSelectedSemantic, for: .selected)
            termsForLosingPasswordCheckboxButton.setImage(UIImage.checkBoxSelectedSemantic, for: .selected)
        }
    }
    
    @objc func termPrimaryTextColor() -> UIColor {
        UIColor.isDesignTokenEnabled() ? TokenColors.Text.primary : UIColor.mnz_primaryGray(for: traitCollection)
    }
    
    @objc func termLinkTextColor() -> UIColor {
        UIColor.isDesignTokenEnabled() ? TokenColors.Link.primary : UIColor.mnz_turquoise(for: self.traitCollection)
    }
    
    @objc func passwordStrengthBackgroundColor() -> UIColor {
        UIColor.isDesignTokenEnabled() ? TokenColors.Background.page : UIColor.mnz_tertiaryBackground(traitCollection)
    }
}

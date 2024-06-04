import MEGADesignToken

@objc enum MEGACustomButtonStyle: Int {
    case none
    case basic
    case primary
    case secondary
    case primaryDisabled
    case destructive
    case cancel
    case delete
}

extension UIButton {
    
    @objc func mnz_setup(_ style: MEGACustomButtonStyle, traitCollection: UITraitCollection) {
        switch style {
        case .basic:
            mnz_setupBasic(traitCollection)
            
        case .primary:
            mnz_setupPrimary(traitCollection)
            
        case .secondary:
            mnz_setupSecondary(traitCollection)
            
        case .primaryDisabled:
            mnz_setupPrimary_disabled(traitCollection)
            
        case .destructive:
            mnz_setupDestructive(traitCollection)
            
        case .cancel:
            mnz_setupCancel(traitCollection)
        
        case .delete:
            mnz_setupDelete(traitCollection)
            
        default:
            mnz_setupBasic(traitCollection)
        }
    }
    
    // MARK: - Buttons
    
    @objc func mnz_setupBasic(_ traitCollection: UITraitCollection) {
        backgroundColor = UIColor.mnz_basicButton(for: traitCollection)
        setTitleColor(UIColor.mnz_turquoise(for: traitCollection), for: UIControl.State.normal)
        
        setupLayer()
    }
    
    @objc func mnz_setupPrimary(_ traitCollection: UITraitCollection) {
        if UIColor.isDesignTokenEnabled() {
            backgroundColor = TokenColors.Button.primary
            setTitleColor(TokenColors.Text.inverse, for: UIControl.State.normal)
        } else {
            backgroundColor = UIColor.mnz_turquoise(for: traitCollection)
            setTitleColor(UIColor.whiteFFFFFF, for: UIControl.State.normal)
        }
        
        setupLayer()
    }
    
    @objc func mnz_setupSecondary(_ traitCollection: UITraitCollection) {
        if UIColor.isDesignTokenEnabled() {
            backgroundColor = TokenColors.Button.secondary
            setTitleColor(TokenColors.Text.accent, for: UIControl.State.normal)
        } else {
            backgroundColor = UIColor.mnz_basicButton(for: traitCollection)
            setTitleColor(UIColor.mnz_turquoise(for: traitCollection), for: UIControl.State.normal)
        }
        
        setupLayer()
    }
    
    @objc func mnz_setupPrimary_disabled(_ traitCollection: UITraitCollection) {
        if UIColor.isDesignTokenEnabled() {
            backgroundColor = TokenColors.Button.disabled
            setTitleColor(TokenColors.Text.inverseAccent, for: UIControl.State.normal)
        } else {
            var darkMode = false
            if traitCollection.userInterfaceStyle == .dark {
                darkMode = true
            }
            backgroundColor = UIColor.mnz_turquoise(for: traitCollection).withAlphaComponent(darkMode ? 0.2 : 0.3)
            setTitleColor(MEGAAppColor.White._FFFFFF.uiColor.withAlphaComponent(darkMode ? 0.2 : 0.7), for: UIControl.State.normal)
        }
        
        setupLayer()
    }
    
    @objc func mnz_setupDestructive(_ traitCollection: UITraitCollection) {
        backgroundColor = UIColor.mnz_basicButton(for: traitCollection)
        setTitleColor(UIColor.mnz_red(for: traitCollection), for: UIControl.State.normal)
        
        setupLayer()
    }
    
    @objc func mnz_setupDelete(_ traitCollection: UITraitCollection) {
        backgroundColor = UIColor.mnz_red(for: traitCollection)
        setTitleColor(MEGAAppColor.White._FFFFFF.uiColor, for: UIControl.State.normal)
        
        setupLayer()
    }
    
    @objc func mnz_setupCancel(_ traitCollection: UITraitCollection) {
        backgroundColor = UIColor.clear
        setTitleColor(UIColor.mnz_secondaryGray(for: traitCollection), for: UIControl.State.normal)
    }
    
    @objc func mnz_clearSetup() {
        backgroundColor = UIColor.clear
        
        removeLayer()
    }
    
    // MARK: - Private
    
    private func setupLayer() {
        layer.cornerRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 3
        layer.shadowColor = UIColor.black000000.cgColor
    }
    
    private func removeLayer() {
        layer.cornerRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.shadowColor = UIColor.clear.cgColor
    }
}

import MEGADesignToken
import MEGADomain
import MEGAL10n
import MEGASDKRepo

extension UsageViewController {
    private func setupTokenColors() {
        view.backgroundColor = TokenColors.Background.page
        pieChartView?.backgroundColor = TokenColors.Background.page
        usageStorageView?.backgroundColor = TokenColors.Background.page

        [cloudDriveLabel, backupsLabel, rubbishBinLabel, incomingSharesLabel].forEach { label in
            label?.textColor = TokenColors.Text.primary
        }

        [cloudDriveSizeLabel, backupsSizeLabel, rubbishBinSizeLabel, incomingSharesSizeLabel, usageTitleLabel].forEach { label in
            label?.textColor = TokenColors.Text.secondary
        }

        pieChartSecondaryLabel?.textColor = TokenColors.Text.primary
        pieChartTertiaryLabel?.textColor = TokenColors.Text.secondary

        usagePageControl?.currentPageIndicatorTintColor = TokenColors.Background.surface3
        usagePageControl?.pageIndicatorTintColor = TokenColors.Background.surface2

        [usageBottomSeparatorView, cloudDriveBottomSeparatorView, backupsBottomSeparatorView, rubbishBinBottomSeparatorView, incomingSharesBottomSeparatorView].forEach { view in
            view?.backgroundColor = TokenColors.Border.strong
        }

        usageSizeLabel?.textColor = TokenColors.Text.accent
    }
    
    private func setupColors() {
        view.backgroundColor = UIColor.systemBackground
        pieChartView?.backgroundColor = UIColor.systemBackground
        usageStorageView?.backgroundColor = UIColor.systemBackground

        let primaryTextColor = UIColor.mnz_primaryTextColor()
        let secondaryTextColor = UIColor.mnz_secondaryGray(for: traitCollection)

        [cloudDriveLabel, backupsLabel, rubbishBinLabel, incomingSharesLabel].forEach { label in
            label?.textColor = primaryTextColor
        }

        [cloudDriveSizeLabel, backupsSizeLabel, rubbishBinSizeLabel, incomingSharesSizeLabel, usageTitleLabel].forEach { label in
            label?.textColor = secondaryTextColor
        }

        pieChartSecondaryLabel?.textColor = UIColor.mnz_primaryGray(for: traitCollection)
        pieChartTertiaryLabel?.textColor = secondaryTextColor

        usagePageControl?.currentPageIndicatorTintColor = UIColor.mnz_turquoise(for: traitCollection)
        usagePageControl?.pageIndicatorTintColor = UIColor.mnz_secondaryGray(for: traitCollection)

        let separatorColor = UIColor.mnz_separator(for: traitCollection)
        [usageBottomSeparatorView, cloudDriveBottomSeparatorView, backupsBottomSeparatorView, rubbishBinBottomSeparatorView, incomingSharesBottomSeparatorView].forEach { view in
            view?.backgroundColor = separatorColor
        }
        
        usageSizeLabel?.textColor = UIColor.mnz_turquoise(for: traitCollection)
    }
    
    @objc func colorForSlice(at index: Int) -> UIColor {
        switch index {
        case 0: // Storage / Transfer Quota
            colorForPage(usagePageControl?.currentPage ?? 0, isDesignTokenEnabled: UIColor.isDesignTokenEnabled(), traitCollection: traitCollection)
        default: // Available storage/quota or default
            availableStorageColor(isDesignTokenEnabled: UIColor.isDesignTokenEnabled(), traitCollection: traitCollection)
        }
    }
    
    @objc func colorForPage(_ currentPage: Int, isDesignTokenEnabled: Bool, traitCollection: UITraitCollection) -> UIColor {
        guard isFull(currentPage: currentPage) else {
            return isDesignTokenEnabled ? TokenColors.Support.success : UIColor.mnz_turquoise(for: traitCollection)
        }
        return isDesignTokenEnabled ? TokenColors.Support.error : UIColor.mnz_red(for: traitCollection)
    }
    
    private func availableStorageColor(isDesignTokenEnabled: Bool, traitCollection: UITraitCollection) -> UIColor {
        isDesignTokenEnabled ? TokenColors.Border.strong : UIColor.mnz_tertiaryGray(for: traitCollection)
    }
    
    @objc func updateAppearance() {
        UIColor.isDesignTokenEnabled() ? setupTokenColors() : setupColors()
        
        pieChartMainLabel?.textColor = colorForPage(
            usagePageControl?.currentPage ?? 0,
            isDesignTokenEnabled: UIColor.isDesignTokenEnabled(),
            traitCollection: traitCollection
        )
        
        pieChartView?.reloadData()
    }
    
    private func startAnimating(_ activityIndicator: UIActivityIndicatorView?) {
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimating()
    }
    
    private func stopAnimating(_ activityIndicator: UIActivityIndicatorView?) {
        activityIndicator?.stopAnimating()
        activityIndicator?.isHidden = true
    }
    
    @objc func initialiseStorageInfo() {
        viewModel?.dispatch(.loadRootNodeStorage)
        viewModel?.dispatch(.loadBackupStorage)
        viewModel?.dispatch(.loadRubbishBinStorage)
        viewModel?.dispatch(.loadIncomingSharedStorage)
        viewModel?.dispatch(.loadStorageDetails)
        viewModel?.dispatch(.loadTransferDetails)
    }
    
    @objc func configView() {
        numberFormatter = NumberFormatter()
        numberFormatter?.numberStyle = .none
        numberFormatter?.roundingMode = .floor
        numberFormatter?.locale = .current

        cloudDriveLabel?.text = Strings.Localizable.cloudDrive
        backupsLabel?.text = Strings.Localizable.Backups.title
        rubbishBinLabel?.text = Strings.Localizable.rubbishBinLabel
        incomingSharesLabel?.text = Strings.Localizable.incomingShares
        
        usagePageControl?.numberOfPages = showTransferQuota ? 2 : 0
    }
    
    var isShowPieChartView: Bool {
        guard let viewModel else { return true }
        return !(viewModel.isBusinessAccount || viewModel.isProFlexiAccount)
    }
    
    @objc var showTransferQuota: Bool {
        guard let viewModel else { return false }
        // Transfer Quota should be hidden on free accounts due to
        // different transfer limits in different countries and also it is subject to change.
        return !viewModel.isFreeAccount
    }
    
    @objc func configStorageContentView() {
        let isShowPieChartView = isShowPieChartView
        pieChartView?.isHidden = !isShowPieChartView
        usageStorageView?.isHidden = isShowPieChartView

        isShowPieChartView ? setUpPieChartView() : setUsageViewContent()
    }
    
    @objc func reloadStorageContentView(forPage page: Int) {
        isShowPieChartView ? reloadPieChart(page): setUsageViewContent(forPage: page)
    }
    
    @objc func setUsageViewContent(forPage page: Int = 0) {
        switch page {
        case 0:
            usageTitleLabel?.text = Strings.Localizable.Account.Storage.StorageUsed.title
            guard usedStorage != 0 else {
                usageSizeLabel?.text = "-"
                return
            }
            usageSizeLabel?.text = String.memoryStyleString(fromByteCount: usedStorage)
            
        case 1:
            usageTitleLabel?.text = Strings.Localizable.Account.Storage.TransferUsed.title
            guard transferUsed != 0 else {
                usageSizeLabel?.text = "-"
                return
            }
            usageSizeLabel?.text = String.memoryStyleString(fromByteCount: transferUsed)
            
        default: return
        }
    }
    
    private func isStorageFull() -> Bool {
        usedStorage >= maxStorage
    }
    
    private func isTransferFull() -> Bool {
        transferUsed >= transferMax
    }
    
    private func isFull(currentPage: Int) -> Bool {
        currentPage == 0 ? isStorageFull() : isTransferFull()
    }
    
    private func updatedPage(forGesture gesture: UIGestureRecognizer, currentPage: Int) -> Int? {
        var page = currentPage

        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            if (swipeGesture.direction == .left && (page == 1 || !showTransferQuota)) ||
               (swipeGesture.direction == .right && page == 0) {
                return nil
            }
            
            switch swipeGesture.direction {
            case .left: page += 1
            case .right: page -= 1
            default: return nil
            }
        } else if gesture is UITapGestureRecognizer {
            if page == 1 {
                page = 0
            } else {
                guard showTransferQuota else {
                    return nil
                }
                page += 1
            }
        } else {
            return nil
        }

        return page
    }
    
    @objc func handleGesture(_ gesture: UIGestureRecognizer) {
        guard let updatedPage = updatedPage(forGesture: gesture, currentPage: usagePageControl?.currentPage ?? 0) else { return }
        usagePageControl?.currentPage = updatedPage
        reloadStorageContentView(forPage: updatedPage)
    }
    
    @objc func setUpInvokeCommands() {
        viewModel?.invokeCommand = { [weak self] in
            self?.executeCommand($0)
        }
    }
    
    private func executeCommand(_ command: UsageViewModel.Command) {
        switch command {
        case .loaded(let storageType, let size):
            switch storageType {
            case .cloud:
                cloudDriveSizeLabel?.text = text(forSizeLabels: size)
                stopAnimating(cloudDriveActivityIndicator)
            case .backups:
                backupsSizeLabel?.text = text(forSizeLabels: size)
                stopAnimating(backupsActivityIndicator)
            case .rubbishBin:
                rubbishBinSizeLabel?.text = text(forSizeLabels: size)
                stopAnimating(rubbishBinActivityIndicator)
            case .incomingShares:
                incomingSharesSizeLabel?.text = text(forSizeLabels: size)
                stopAnimating(incomingSharesActivityIndicator)
            }
            reloadCurrentPage()
            
        case .loadedStorage(let used, let max):
            usedStorage = used
            maxStorage = max
            reloadCurrentPage()
            
        case .loadedTransfer(let used, let max):
            transferUsed = used
            transferMax = max
            reloadCurrentPage()
            
        case .startLoading(let storageType):
            switch storageType {
            case .cloud: startAnimating(cloudDriveActivityIndicator)
            case .backups: startAnimating(backupsActivityIndicator)
            case .rubbishBin: startAnimating(rubbishBinActivityIndicator)
            case .incomingShares: startAnimating(incomingSharesActivityIndicator)
            }
        }
    }
    
    private func reloadCurrentPage() {
        guard let currentPage = usagePageControl?.currentPage else { return }
        reloadStorageContentView(forPage: currentPage)
    }
}

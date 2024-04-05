import Accounts
import Combine
import MEGADomain
import MEGASDKRepo

extension MainTabBarController: AdsSlotViewControllerProtocol {
    public var adsSlotPublisher: AnyPublisher<AdsSlotConfig?, Never> {
        mainTabBarAdsViewModel.adsSlotConfigPublisher
    }
    
    @objc func configureAdsVisibility() {
        mainTabBarAdsViewModel.sendNewAdsConfig(currentAdsSlotConfig())
    }
    
    private func currentAdsSlotConfig() -> AdsSlotConfig? {
        switch selectedIndex {
        case TabType.cloudDrive.rawValue:
            if let adsDipslayable = mainTabBarTopViewController() as? any CloudDriveAdsSlotDisplayable {
                return AdsSlotConfig(
                    adsSlot: .files,
                    displayAds: adsDipslayable.shouldDisplayAdsSlot,
                    isAdsCookieEnabled: calculateAdCookieStatus
                )
            }
            
            return AdsSlotConfig(
                adsSlot: .files,
                displayAds: false,
                isAdsCookieEnabled: calculateAdCookieStatus
            )
        case TabType.cameraUploads.rawValue:
            return AdsSlotConfig(
                adsSlot: .photos,
                displayAds: isVisibleController(type: PhotoAlbumContainerViewController.self), 
                isAdsCookieEnabled: calculateAdCookieStatus
            )
            
        case TabType.home.rawValue:
            return AdsSlotConfig(
                adsSlot: .home,
                displayAds: isVisibleController(type: HomeViewController.self), 
                isAdsCookieEnabled: calculateAdCookieStatus
            )
            
        case TabType.chat.rawValue, TabType.sharedItems.rawValue:
            return nil
            
        default:
            return nil
        }
    }
    
    private func isVisibleController<T: UIViewController>(type viewControllerType: T.Type) -> Bool {
        guard let topViewController = mainTabBarTopViewController() else { return false }
        return topViewController.isKind(of: viewControllerType)
    }
    
    private func mainTabBarTopViewController() -> UIViewController? {
        guard let selectedNavController = selectedViewController as? UINavigationController,
              let topViewController = selectedNavController.topViewController else {
            return nil
        }
        return topViewController
    }
    
    private func calculateAdCookieStatus() async -> Bool {
        do {
            let cookieSettingsUseCase = CookieSettingsUseCase(repository: CookieSettingsRepository.newRepo)
            let bitmap = try await cookieSettingsUseCase.cookieSettings()
            
            let cookiesBitmap = CookiesBitmap(rawValue: bitmap)
            return cookiesBitmap.contains(.ads) && cookiesBitmap.contains(.adsCheckCookie)
        } catch {
            return false
        }
    }
}

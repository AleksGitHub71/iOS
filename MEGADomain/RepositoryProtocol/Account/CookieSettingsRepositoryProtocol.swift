
import Foundation

protocol CookieSettingsRepositoryProtocol {
    func cookieBannerEnabled() -> Bool
    
    func cookieSettings(completion: @escaping (Result<Int, CookieSettingsErrorEntity>) -> Void)
    
    func setCookieSettings(with settings: Int, completion: @escaping (Result<Int, CookieSettingsErrorEntity>) -> Void)
    
    func setCrashlyticsEnabled(_ bool: Bool) -> Void
}

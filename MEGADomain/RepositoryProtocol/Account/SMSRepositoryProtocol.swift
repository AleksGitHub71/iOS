import Foundation

protocol SMSRepositoryProtocol {
    func verifiedPhoneNumber() -> String?
    func getRegionCallingCodes(completion: @escaping (Result<[RegionEntity], GetSMSErrorEntity>) -> Void)
    func checkVerificationCode(_ code: String, completion: @escaping (Result<String, CheckSMSErrorEntity>) -> Void)
    func sendVerification(toPhoneNumber number: String, completion: @escaping (Result<String, CheckSMSErrorEntity>) -> Void)
    func checkState() -> SMSStateEntity
}

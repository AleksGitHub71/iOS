import XCTest
@testable import MEGA

class MEGAavatarLoadingUseCaseTests: XCTestCase {
    
    // MARK: - Load Cached Avatar
    
    func testUnableLoadRemoteAvatarImage_WhenUserIsNil() {
        let useCaseUT = MEGAavatarUseCase(
            megaAvatarClient: .foundImage,
            avatarFileSystemClient: .foundNil,
            megaUserClient: .foundNil,
            filePathUseCase: MEGAAppGroupFilePathUseCase()
        )
        
        let expectations = expectation(description: "for async load image")
        useCaseUT.loadRemoteAvatarImage(completion: { image in
            XCTAssertNil(image)
            expectations.fulfill()
        })
        wait(for: [expectations], timeout: 0.1)
    }
    
    func testUnableLoadRemoteAvatarImage_WhenSDKFailedLoadingAvatar() {
        let useCaseUT = MEGAavatarUseCase(
            megaAvatarClient: .foundNil,
            avatarFileSystemClient: .foundNil,
            megaUserClient: .foundUser,
            filePathUseCase: MEGAAppGroupFilePathUseCase()
        )
        
        let expectations = expectation(description: "for async load image")
        useCaseUT.loadRemoteAvatarImage(completion: { image in
            XCTAssertNil(image)
            expectations.fulfill()
        })
        wait(for: [expectations], timeout: 0.1)
    }
    
    func testSuccessLoadRemoteAvatarImage() {
        let useCaseUT = MEGAavatarUseCase(
            megaAvatarClient: .foundImage,
            avatarFileSystemClient: .foundNil,
            megaUserClient: .foundUser,
            filePathUseCase: MEGAAppGroupFilePathUseCase()
        )
        
        let expectations = expectation(description: "for async load image")
        useCaseUT.loadRemoteAvatarImage(completion: { image in
            XCTAssertNotNil(image)
            expectations.fulfill()
        })
        wait(for: [expectations], timeout: 0.1)
    }
}

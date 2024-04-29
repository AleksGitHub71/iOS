import Combine
import MEGADomain
import MEGADomainMock
import MEGASDKRepo
import MEGASDKRepoMock
import MEGASwift
import XCTest

@testable import MEGA

final class AccountRepositoryTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()
    
    func testCurrentUserHandle() {
        let expectedHandle = HandleEntity.random()
        
        let sut = makeSUT(sdk: MockSdk(myUser: MockUser(handle: expectedHandle)))
        
        XCTAssertEqual(sut.currentUserHandle, expectedHandle)
    }
    
    func testCurrentUser() async {
        let expectedUser = MockUser(handle: .random())
        
        let sut = makeSUT(sdk: MockSdk(myUser: expectedUser))
        
        let currentUser = await sut.currentUser()
        XCTAssertEqual(currentUser, expectedUser.toUserEntity())
    }
    
    func testIsGuest() {
        func assert(
            whenUserEmail email: String,
            isGuestShouldBe expectedIsGuest: Bool,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(myUser: MockUser(email: email)))
            
            XCTAssertEqual(sut.isGuest, expectedIsGuest, line: line)
        }
        
        assert(whenUserEmail: "", isGuestShouldBe: true)
        assert(whenUserEmail: "any-email@mega.com", isGuestShouldBe: false)
    }
    
    func testIsLoggedIn() {
        XCTAssertTrue(makeSUT(sdk: MockSdk(isLoggedIn: 1)).isLoggedIn())
        XCTAssertFalse(makeSUT(sdk: MockSdk(isLoggedIn: 0)).isLoggedIn())
    }
    
    func testIsMasterBusinessAccount() {
        XCTAssertTrue(makeSUT(sdk: MockSdk(isMasterBusinessAccount: true)).isMasterBusinessAccount)
        XCTAssertFalse(makeSUT(sdk: MockSdk(isMasterBusinessAccount: false)).isMasterBusinessAccount)
    }
    
    func testIsAchievementsEnabled() {
        XCTAssertTrue(makeSUT(sdk: MockSdk(isAchievementsEnabled: true)).isAchievementsEnabled)
        XCTAssertFalse(makeSUT(sdk: MockSdk(isAchievementsEnabled: false)).isAchievementsEnabled)
    }
    
    func testIsNewAccount() {
        XCTAssertTrue(makeSUT(sdk: MockSdk(isNewAccount: true)).isNewAccount)
        XCTAssertFalse(makeSUT(sdk: MockSdk(isNewAccount: false)).isNewAccount)
    }
    
    func testAccountCreationDate_whenNil_shouldReturnNil() {
        let sut = makeSUT(sdk: MockSdk(accountCreationDate: nil))
        XCTAssertNil(sut.accountCreationDate)
    }
    
    func testAccountCreationDate_whenNotNil_shouldReturnValue() {
        let stubbedDate = Date()
        let sut = makeSUT(sdk: MockSdk(accountCreationDate: stubbedDate))
        XCTAssertEqual(sut.accountCreationDate, stubbedDate)
    }
    
    func testContacts_shouldMapSdkContacts() {
        let userStubOne = MockUser()
        let userStubTwo = MockUser()
        let sut = makeSUT(sdk: MockSdk(
            myContacts: MockUserList(users: [userStubOne, userStubTwo])
        ))
        
        XCTAssertEqual(sut.contacts(), [userStubOne.toUserEntity(), userStubTwo.toUserEntity()])
    }
    
    func testBandwidthOverquotaDelay_returnBandwidth() {
        let expectedBandwidth: Int64 = 100
        let sut = makeSUT(sdk: MockSdk(bandwidthOverquotaDelay: expectedBandwidth))
        XCTAssertEqual(sut.bandwidthOverquotaDelay, expectedBandwidth)
    }
    
    func testIncomingContactsRequestCount() {
        func assert(
            whenContactRequestCount expectedCount: Int,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(
                incomingContactRequestList: MockContactRequestList(
                    contactRequests: Array(repeating: MockContactRequest(), count: expectedCount)
                )
            ))
            
            XCTAssertEqual(sut.incomingContactsRequestsCount(), expectedCount, line: line)
        }
        
        assert(whenContactRequestCount: 0)
        assert(whenContactRequestCount: 1)
        assert(whenContactRequestCount: 5)
        assert(whenContactRequestCount: 10)
    }
    
    func testRelevantUnseenUserAlertsCount() {
        func assert(
            whenAlertsInSDK alerts: [MockUserAlert],
            relevantUnseenUserAlertsCount expectedCount: UInt,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(
                userAlertList: MockUserAlertList(alerts: alerts)
            ))
            
            XCTAssertEqual(sut.relevantUnseenUserAlertsCount(), expectedCount, line: line)
        }
        
        assert(whenAlertsInSDK: [], relevantUnseenUserAlertsCount: 0)
        
        assert(
            whenAlertsInSDK: [
                MockUserAlert(isSeen: true, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: false),
                MockUserAlert(isSeen: true, isRelevant: true)
            ],
            relevantUnseenUserAlertsCount: 0
        )
        
        assert(
            whenAlertsInSDK: [
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true)
            ],
            relevantUnseenUserAlertsCount: 3
        )
        
        assert(
            whenAlertsInSDK: [
                MockUserAlert(isSeen: true, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: false),
                MockUserAlert(isSeen: false, isRelevant: true),
                MockUserAlert(isSeen: true, isRelevant: true),
                MockUserAlert(isSeen: false, isRelevant: true)
            ],
            relevantUnseenUserAlertsCount: 3
        )
    }
    
    func testTotalNodesCount() {
        func assert(
            whenNodesCount expectedCount: Int,
            line: UInt = #line
        ) {
            let sut = makeSUT(sdk: MockSdk(
                nodes: Array(repeating: MockNode(handle: .invalidHandle), count: expectedCount)
            ))
            
            XCTAssertEqual(sut.totalNodesCount(), UInt64(expectedCount), line: line)
        }
        
        assert(whenNodesCount: 0)
        assert(whenNodesCount: 1)
        assert(whenNodesCount: 5)
        assert(whenNodesCount: 10)
    }
    
    func testCurrentAccountDetails_shouldReturnCurrentAccountDetails() async {
        let expectedAccountDetails = randomAccountDetails().toAccountDetailsEntity()
        let userSource = CurrentUserSource(sdk: MockSdk())
        let sut = AccountRepository(sdk: MockSdk(), currentUserSource: userSource, myChatFilesFolderNodeAccess: .shared)
        
        userSource.setAccountDetails(expectedAccountDetails)
        XCTAssertEqual(sut.currentAccountDetails, expectedAccountDetails)
    }
    
    func testRefreshCurrentAccountDetails_whenFails_shouldThrowGenericError() async {
        let expectedError = MockError.failingError
        let sut = makeSUT(
            sdk: MockSdk(accountDetails: { sdk, delegate in
                delegate.onRequestFinish?(sdk, request: MockRequest(handle: 1), error: expectedError)
            })
        )
        
        await XCTAsyncAssertThrowsError(try await sut.refreshCurrentAccountDetails()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountDetailsErrorEntity, .generic)
        }
    }
    
    func testRefreshCurrentAccountDetails_whenSuccess_shouldReturnAccountDetails() async throws {
        let expectedAccountDetails = randomAccountDetails()
        let sut = makeSUT(
            sdk: MockSdk(accountDetails: { sdk, delegate in
                delegate.onRequestFinish?(
                    sdk,
                    request: MockRequest(handle: 1, accountDetails: expectedAccountDetails),
                    error: MockError(errorType: .apiOk))
            })
        )
        
        let accountDetails = try await sut.refreshCurrentAccountDetails()
        XCTAssertEqual(accountDetails, expectedAccountDetails.toAccountDetailsEntity())
        XCTAssertEqual(accountDetails, sut.currentAccountDetails)
    }
    
    func testUpgradeSecurity_whenApiOk_shouldNotThrow() async {
        let apiOk = MockError(errorType: .apiOk)
        let sut = makeSUT(
            sdk: MockSdk(upgradeSecurity: { sdk, delegate in
                delegate.onRequestFinish?(sdk, request: MockRequest(handle: 1), error: apiOk)
            })
        )
        
        await XCTAsyncAssertNoThrow(try await sut.upgradeSecurity())
    }
    
    func testUpgradeSecurity_whenFails_shouldThrowGenericError() async {
        let expectedError = MockError.failingError
        let sut = makeSUT(
            sdk: MockSdk(upgradeSecurity: { sdk, delegate in
                delegate.onRequestFinish?(sdk, request: MockRequest(handle: 1), error: expectedError)
            })
        )
        
        await XCTAsyncAssertThrowsError(try await sut.upgradeSecurity()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }
    
    func testRequestResultPublisher_onRequestFinish_whenApiOk_sendsSuccessResult() {
        let apiOk = MockError(errorType: .apiOk)
        let mockSdk = MockSdk()
        let sut = makeSUT(sdk: mockSdk)
        
        let exp = expectation(description: "Should receive success AccountRequestEntity")
        let megaRequest = MEGARequest()
        sut.requestResultPublisher
            .sink { request in
                switch request {
                case .success(let result):
                    XCTAssertEqual(result, megaRequest.toAccountRequestEntity())
                case .failure:
                    XCTFail("Request error is not expected.")
                }
                exp.fulfill()
            }.store(in: &subscriptions)
        sut.onRequestFinish(mockSdk, request: megaRequest, error: apiOk)
        wait(for: [exp], timeout: 1)
    }
    
    func testRequestResultPublisher_onRequestFinish_withError_sendsError() {
        let apiError = MockError.failingError
        let mockSdk = MockSdk()
        let sut = makeSUT(sdk: mockSdk)
        
        let exp = expectation(description: "Should receive success AccountRequestEntity")
        sut.requestResultPublisher
            .sink { request in
                switch request {
                case .success:
                    XCTFail("Expecting an error but got a success.")
                case .failure(let error):
                    guard let err = error as? MEGAError else {
                        XCTFail("Error can't cast as MEGAError")
                        return
                    }
                    XCTAssertEqual(err.type, apiError.type)
                }
                exp.fulfill()
            }.store(in: &subscriptions)
        sut.onRequestFinish(mockSdk, request: MEGARequest(), error: apiError)
        wait(for: [exp], timeout: 1)
    }
    
    func testContactRequestPublisher_onContactRequestsUpdate_sendsContactRequestList() {
        let mockSdk = MockSdk()
        let sut = makeSUT(sdk: mockSdk)
        
        let exp = expectation(description: "Should receive ContactRequestEntity list")
        let expectedContactRequest = ContactRequestEntity.random
        sut.contactRequestPublisher
            .sink { list in
                XCTAssertEqual(list, [expectedContactRequest])
                exp.fulfill()
            }.store(in: &subscriptions)
        
        let mockContactRequestList = MockContactRequestList(contactRequests: [MockContactRequest(handle: expectedContactRequest.handle)])
        sut.onContactRequestsUpdate(mockSdk, contactRequestList: mockContactRequestList)
        wait(for: [exp], timeout: 1)
    }
    
    func testUserAlertPublisher_onUserAlertsUpdate_sendsUserAlertList() {
        let mockSdk = MockSdk()
        let sut = makeSUT(sdk: mockSdk)
        
        let exp = expectation(description: "Should receive UserAlertEntity list")
        let expectedUserAlert = UserAlertEntity.random
        sut.userAlertUpdatePublisher
            .sink { list in
                XCTAssertEqual(list, [expectedUserAlert])
                exp.fulfill()
            }.store(in: &subscriptions)
        
        let mockUserAlertList = MockUserAlertList(alerts: [MockUserAlert(identifier: expectedUserAlert.identifier)])
        sut.onUserAlertsUpdate(mockSdk, userAlertList: mockUserAlertList)
        wait(for: [exp], timeout: 1)
    }
    
    func testOnRequestResultFinish_addDelegate_delegateShouldExist() async {
        let sdk = MockSdk()
        let repo = AccountRepository(sdk: sdk, myChatFilesFolderNodeAccess: .shared)
        await repo.registerMEGARequestDelegate()
        
        XCTAssertTrue(sdk.hasRequestDelegate)
    }
    
    func testOnRequestResultFinish_removeDelegate_delegateShouldNotExist() async {
        let sdk = MockSdk()
        sdk.hasRequestDelegate = true
        
        let repo = AccountRepository(sdk: sdk, myChatFilesFolderNodeAccess: .shared)
        await repo.deRegisterMEGARequestDelegate()
        
        XCTAssertFalse(sdk.hasRequestDelegate)
    }

    func testGetMiscFlag_whenApiOk_shouldNotThrow() async {
        let mockSdk = MockSdk(requestResult: .success(MockRequest(handle: 1)))
        let sut = makeSUT(sdk: mockSdk)

        await XCTAsyncAssertNoThrow(try await sut.getMiscFlags())
    }
    
    func testGetMiscFlag_whenFail_shouldThrowGenericError() async {
        let mockSdk = MockSdk(requestResult: .failure(MockError.failingError))
        let sut = makeSUT(sdk: mockSdk)
        
        await XCTAsyncAssertThrowsError(try await sut.getMiscFlags()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }
    
    func testSessionTransferURL_whenApiOk_shouldReturnURL() async throws {
        let urlPath = "https://mega.nz"
        let expectedURL = try XCTUnwrap(URL(string: urlPath))
        let mockSdk = MockSdk(requestResult: .success(MockRequest(handle: 1, link: urlPath)))
        let sut = makeSUT(sdk: mockSdk)
        
        let urlResult = try await sut.sessionTransferURL(path: urlPath)
        
        XCTAssertEqual(urlResult, expectedURL)
    }
    
    func testSessionTransferURL_whenFail_shouldThrowGenericError() async throws {
        let urlPath = "https://mega.nz"
        let mockSdk = MockSdk(requestResult: .failure(MockError.failingError))
        let sut = makeSUT(sdk: mockSdk)
        
        await XCTAsyncAssertThrowsError(try await sut.sessionTransferURL(path: urlPath)) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }
    
    func testSessionTransferURL_whenApiOkButInvalidURLLink_shouldThrowGenericError() async throws {
        let urlPath = "https://mega.nz"
        let mockSdk = MockSdk(requestResult: .success(MockRequest(handle: 1, link: nil)))
        let sut = makeSUT(sdk: mockSdk)
        
        await XCTAsyncAssertThrowsError(try await sut.sessionTransferURL(path: urlPath)) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }

    // MARK: - Helpers
    
    private func makeSUT(sdk: MEGASdk) -> AccountRepository {
        AccountRepository(
            sdk: sdk,
            currentUserSource: CurrentUserSource(sdk: sdk), myChatFilesFolderNodeAccess: .shared
        )
    }
    
    private func randomAccountDetails() -> MockMEGAAccountDetails {
        MockMEGAAccountDetails(type: MEGAAccountType(rawValue: .random(in: 0...4)) ?? .free)
    }
}

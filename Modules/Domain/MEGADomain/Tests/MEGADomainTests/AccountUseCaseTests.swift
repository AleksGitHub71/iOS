import MEGADomain
import MEGADomainMock
import MEGATest
import XCTest

final class AccountUseCaseTests: XCTestCase {
    
    private func makeSUT(
        currentUser: UserEntity? = nil,
        isGuest: Bool = false,
        isNewAccount: Bool = false,
        accountCreationDate: Date? = nil,
        myEmail: String? = nil,
        isLoggedIn: Bool = true,
        isMasterBusinessAccount: Bool = false,
        isAchievementsEnabled: Bool = false,
        isSmsAllowed: Bool = false,
        contacts: [UserEntity] = [],
        nodesCount: UInt64 = 0,
        getMyChatFilesFolderResult: Result<NodeEntity, AccountErrorEntity> = .failure(.nodeNotFound),
        currentAccountDetails: AccountDetailsEntity? = nil,
        accountDetailsResult: Result<AccountDetailsEntity, AccountDetailsErrorEntity> = .failure(.generic),
        miscFlagsResult: Result<Void, AccountErrorEntity> = .failure(.generic),
        sessionTransferURLResult: Result<URL, AccountErrorEntity> = .failure(.generic),
        multiFactorAuthCheckResult: Result<Bool, AccountErrorEntity> = .failure(.generic),
        isUpgradeSecuritySuccess: Bool = false,
        bandwidthOverquotaDelay: Int64 = 0,
        isExpiredAccount: Bool = false,
        isInGracePeriod: Bool = false,
        accountType: AccountTypeEntity = .free
    ) -> AccountUseCase<MockAccountRepository> {
        let repository = MockAccountRepository(
            currentUser: currentUser,
            isGuest: isGuest,
            isNewAccount: isNewAccount,
            accountCreationDate: accountCreationDate,
            myEmail: myEmail,
            isLoggedIn: isLoggedIn,
            isMasterBusinessAccount: isMasterBusinessAccount,
            isExpiredAccount: isExpiredAccount,
            isInGracePeriod: isInGracePeriod,
            isAchievementsEnabled: isAchievementsEnabled,
            isSmsAllowed: isSmsAllowed,
            contacts: contacts,
            nodesCount: nodesCount,
            getMyChatFilesFolderResult: getMyChatFilesFolderResult,
            currentAccountDetails: currentAccountDetails,
            accountDetailsResult: accountDetailsResult,
            miscFlagsResult: miscFlagsResult,
            sessionTransferURLResult: sessionTransferURLResult,
            multiFactorAuthCheckResult: multiFactorAuthCheckResult,
            isUpgradeSecuritySuccess: isUpgradeSecuritySuccess,
            bandwidthOverquotaDelay: bandwidthOverquotaDelay,
            accountType: accountType
        )
        return AccountUseCase(repository: repository)
    }

    func testUpgradeSecurity_shouldReturnSuccess() async throws {
        let sut = makeSUT(isUpgradeSecuritySuccess: true)
        let isSuccess = try await sut.upgradeSecurity()
        XCTAssertTrue(isSuccess)
    }
    
    func testIsNewAccount_accountIsNew_shouldReturnTrue() {
        let sut = makeSUT(isNewAccount: true)
        XCTAssertTrue(sut.isNewAccount)
    }
    
    func testIsNewAccount_accountIsAnExistingAccount_shouldReturnFalse() {
        let sut = makeSUT(isNewAccount: false)
        XCTAssertFalse(sut.isNewAccount)
    }
    
    func testCurrentAccountDetails_shouldReturnCurrentAccountDetails() {
        let accountDetails = AccountDetailsEntity.random
        let sut = makeSUT(currentAccountDetails: accountDetails)
        XCTAssertEqual(sut.currentAccountDetails, accountDetails)
    }
    
    func testBandwidthOverquotaDelay_returnBandwidth() {
        let expectedBandwidth: Int64 = 100
        let sut = makeSUT(bandwidthOverquotaDelay: expectedBandwidth)
        XCTAssertEqual(sut.bandwidthOverquotaDelay, expectedBandwidth)
    }
    
    func testRefreshCurrentAccountDetails_whenSuccess_shouldReturnAccountDetails() async throws {
        let accountDetails = AccountDetailsEntity.random
        let sut = makeSUT(currentAccountDetails: accountDetails, accountDetailsResult: .success(accountDetails))
        let currentAccountDetails = try await sut.refreshCurrentAccountDetails()
        XCTAssertEqual(currentAccountDetails, accountDetails)
    }
    
    func testRefreshCurrentAccountDetails_whenFails_shouldThrowGenericError() async {
        let sut = makeSUT(accountDetailsResult: .failure(.generic))
        await XCTAsyncAssertThrowsError(try await sut.refreshCurrentAccountDetails()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountDetailsErrorEntity, .generic)
        }
    }
    
    func testGetMiscFlag_whenSuccess_shouldNotThrow() async {
        let sut = makeSUT(miscFlagsResult: .success(()))
        await XCTAsyncAssertNoThrow(try await sut.getMiscFlags())
    }
    
    func testGetMiscFlag_whenFail_shouldThrowGenericError() async throws {
        let sut = makeSUT(miscFlagsResult: .failure(.generic))
        await XCTAsyncAssertThrowsError(try await sut.getMiscFlags()) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }
    
    func testSessionTransferURL_whenSuccess_shouldReturnURL() async throws {
        let urlPath = "https://mega.nz"
        let expectedURL = try XCTUnwrap(URL(string: urlPath))
        let sut = makeSUT(sessionTransferURLResult: .success(expectedURL))
        let urlResult = try await sut.sessionTransferURL(path: urlPath)
        XCTAssertEqual(urlResult, expectedURL)
    }
    
    func testSessionTransferURL_whenFail_shouldThrowGenericError() async throws {
        let urlPath = "https://mega.nz"
        let sut = makeSUT(sessionTransferURLResult: .failure(.generic))
        await XCTAsyncAssertThrowsError(try await sut.sessionTransferURL(path: urlPath)) { errorThrown in
            XCTAssertEqual(errorThrown as? AccountErrorEntity, .generic)
        }
    }
    
    func testIsLoggedIn_whenLoggedIn_shouldReturnTrue() {
        let sut = makeSUT(isLoggedIn: true)
        XCTAssertTrue(sut.isLoggedIn())
    }
    
    func testIsLoggedIn_whenLoggedOut_shouldReturnFalse() {
        let sut = makeSUT(isLoggedIn: false)
        XCTAssertFalse(sut.isLoggedIn())
    }
    
    func testIsMasterBusinessAccount_whenTrue_shouldReturnTrue() {
        let sut = makeSUT(isMasterBusinessAccount: true)
        XCTAssertTrue(sut.isMasterBusinessAccount)
    }
    
    func testIsMasterBusinessAccount_whenFalse_shouldReturnFalse() {
        let sut = makeSUT(isMasterBusinessAccount: false)
        XCTAssertFalse(sut.isMasterBusinessAccount)
    }
    
    func testIsAchievementsEnabled_whenTrue_shouldReturnTrue() {
        let sut = makeSUT(isAchievementsEnabled: true)
        XCTAssertTrue(sut.isAchievementsEnabled)
    }
    
    func testIsAchievementsEnabled_whenFalse_shouldReturnFalse() {
        let sut = makeSUT(isAchievementsEnabled: false)
        XCTAssertFalse(sut.isAchievementsEnabled)
    }

    func testIsSmsAllowed_whenAllowed_shouldReturnTrue() {
        let sut = makeSUT(isSmsAllowed: true)
        XCTAssertTrue(sut.isSmsAllowed)
    }
    
    func testIsSmsAllowed_whenNotAllowed_shouldReturnFalse() {
        let sut = makeSUT(isSmsAllowed: false)
        XCTAssertFalse(sut.isSmsAllowed)
    }
    
    func testCurrentUser_whenUserExists_shouldReturnUser() async {
        let user = UserEntity(handle: 1)
        let sut = makeSUT(currentUser: user)
        let fetchedUser = await sut.currentUser()
        XCTAssertEqual(fetchedUser, user)
    }
    
    func testCurrentUser_whenUserDoesNotExist_shouldReturnNil() async {
        let sut = makeSUT(currentUser: nil)
        let fetchedUser = await sut.currentUser()
        XCTAssertNil(fetchedUser)
    }
    
    func testAccountCreationDate_whenSet_shouldReturnDate() {
        let testDate = Date()
        let sut = makeSUT(accountCreationDate: testDate)
        XCTAssertEqual(sut.accountCreationDate, testDate)
    }
    
    func testContacts_shouldReturnContacts() {
        let contacts = [
            UserEntity(handle: 1),
            UserEntity(handle: 2)
        ]
        let sut = makeSUT(contacts: contacts)
        XCTAssertEqual(sut.contacts(), contacts)
    }
    
    func testTotalNodesCount_shouldReturnCorrectCount() {
        let count: UInt64 = 100
        let sut = makeSUT(nodesCount: count)
        XCTAssertEqual(sut.totalNodesCount(), count)
    }
    
    func testMultiFactorAuthCheck_whenSuccess_shouldReturnTrue() async throws {
        let sut = makeSUT(multiFactorAuthCheckResult: .success(true))
        let result = try await sut.multiFactorAuthCheck(email: "test@example.com")
        XCTAssertTrue(result)
    }
    
    func testMultiFactorAuthCheck_whenFail_shouldThrow() async throws {
        let sut = makeSUT(multiFactorAuthCheckResult: .failure(AccountErrorEntity.generic))
        await XCTAsyncAssertThrowsError(try await sut.multiFactorAuthCheck(email: "test@example.com"))
    }
    
    func testHasValidProAccount_whenAccountIsAValidProAccount_returnsTrue() {
        testHasValidProAccount(.lite, expectedResult: true)
        testHasValidProAccount(.proI, expectedResult: true)
        testHasValidProAccount(.proII, expectedResult: true)
        testHasValidProAccount(.proIII, expectedResult: true)
        testHasValidProAccount(.proFlexi, expectedResult: true)
    }
    
    func testHasValidProAccount_whenAccountIsNotAValidProAccount_returnsFalse() {
        testHasValidProAccount(.free, expectedResult: false)
        testHasValidProAccount(.proFlexi, isExpiredAccount: true, expectedResult: false)
        testHasValidProAccount(.proFlexi, isInGracePeriod: true, expectedResult: false)
    }
    
    func testHasValidProOrUnexpiredBusinessAccount_freeAccount_shouldReturnFalse() {
        let sut = makeSUT(accountType: .free)
        
        XCTAssertFalse(sut.hasValidProOrUnexpiredBusinessAccount())
    }
    
    func testHasValidProOrUnexpiredBusinessAccount_standardProAccount_shouldReturnTrue() {
        [AccountTypeEntity.lite, .proI, .proII, .proIII]
            .enumerated()
            .forEach { (index, accountType) in
                let sut = makeSUT(accountType: accountType)
                
                XCTAssertTrue(sut.hasValidProOrUnexpiredBusinessAccount(),
                              "failed at index: \(index) for accountType: \(accountType)")
            }
    }
    
    func testHasValidProOrUnexpiredBusinessAccount_proFlexi_shouldReturnCorrectValue() {
        [(accountType: AccountTypeEntity.proFlexi, isExpiredAccount: false, isInGracePeriod: false, expectedResult: true),
         (accountType: AccountTypeEntity.proFlexi, isExpiredAccount: true, isInGracePeriod: true, expectedResult: false),
         (accountType: AccountTypeEntity.proFlexi, isExpiredAccount: true, isInGracePeriod: false, expectedResult: false),
         (accountType: AccountTypeEntity.proFlexi, isExpiredAccount: false, isInGracePeriod: true, expectedResult: false)]
            .enumerated()
            .forEach { (index, testCase) in
                let sut = makeSUT(isExpiredAccount: testCase.isExpiredAccount,
                                  isInGracePeriod: testCase.isInGracePeriod,
                                  accountType: testCase.accountType)
                
                XCTAssertEqual(sut.hasValidProOrUnexpiredBusinessAccount(), testCase.expectedResult,
                               "failed at index: \(index) for accountType: \(testCase.accountType)")
            }
    }
    
    func testHasValidProOrUnexpiredBusinessAccount_businessAccountAndStatus_shouldReturnCorrectValue() {
        [(accountType: AccountTypeEntity.business, isExpiredAccount: false, expectedResult: true),
         (accountType: AccountTypeEntity.business, isExpiredAccount: true, expectedResult: false)]
            .enumerated()
            .forEach { (index, testCase) in
                let sut = makeSUT(isExpiredAccount: testCase.isExpiredAccount,
                                  accountType: testCase.accountType)
                
                XCTAssertEqual(sut.hasValidProOrUnexpiredBusinessAccount(), testCase.expectedResult,
                               "failed at index: \(index) for accountType: \(testCase.accountType)")
            }
    }
    
    private func testHasValidProAccount(
        _ accountType: AccountTypeEntity,
        isExpiredAccount: Bool = false,
        isInGracePeriod: Bool = false,
        expectedResult: Bool
    ) {
        let sut = makeSUT(
            isExpiredAccount: isExpiredAccount,
            isInGracePeriod: isInGracePeriod,
            accountType: accountType
        )
        
        if expectedResult {
            XCTAssertTrue(sut.hasValidProAccount(), "\(accountType) result should be true")
        } else {
            XCTAssertFalse(sut.hasValidProAccount(), "\(accountType) result should be false")
        }
    }
}

final class AccountUserCaseProtocolTests: XCTestCase {
    func testFreeTierTrue_WhenProLevelFree() {
        let useCaseFree = MockAccountUseCase(currentAccountDetails: AccountDetailsEntity(proLevel: .free))
        XCTAssertTrue(useCaseFree.isFreeTierUser)
    }
    
    func testFreeTierFalse_WhenProLevelNonFree() {
        let nonFreeProLevels = AccountTypeEntity.allCases.filter { $0 != .free }
        for level in nonFreeProLevels {
            let useCase = MockAccountUseCase(currentAccountDetails: AccountDetailsEntity(proLevel: level))
            XCTAssertFalse(useCase.isFreeTierUser)
        }
    }
}

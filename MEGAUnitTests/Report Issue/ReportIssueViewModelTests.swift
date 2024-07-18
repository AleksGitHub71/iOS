import Combine
@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAL10n
import MEGASwift
import MEGATest
import XCTest

final class ReportIssueViewModelTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()
    private let defaultTransferEntity = TransferEntity(fileName: "test.log")
    
    private func makeSUT(
        router: ReportIssueViewRouting = MockReportIssueViewRouter(),
        connectionChangedStream: AnyAsyncSequence<Bool> = EmptyAsyncSequence().eraseToAnyAsyncSequence(),
        connected: Bool = true,
        connectedViaWiFi: Bool = false,
        uploadFileResult: Result<Void, TransferErrorEntity>? = nil,
        uploadSupportFileResult: Result<TransferEntity, TransferErrorEntity>? = nil,
        supportResult: Result<Void, Error> = .failure(GenericErrorEntity()),
        cancelTransferResult: Result<Void, TransferErrorEntity> = .failure(.generic),
        areLogsEnabled: Bool = false,
        sourceUrl: URL? = nil,
        transfer: TransferEntity? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) -> (ReportIssueViewModel, MockReportIssueViewRouter) {
        let monitorUseCase = MockNetworkMonitorUseCase(
            connected: connected,
            connectedViaWiFi: connectedViaWiFi,
            connectionChangedStream: connectionChangedStream
        )
        let uploadFileUseCase = MockUploadFileUseCase(
            uploadFileResult: uploadFileResult,
            uploadSupportFileResult: uploadSupportFileResult,
            cancelTransferResult: cancelTransferResult,
            transfer: transfer
        )
        let supportUseCase = MockSupportUseCase(createSupportTicketResult: supportResult)
        let accountUseCase = MockAccountUseCase()
        
        let sut = ReportIssueViewModel(
            router: router,
            uploadFileUseCase: uploadFileUseCase,
            supportUseCase: supportUseCase,
            monitorUseCase: monitorUseCase,
            accountUseCase: accountUseCase,
            areLogsEnabled: areLogsEnabled,
            sourceUrl: sourceUrl
        )
        trackForMemoryLeaks(on: sut, file: file, line: line)
        return (sut, router as! MockReportIssueViewRouter)
    }
    
    private func assertAlertData(
        _ alertData: ReportIssueAlertDataModel,
        title: String,
        message: String,
        buttonTitle: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            alertData.title,
            title,
            file: file,
            line: line
        )
        XCTAssertEqual(
            alertData.message,
            message,
            file: file,
            line: line
        )
        XCTAssertEqual(
            alertData.primaryButtonTitle,
            buttonTitle,
            file: file,
            line: line
        )
    }
    
    private func defaultFileURL() -> URL {
        do {
            return try XCTUnwrap(URL(string: "file://testFile"))
        } catch {
            return URL(string: "")!
        }
    }

    func testDismissReport_emptyDetails_dismissCalledOnce() async {
        let (sut, router) = makeSUT()
        
        sut.details = ""
        await sut.dismissReport()
        
        XCTAssertEqual(router.dismiss_calledTimes, 1)
    }
    
    func testDismissReport_detailsSameAsPlaceholder_dismissCalledOnce() async {
        let (sut, router) = makeSUT()
        
        sut.details = "Describe the issue"
        await sut.dismissReport()
        
        XCTAssertEqual(router.dismiss_calledTimes, 1)
    }
    
    func testShouldDisableSendButton_detailsEmpty_isTrue() {
        let (sut, _) = makeSUT()
        
        sut.details = ""
        
        XCTAssertTrue(sut.shouldDisableSendButton)
    }
    
    func testShouldDisableSendButton_detailsEqualToPlaceholder_isTrue() {
        let (sut, _) = makeSUT()
        
        sut.details = "Describe the issue"
        
        XCTAssertTrue(sut.shouldDisableSendButton)
    }
    
    func testShouldDisableSendButton_notConnected_isTrue() {
        let (sut, _) = makeSUT(connected: false)
        
        XCTAssertTrue(sut.shouldDisableSendButton)
    }
    
    func testShouldShowUploadLogFileView_uploadingLogAndLogsEnabledAndToggleOn_isTrue() {
        let (sut, _) = makeSUT()
        
        sut.isUploadingLog = true
        sut.areLogsEnabled = true
        sut.isSendLogFileToggleOn = true
        
        XCTAssertTrue(sut.shouldShowUploadLogFileView)
    }
    
    func testShouldShowUploadLogFileView_uploadingLogAndLogsNotEnabled_isFalse() {
        let (sut, _) = makeSUT()
        
        sut.isUploadingLog = true
        sut.areLogsEnabled = false
        sut.isSendLogFileToggleOn = true
        
        XCTAssertFalse(sut.shouldShowUploadLogFileView)
    }
    
    func testShouldShowUploadLogFileView_notUploadingLog_isFalse() {
        let (sut, _) = makeSUT()
        
        sut.isUploadingLog = false
        sut.areLogsEnabled = true
        sut.isSendLogFileToggleOn = true
        
        XCTAssertFalse(sut.shouldShowUploadLogFileView)
    }
    
    func testShouldShowUploadLogFileView_sendLogFileToggleOff_isFalse() {
        let (sut, _) = makeSUT()
        
        sut.isUploadingLog = true
        sut.areLogsEnabled = true
        sut.isSendLogFileToggleOn = false
        
        XCTAssertFalse(sut.shouldShowUploadLogFileView)
    }
    
    func testMonitorNetworkChanges_connectionChanges_isConnectedUpdated() async {
        var results = [false, true, true, false]
        let stream = AsyncStream { continuation in
            results.forEach {
                continuation.yield($0)
            }
            continuation.finish()
        }.eraseToAnyAsyncSequence()
        
        let (sut, _) = makeSUT(connectionChangedStream: stream)
        
        sut.$isConnected
            .dropFirst()
            .sink {
                XCTAssertEqual($0, results.removeFirst())
            }
            .store(in: &subscriptions)
        
        await sut.monitorNetworkChanges()
    }
    
    func testShouldDisableSendButton_allConditionsMet_isFalse() {
        let (sut, _) = makeSUT()
        
        sut.details = "Some issue details"
        sut.isConnected = true
        
        XCTAssertFalse(sut.shouldDisableSendButton)
    }

    func testDismissReport_called_dismissCalledOnce() async {
        let (sut, router) = makeSUT()
        
        await sut.dismissReport()
        
        XCTAssertEqual(router.dismiss_calledTimes, 1)
    }

    func testSetAreLogsEnabled_toggle_isUpdated() {
        let (sut, _) = makeSUT()
        
        sut.areLogsEnabled = true
        XCTAssertTrue(sut.areLogsEnabled)
        
        sut.areLogsEnabled = false
        XCTAssertFalse(sut.areLogsEnabled)
    }

    func testSetIsSendLogFileToggleOn_toggle_isUpdated() {
        let (sut, _) = makeSUT()
        
        sut.isSendLogFileToggleOn = true
        XCTAssertTrue(sut.isSendLogFileToggleOn)
        
        sut.isSendLogFileToggleOn = false
        XCTAssertFalse(sut.isSendLogFileToggleOn)
    }
    
    func testCreateTicket_uploadSupportFileFails_showsAlert() async {
        let (sut, _) = makeSUT(
            uploadSupportFileResult: .success(defaultTransferEntity),
            supportResult: .failure(ReportErrorEntity.tooManyRequest),
            areLogsEnabled: true,
            sourceUrl: defaultFileURL(),
            transfer: defaultTransferEntity
        )
        
        await sut.createTicket()
        
        XCTAssertTrue(sut.showingReportIssueAlert)
        XCTAssertEqual(sut.reportAlertType, .createSupportTicketTooManyRequestFailure)
        
        assertAlertData(
            sut.reportIssueAlertData(),
            title: Strings.Localizable.Help.ReportIssue.Fail.Too.Many.Request.title,
            message: Strings.Localizable.Help.ReportIssue.Fail.Too.Many.Request.message,
            buttonTitle: Strings.Localizable.ok
        )
    }
    
    func testUploadLogFileIfNeeded_sourceUrlNil_createsTicketWithoutUploading() async {
        let (sut, _) = makeSUT(
            uploadSupportFileResult: .success(defaultTransferEntity),
            supportResult: .success,
            areLogsEnabled: true,
            transfer: defaultTransferEntity
        )
        
        await sut.createTicket()
        
        XCTAssertFalse(sut.isUploadingLog)
        XCTAssertTrue(sut.reportAlertType == .createSupportTicketFinished)
        
        assertAlertData(
            sut.reportIssueAlertData(),
            title: Strings.Localizable.Help.ReportIssue.Success.title,
            message: Strings.Localizable.Help.ReportIssue.Success.message,
            buttonTitle: Strings.Localizable.ok
        )
    }
    
    func testUploadLogFileIfNeeded_logsEnabledAndToggleOn_uploadsFile() async {
        let (sut, _) = makeSUT(
            uploadSupportFileResult: .success(defaultTransferEntity),
            supportResult: .success,
            areLogsEnabled: true,
            sourceUrl: defaultFileURL(),
            transfer: defaultTransferEntity
        )
        
        let expectation = self.expectation(description: "Log file upload completed")
        
        sut.$isUploadingLog
            .dropFirst()
            .sink { isUploadingLog in
                if !isUploadingLog {
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        await sut.createTicket()
        
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertFalse(sut.isUploadingLog)
        XCTAssertEqual(sut.progress, 1)
        XCTAssertTrue(sut.reportAlertType == .createSupportTicketFinished)
    }
   
    func testUploadLogFileIfNeeded_logsNotEnabled_doesNotUploadFile() async {
        let uploadFileResult: Result<Void, TransferErrorEntity> = .success
        let (sut, _) = makeSUT(uploadFileResult: uploadFileResult)
        
        sut.areLogsEnabled = false
        sut.isSendLogFileToggleOn = true
        
        await sut.createTicket()
        
        XCTAssertFalse(sut.isUploadingLog)
    }
   
    func testUploadLogFileIfNeeded_uploadFails_showsAlert() async {
        let (sut, _) = makeSUT(
            uploadSupportFileResult: .failure(.generic),
            areLogsEnabled: true,
            sourceUrl: defaultFileURL()
        )
        
        let expectation = self.expectation(description: "Upload failure shows alert")
        
        sut.$showingReportIssueAlert
            .dropFirst()
            .sink { showingAlert in
                if showingAlert {
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        await sut.createTicket()
        
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertFalse(sut.isUploadingLog)
        XCTAssertEqual(sut.reportAlertType, .uploadLogFileFailure)
        
        assertAlertData(
            sut.reportIssueAlertData(),
            title: Strings.Localizable.somethingWentWrong,
            message: Strings.Localizable.Help.ReportIssue.Fail.message,
            buttonTitle: Strings.Localizable.ok
        )
    }
    
    func testCancelUploadReport_uploadInProgress_cancelSucceeds() async throws {
        let (sut, router) = makeSUT(
            uploadSupportFileResult: .success(defaultTransferEntity),
            cancelTransferResult: .success,
            sourceUrl: defaultFileURL(),
            transfer: defaultTransferEntity
        )
        
        sut.areLogsEnabled = true
        sut.isSendLogFileToggleOn = true
        
        let createTicketExpectation = self.expectation(description: "Create ticket in progress")
        
        Task {
            await sut.createTicket()
            createTicketExpectation.fulfill()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await sut.cancelUploadReport()
        
        XCTAssertEqual(router.dismiss_calledTimes, 0)
        
        await fulfillment(of: [createTicketExpectation], timeout: 3)
    }

    func testCancelUploadReport_uploadInProgress_cancelFails() async throws {
        let (sut, router) = makeSUT(
            uploadSupportFileResult: .success(defaultTransferEntity),
            cancelTransferResult: .failure(.generic),
            sourceUrl: defaultFileURL(),
            transfer: defaultTransferEntity
        )
        
        sut.areLogsEnabled = true
        sut.isSendLogFileToggleOn = true
        
        let createTicketExpectation = self.expectation(description: "Create ticket in progress")
        
        Task {
            await sut.createTicket()
            createTicketExpectation.fulfill()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await sut.cancelUploadReport()
        
        XCTAssertEqual(router.dismiss_calledTimes, 1)
        
        await fulfillment(of: [createTicketExpectation], timeout: 3)
    }
    
    func testCancelUploadReport_noTransfer_dismissCalled() async {
        let (sut, router) = makeSUT()
        
        let noTransferExpectation = self.expectation(description: "No transfer, dismiss called")
        
        await sut.cancelUploadReport()
        
        XCTAssertEqual(router.dismiss_calledTimes, 1)
        noTransferExpectation.fulfill()
        
        await fulfillment(of: [noTransferExpectation], timeout: 2)
    }

    func testShowReportIssueActionSheetIfNeeded_discardable_showsActionSheet() async {
        let (sut, _) = makeSUT()
        sut.details = "Some issue details"
        
        await sut.showReportIssueActionSheetIfNeeded()
        
        XCTAssertTrue(sut.showingReportIssueActionSheet)
    }

    func testShowReportIssueActionSheetIfNeeded_notDiscardable_dismissesReport() async {
        let (sut, router) = makeSUT()
        sut.details = ""
        
        await sut.showReportIssueActionSheetIfNeeded()
        
        XCTAssertFalse(sut.showingReportIssueActionSheet)
        XCTAssertEqual(router.dismiss_calledTimes, 1)
    }

    func testShowCancelUploadReportAlert_whenCalled_setsCorrectAlertTypeAndShowsAlert() async {
        let (sut, _) = makeSUT()
        
        await sut.showCancelUploadReportAlert()
        
        XCTAssertEqual(sut.reportAlertType, .cancelUploadReport)
        XCTAssertTrue(sut.showingReportIssueAlert)
        
        assertAlertData(
            sut.reportIssueAlertData(),
            title: Strings.Localizable.Help.ReportIssue.Creating.Cancel.title,
            message: Strings.Localizable.Help.ReportIssue.Creating.Cancel.message,
            buttonTitle: Strings.Localizable.continue
        )
    }
    
    func testReportIssueAlertData_none_returnsEmptyAlertData() {
        let (sut, _) = makeSUT()
        
        let alertData = sut.reportIssueAlertData()
        
        XCTAssertTrue(alertData.title.isEmpty)
        XCTAssertTrue(alertData.message.isEmpty)
        XCTAssertTrue(alertData.primaryButtonTitle.isEmpty)
    }
}

final class MockReportIssueViewRouter: ReportIssueViewRouting {
    var dismiss_calledTimes = 0

    func dismiss() {
        dismiss_calledTimes += 1
    }
}

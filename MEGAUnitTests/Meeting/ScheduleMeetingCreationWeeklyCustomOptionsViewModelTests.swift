@testable import MEGA
import MEGADomain
import MEGADomainMock
import XCTest

final class ScheduleMeetingCreationWeeklyCustomOptionsViewModelTests: XCTestCase {
    
    func testWeekDaySymbols_shouldMatch() {
        XCTAssertEqual(makeViewModel().weekdaySymbols, WeekDaysInformation().symbols)
    }
    
    func testSelectedWeekDays_givenOnlyOneWeekDay_shouldMatch() {
        let viewModel = makeViewModel(withWeekDayList: [1])
        XCTAssertEqual(viewModel.selectedWeekDays, Set([WeekDaysInformation().symbols[0]]))
    }

    func testToogleSelection_givenOnlyWeekDaySelectedShouldNotBeRemoved_shouldMatch() {
        let viewModel = makeViewModel(withWeekDayList: [1])
        viewModel.toggleSelection(forWeekDay: WeekDaysInformation().symbols[0])
        XCTAssertEqual(viewModel.rules.weekDayList, [1])
    }
    
    func testToogleSelection_weekDayListShouldAddTheWeekDay_shouldMatch() {
        let viewModel = makeViewModel(withWeekDayList: [1])
        viewModel.toggleSelection(forWeekDay: WeekDaysInformation().symbols[1])
        XCTAssertEqual(viewModel.rules.weekDayList, [1, 2])
    }
    
    func testToogleSelection_weekDayListShouldAddTheWeekDayAndAlsoSorted_shouldMatch() {
        let viewModel = makeViewModel(withWeekDayList: [4])
        viewModel.toggleSelection(forWeekDay: WeekDaysInformation().symbols[1])
        XCTAssertEqual(viewModel.rules.weekDayList, [2, 4])
    }
    
    func testUpdateInterval_changeIntervalToThree_shouldMatch() {
        let viewModel = makeViewModel(withWeekDayList: [4])
        viewModel.update(interval: 5)
        XCTAssertEqual(viewModel.rules.interval, 5)
    }
    
    // MARK: - Private methods
    
    private func makeViewModel(
        withWeekDayList weekDayList: [Int]? = nil
    ) -> ScheduleMeetingCreationWeeklyCustomOptionsViewModel {
        let rules = ScheduledMeetingRulesEntity(frequency: .weekly, weekDayList: weekDayList)
        return ScheduleMeetingCreationWeeklyCustomOptionsViewModel(rules: rules)
    }
}

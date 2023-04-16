
import SwiftUI

struct ScheduleMeetingCreationDateAndRecurrenceView: View {
    @ObservedObject var viewModel: ScheduleMeetingViewModel
    
    var body: some View {
        VStack {
            Divider()
            DatePickerView(title: Strings.Localizable.Meetings.ScheduleMeeting.start, dateFormatted: $viewModel.startDateFormatted, datePickerVisible: $viewModel.startDatePickerVisible, date: $viewModel.startDate, dateRange: Date()...) {
                viewModel.startsDidTap()
            }
            if viewModel.startDatePickerVisible {
                Divider()
            } else {
                Divider()
                    .padding(.leading)
            }
            DatePickerView(title: Strings.Localizable.Meetings.ScheduleMeeting.end, dateFormatted: $viewModel.endDateFormatted, datePickerVisible: $viewModel.endDatePickerVisible, date: $viewModel.endDate, dateRange: viewModel.minimunEndDate...) {
                viewModel.endsDidTap()
            }
            if viewModel.endDatePickerVisible {
                Divider()
            } else {
                Divider()
                    .padding(.leading)
            }
            DetailDisclosureView(text: Strings.Localizable.Meetings.ScheduleMeeting.recurrence, detail: Strings.Localizable.never) {}
            Divider()
                .padding(.leading)
        }
    }
}

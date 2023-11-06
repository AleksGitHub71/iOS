import Combine
import MEGADomain
import MEGASwift

protocol ScheduleMeetingCreationCustomOptionsRouting {
    func start()
}

final class ScheduleMeetingCreationCustomOptionsViewModel: ObservableObject {
    var frequency: ScheduledMeetingRulesEntity.Frequency { rules.frequency }
    var interval: Int { rules.interval }
    var intervalFooterNote: String { ScheduleMeetingCreationIntervalFooterNote(rules: rules).string }
    var frequencyNames: [String] { ScheduleMeetingCreationFrequencyOption.all.map(\.name) }
    
    var selectedFrequencyOption: ScheduleMeetingCreationFrequencyOption? {
        ScheduleMeetingCreationFrequencyOption.all.first(where: { $0.frequency == rules.frequency })
    }
    
    var intervalOptions: [Int]? {
        selectedFrequencyOption?.intervalOption
    }
    
    @Published
    private(set) var expandFrequency: Bool = false {
        didSet {
            guard expandFrequency else { return }
            expandInterval = false
        }
    }
    
    @Published
    private(set) var expandInterval: Bool = false {
        didSet {
            guard expandInterval else { return }
            expandFrequency = false
        }
    }
    
    @Published
    var selectedFrequencyName: String = ""
            
    @Published
    private(set) var rules: ScheduledMeetingRulesEntity
    
    @Published
    private(set) var monthlyOptionsViewModel: ScheduleMeetingCreationMonthlyCustomOptionsViewModel?
    
    @Published
    private(set) var weeklyOptionsViewModel: ScheduleMeetingCreationWeeklyCustomOptionsViewModel?
    
    private var subscriptions = Set<AnyCancellable>()
    private let startDate: Date

    init(rules: ScheduledMeetingRulesEntity, startDate: Date) {
        self.rules = rules
        self.startDate = startDate
        resetFrequencyToDailyFrequencyIfNeeded()
        updateSelectedFrequencyName()
        instantiateRequiredViewModel(forFrequency: frequency)
        listenToFrequencyNameChanges()
    }
    
    func toggleFrequencyOption() {
        expandFrequency.toggle()
    }
    
    func toggleIntervalOption() {
        expandInterval.toggle()
    }
    
    func update(interval: Int) {
        rules.interval = interval
        if rules.frequency == .daily {
            rules.weekDayList = interval == 1 ? Array(1...7) : nil
        }
        monthlyOptionsViewModel?.update(interval: interval)
        weeklyOptionsViewModel?.update(interval: interval)
    }
    
    func string(forInterval interval: Int) -> String? {
        selectedFrequencyOption?.localizedString(interval)
    }
    
    private func instantiateRequiredViewModel(forFrequency frequency: ScheduledMeetingRulesEntity.Frequency) {
        weeklyOptionsViewModel = nil
        monthlyOptionsViewModel = nil
        
        switch frequency {
        case .weekly:
            weeklyOptionsViewModel = ScheduleMeetingCreationWeeklyCustomOptionsViewModel(rules: rules)
            weeklyOptionsViewModel?.$rules.assign(to: &$rules)
        case .monthly:
            monthlyOptionsViewModel = ScheduleMeetingCreationMonthlyCustomOptionsViewModel(
                rules: rules,
                startDate: startDate
            )
            monthlyOptionsViewModel?.$rules.assign(to: &$rules)
        default:
            break
        }
    }
            
    private func listenToFrequencyNameChanges() {
        $selectedFrequencyName
            .dropFirst()
            .sink { [weak self] updateFrequencyName in
                guard let self else { return }
                updateFrequency(withName: updateFrequencyName)
                instantiateRequiredViewModel(forFrequency: frequency)
            }
            .store(in: &subscriptions)
    }
    
    private func resetFrequencyToDailyFrequencyIfNeeded() {
        if rules.frequency == .invalid {
            rules.reset(toFrequency: .daily, usingStartDate: startDate)
        }
    }
    
    private func updateSelectedFrequencyName() {
        if let selectedFrequencyName = stringForSelectedFrequency() {
            self.selectedFrequencyName = selectedFrequencyName
        }
    }
    
    private func stringForSelectedFrequency() -> String? {
        selectedFrequencyOption?.name
    }
    
    private func updateFrequency(withName frequencyName: String) {
        let frequencyOption = ScheduleMeetingCreationFrequencyOption.all.first(where: { $0.name == frequencyName })
        let newRules = frequencyOption?.createRules(usingInterval: rules.interval, startDate: startDate)
        rules = newRules ?? rules
    }
}

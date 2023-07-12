import Foundation

public protocol ScheduledMeetingRepositoryProtocol: RepositoryProtocol {
    func scheduledMeetings() -> [ScheduledMeetingEntity]
    func scheduledMeetingsByChat(chatId: ChatIdEntity) -> [ScheduledMeetingEntity]
    func scheduledMeeting(for scheduledMeetingId: ChatIdEntity, chatId: ChatIdEntity) -> ScheduledMeetingEntity?
    func scheduledMeetingOccurrencesByChat(chatId: ChatIdEntity) async throws -> [ScheduledMeetingOccurrenceEntity]
    func scheduledMeetingOccurrencesByChat(chatId: ChatIdEntity, since: Date) async throws -> [ScheduledMeetingOccurrenceEntity]
    func createScheduleMeeting(_ meeting: ScheduleMeetingProxyEntity) async throws -> ScheduledMeetingEntity
    func updateScheduleMeeting(_ meeting: ScheduledMeetingEntity) async throws -> ScheduledMeetingEntity
    func updateOccurrence(
        _ occurrence: ScheduledMeetingOccurrenceEntity,
        meeting: ScheduledMeetingEntity
    ) async throws -> ScheduledMeetingEntity
}

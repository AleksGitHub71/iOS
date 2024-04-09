import Foundation
import MEGADomain

public final class MockContentConsumptionUserAttributeUseCase: ContentConsumptionUserAttributeUseCaseProtocol {
    @Published public private(set) var sensitiveAttributeChanged: SensitiveNodesUserAttributeEntity
    
    private var sensitiveShowHiddenNodes: Bool
    private var sensitiveOnboarded: Bool
    private var timelineUserAttributeEntity: TimelineUserAttributeEntity
    
    public init(
        timelineUserAttributeEntity: TimelineUserAttributeEntity = .init(mediaType: .allMedia, location: .allLocations, usePreference: false),
        sensitiveNodesUserAttributeEntity: SensitiveNodesUserAttributeEntity = .init(onboarded: false, showHiddenNodes: false)) {
        self.timelineUserAttributeEntity = timelineUserAttributeEntity
        self.sensitiveAttributeChanged = sensitiveNodesUserAttributeEntity
        self.sensitiveOnboarded = sensitiveNodesUserAttributeEntity.onboarded
        self.sensitiveShowHiddenNodes = sensitiveNodesUserAttributeEntity.showHiddenNodes
    }
    
    public func fetchTimelineAttribute() async -> TimelineUserAttributeEntity {
        timelineUserAttributeEntity
    }
    
    public func fetchSensitiveAttribute() async -> SensitiveNodesUserAttributeEntity {
        .init(onboarded: sensitiveOnboarded, showHiddenNodes: sensitiveShowHiddenNodes)
    }
    
    public func save(timeline: TimelineUserAttributeEntity) async throws {
        self.timelineUserAttributeEntity = timeline
    }
    
    public func saveSensitiveSetting(showHiddenNodes: Bool) async throws {
        sensitiveShowHiddenNodes = showHiddenNodes
        sensitiveAttributeChanged = await fetchSensitiveAttribute()
    }
    
    public func saveSensitiveSetting(onboarded: Bool) async throws {
        sensitiveOnboarded = onboarded
        sensitiveAttributeChanged = await fetchSensitiveAttribute()
    }
}

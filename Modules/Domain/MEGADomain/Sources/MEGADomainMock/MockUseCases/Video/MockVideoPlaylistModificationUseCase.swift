import MEGADomain
import MEGASwift

public final class MockVideoPlaylistModificationUseCase: VideoPlaylistModificationUseCaseProtocol {
    
    private let addToVideoPlaylistResult: Result<VideoPlaylistElementsResultEntity, any Error>
    private let deleteVideoPlaylistResult: [VideoPlaylistEntity]
    private let updateVideoPlaylistNameResult: Result<Void, any Error>
    
    public enum Message: Equatable {
        case addVideoToPlaylist
        case deleteVideoPlaylist
        case updateVideoPlaylistName
    }
    
    public private(set) var messages = [Message]()
    
    public init(
        addToVideoPlaylistResult: Result<VideoPlaylistElementsResultEntity, any Error> = .failure(GenericErrorEntity()),
        deleteVideoPlaylistResult: [VideoPlaylistEntity] = [],
        updateVideoPlaylistNameResult: Result<Void, any Error> = .failure(GenericErrorEntity())
    ) {
        self.addToVideoPlaylistResult = addToVideoPlaylistResult
        self.deleteVideoPlaylistResult = deleteVideoPlaylistResult
        self.updateVideoPlaylistNameResult = updateVideoPlaylistNameResult
    }
    
    public func addVideoToPlaylist(by id: HandleEntity, nodes: [NodeEntity]) async throws -> VideoPlaylistElementsResultEntity {
        messages.append(.addVideoToPlaylist)
        return try addToVideoPlaylistResult.get()
    }
    
    public func deleteVideos(in videoPlaylistId: HandleEntity, videos: [VideoPlaylistVideoEntity]) async throws -> VideoPlaylistElementsResultEntity {
        VideoPlaylistElementsResultEntity(success: 0, failure: 0)
    }
    
    public func delete(videoPlaylists: [VideoPlaylistEntity]) async -> [VideoPlaylistEntity] {
        messages.append(.deleteVideoPlaylist)
        return deleteVideoPlaylistResult
    }
    
    public func updateVideoPlaylistName(_ newName: String, for videoPlaylistEntity: VideoPlaylistEntity) async throws {
        messages.append(.updateVideoPlaylistName)
        return try updateVideoPlaylistNameResult.get()
    }
}

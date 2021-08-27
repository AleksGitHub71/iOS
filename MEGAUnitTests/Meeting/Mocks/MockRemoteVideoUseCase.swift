@testable import MEGA

class MockCallRemoteVideoUseCase: CallRemoteVideoUseCaseProtocol {
    var addRemoteVideoListener_CalledTimes = 0
    var disableAllRemoteVideos_CalledTimes = 0
    var enableRemoteVideo_CalledTimes = 0
    var disableRemoteVideo_CalledTimes = 0
    var requestHighResolutionVideoCompletion: Result<Void, CallErrorEntity> = .failure(.generic)
    var stopHighResolutionVideoCompletion: Result<Void, CallErrorEntity> = .failure(.generic)
    var requestLowResolutionVideoCompletion: Result<Void, CallErrorEntity> = .failure(.generic)
    var stopLowResolutionVideoCompletion: Result<Void, CallErrorEntity> = .failure(.generic)

    func addRemoteVideoListener(_ remoteVideoListener: CallRemoteVideoListenerUseCaseProtocol) {
        addRemoteVideoListener_CalledTimes += 1
    }
    
    func enableRemoteVideo(for participant: CallParticipantEntity) {
        enableRemoteVideo_CalledTimes += 1
    }
    
    func disableRemoteVideo(for participant: CallParticipantEntity) {
        disableRemoteVideo_CalledTimes += 1
    }
    
    func disableAllRemoteVideos() {
        disableAllRemoteVideos_CalledTimes += 1
    }
    
    func requestHighResolutionVideo(for chatId: MEGAHandle, clientId: MEGAHandle, completion: ResolutionVideoChangeCompletion?) {
        completion?(requestHighResolutionVideoCompletion)
    }
    
    func stopHighResolutionVideo(for chatId: MEGAHandle, clientIds: [MEGAHandle], completion: ResolutionVideoChangeCompletion?) {
        completion?(stopHighResolutionVideoCompletion)
    }
    
    func requestLowResolutionVideos(for chatId: MEGAHandle, clientIds: [MEGAHandle], completion: ResolutionVideoChangeCompletion?) {
        completion?(requestLowResolutionVideoCompletion)
    }
    
    func stopLowResolutionVideo(for chatId: MEGAHandle, clientIds: [MEGAHandle], completion: ResolutionVideoChangeCompletion?) {
        completion?(stopLowResolutionVideoCompletion)
    }
}

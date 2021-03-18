@testable import MEGA

final class MockAudioPlayerViewRouter: AudioPlayerViewRouting {
    var dismiss_calledTimes = 0
    var goToPlaylist_calledTimes = 0
    var showMiniPlayer_calledTimes = 0
    var showOfflineMiniPlayer_calledTimes = 0
    var importNode_calledTimes = 0
    var share_calledTimes = 0
    var sendToContact_calledTimes = 0
    var showAction_calledTimes = 0
    
    func dismiss() {
        dismiss_calledTimes += 1
    }
    
    func goToPlaylist() {
        goToPlaylist_calledTimes += 1
    }
    
    func showMiniPlayer(shouldReload: Bool) {
        showMiniPlayer_calledTimes += 1
    }
    
    func showOfflineMiniPlayer(file: String, shouldReload: Bool) {
        showOfflineMiniPlayer_calledTimes += 1
    }
    
    func importNode(_ node: MEGANode) {
        importNode_calledTimes += 1
    }
    
    func share() {
        share_calledTimes += 1
    }
    
    func sendToContact() {
        sendToContact_calledTimes += 1
    }
    
    func showAction(for node: MEGANode, sender: Any) {
        showAction_calledTimes += 1
    }
}


@testable import MEGA

final class MockAudioPlayerHandler: AudioPlayerHandlerProtocol {
    var playPrevious_calledTimes = 0
    var togglePlay_calledTimes = 0
    var pause_calledTimes = 0
    var play_calledTimes = 0
    var playNext_calledTimes = 0
    var updateProgressCompleted_calledTimes = 0
    var onShuffle_calledTimes = 0
    var onRepeatAll_calledTimes = 0
    var onRepeatOne_calledTimes = 0
    var onRepeatDisabled_calledTimes = 0
    var onMoveItem_calledTimes = 0
    var onDeleteItems_calledTimes = 0
    var addPlayer_calledTimes = 0
    var addPlayerTracks_calledTimes = 0
    var addPlayerListener_calledTimes = 0
    var removePlayerListener_calledTimes = 0
    var playDirection_calledTimes = 0
    
    func isPlayerDefined() -> Bool { false }
    func isPlayerEmpty() -> Bool { false }
    
    func currentPlayer() -> AudioPlayer? {
        AudioPlayer()
    }
    
    func setCurrent(player: AudioPlayer?, autoPlayEnabled: Bool) {
        addPlayer_calledTimes += 1
    }
    
    func addPlayer(listener: AudioPlayerObserversProtocol) {
        addPlayerListener_calledTimes += 1
    }
    
    func removePlayer(listener: AudioPlayerObserversProtocol) {
        removePlayerListener_calledTimes += 1
    }
    
    func addPlayer(tracks: [AudioPlayerItem]) {
        addPlayerTracks_calledTimes += 1
    }
    
    func move(item: AudioPlayerItem, to position: IndexPath, direction: MovementDirection) {
        onMoveItem_calledTimes += 1
    }
    
    func delete(items: [AudioPlayerItem]) {
        onDeleteItems_calledTimes += 1
    }
    
    func playerProgressCompleted(percentage: Float) {
        updateProgressCompleted_calledTimes += 1
    }
    
    func playerShuffle(active: Bool) {
        onShuffle_calledTimes += 1
    }
   
    func playPrevious() {
        playPrevious_calledTimes += 1
    }
    
    func playerTogglePlay() {
        togglePlay_calledTimes += 1
    }
    
    func playerPause() {
        pause_calledTimes += 1
    }
    
    func playerPlay() {
        play_calledTimes += 1
    }
    
    func playNext() {
        playNext_calledTimes += 1
    }
    
    func play(direction: MovementDirection) {
        playDirection_calledTimes += 1
    }
    
    func playerRepeatAll(active: Bool) {
        onRepeatAll_calledTimes += 1
    }
    
    func playerRepeatOne(active: Bool) {
        onRepeatOne_calledTimes += 1
    }
    
    func playerRepeatDisabled() {
        onRepeatDisabled_calledTimes += 1
    }
    
    func playerCurrentItem() -> AudioPlayerItem? { AudioPlayerItem.mockItem }
    func playerCurrentItemTime() -> TimeInterval { 0.0 }
    func playerQueueItems() -> [AudioPlayerItem]? { nil }
    func playerPlaylistItems() -> [AudioPlayerItem]? { nil}
    func initMiniPlayer(node: MEGANode?, fileLink: String?, filePaths: [String]?, isFolderLink: Bool, presenter: UIViewController, shouldReloadPlayerInfo: Bool, shouldResetPlayer: Bool) {}
    func initFullScreenPlayer(node: MEGANode?, fileLink: String?, filePaths: [String]?, isFolderLink: Bool, presenter: UIViewController) {}
    func playerHidden(_ hidden: Bool, presenter: UIViewController) {}
    func closePlayer() {}
    func isPlayerPlaying() -> Bool { true }
    func isPlayerPaused() -> Bool { false }
    func isPlayerAlive() -> Bool { true }
    func addDelegate(_ delegate: AudioPlayerPresenterProtocol) {}
    func removeDelegate(_ delegate: AudioPlayerPresenterProtocol) {}
    func addMiniPlayerHandler(_ handler: AudioMiniPlayerHandlerProtocol) {}
    func removeMiniPlayerHandler(_ handler: AudioMiniPlayerHandlerProtocol) {}
    func isShuffleEnabled() -> Bool { false }
    func currentRepeatMode() -> RepeatMode { RepeatMode.none }
    func refreshCurrentItemState() {}
    func autoPlay(enable: Bool) {}
}

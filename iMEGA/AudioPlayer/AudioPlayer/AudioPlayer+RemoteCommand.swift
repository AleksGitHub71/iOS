import AVFoundation
import MediaPlayer

extension AudioPlayer {
    func registerRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget(self, action: #selector(audioPlayer(didReceivePlayCommand:)))
        commandCenter.pauseCommand.addTarget(self, action: #selector(audioPlayer(didReceivePauseCommand:)))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(audioPlayer(didReceiveNextTrackCommand:)))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(audioPlayer(didReceivePreviousTrackCommand:)))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(audioPlayer(didReceiveTogglePlayPauseCommand:)))
        commandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(audioPlayer(didReceiveChangePlaybackPositionCommand:)))
    }
    
    func unregisterRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(self)
        commandCenter.pauseCommand.removeTarget(self)
        commandCenter.nextTrackCommand.removeTarget(self)
        commandCenter.previousTrackCommand.removeTarget(self)
        commandCenter.togglePlayPauseCommand.removeTarget(self)
        commandCenter.seekForwardCommand.removeTarget(self)
        commandCenter.seekBackwardCommand.removeTarget(self)
    }
    
    func refreshNowPlayingInfo() {
        guard let item = currentItem() else { return }
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = item.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = item.artist
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = item.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = item.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = queuePlayer?.rate
        if let artwork = item.artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { size in
                artwork
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

extension AudioPlayer: AudioPlayerRemoteCommandProtocol {
    @objc func audioPlayer(didReceivePlayCommand event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let player = queuePlayer else { return .commandFailed }
        if player.rate == 0.0 {
            play()
            return .success
        }

        return .commandFailed
    }
    
    @objc func audioPlayer(didReceivePauseCommand event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let player = queuePlayer else { return .commandFailed }
        
        if player.rate == 1.0 {
            pause()
            return .success
        }

        return.commandFailed
    }
    
    @objc func audioPlayer(didReceiveNextTrackCommand event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard queuePlayer != nil else { return .commandFailed }
        
        if isRepeatOneMode() {
            repeatAll(true)
            notify(aboutAudioPlayerConfiguration)
        }
        
        updateCommandsState(enabled: false)
        playNext() { [weak self] in
            guard let `self` = self else { return }
            self.updateCommandsState(enabled: true)
        }

        return.success
    }
    
    @objc func audioPlayer(didReceivePreviousTrackCommand event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard queuePlayer != nil else { return .commandFailed }
        
        updateCommandsState(enabled: false)
        playPrevious() { [weak self] in
            guard let `self` = self else { return }
            self.updateCommandsState(enabled: true)
        }

        return.success
    }
    
    @objc func audioPlayer(didReceiveTogglePlayPauseCommand event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let player = queuePlayer else { return .commandFailed }
        
        if isPlaying {
            if player.rate == 1.0 {
                pause()
                return .success
            }
        } else {
            if player.rate == 0.0 {
                play()
                return .success
            }
        }

        return.commandFailed
    }
    
    @objc func audioPlayer(didReceiveChangePlaybackPositionCommand event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        setProgressCompleted(event.positionTime)
        return .success
    }
    
    private func updateCommandsState(enabled: Bool) {
        MPRemoteCommandCenter.shared().playCommand.isEnabled = enabled
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = enabled
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = enabled
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = enabled
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = enabled
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = enabled
    }
}

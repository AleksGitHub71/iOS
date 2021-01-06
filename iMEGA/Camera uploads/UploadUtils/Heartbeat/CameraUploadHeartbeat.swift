import Foundation
import FirebaseCrashlytics

final class CameraUploadHeartbeat: NSObject {
    private enum Constants {
        static let activeTimerInterval: Double = 30
        static let statusTimerInterval: Double = 30 * 60
    }
    
    private let sdk: MEGASdk
    private let register: BackupRegister
    private let recorder: BackupRecorder
    private var activeTimer: DispatchSourceTimer?
    private var statusTimer: DispatchSourceTimer?
    private var lastHeartbeatNodeHandle: MEGAHandle?
    
    @objc override init() {
        sdk = MEGASdkManager.sharedMEGASdk()
        register = BackupRegister(sdk: sdk)
        recorder = BackupRecorder()
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveNodeCurrentNotification), name: Notification.Name.MEGANodesCurrent, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveCameraUploadsCompleteNotification), name: Notification.Name.MEGACameraUploadComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveIsBeingLogoutNotification), name: Notification.Name.MEGAIsBeingLogout, object: nil)
    }
    
    // MARK: - Notification
    @objc private func didReceiveNodeCurrentNotification() {
        if CameraUploadManager.isCameraUploadEnabled {
            registerHeartbeat()
        }
    }
    
    @objc private func didReceiveCameraUploadsCompleteNotification() {
        MEGALogDebug("[Camera Upload] heartbeat - received camera uploads complete notification")
        sendHeartbeat()
    }
    
    @objc private func didReceiveIsBeingLogoutNotification() {
        MEGALogDebug("[Camera Upload] heartbeat - received account is being logout notification")
        unregisterHeartbeat()
    }
    
    // MARK: - Registration
    @objc func registerHeartbeat() {
        recorder.startRecordingBackupUpdate()
        register.registerBackupIfNeeded()
        setupHeartbeatTimers()
    }
    
    @objc func unregisterHeartbeat() {
        cancelHeartbeatTimers()
        register.unregisterBackup()
        recorder.stopRecordingBackupUpdate()
    }

    // MARK: - Manage Timers
    private func setupHeartbeatTimers() {
        setupActiveTimerIfNeeded()
        setupStatusTimerIfNeeded()
    }
    
    private func cancelHeartbeatTimers() {
        activeTimer?.cancel()
        activeTimer = nil
        
        statusTimer?.cancel()
        statusTimer = nil
    }
    
    // MARK: - Active Timer
    private func setupActiveTimerIfNeeded() {
        guard activeTimer == nil else {
            return
        }
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        // we use absolute time here to achieve accuracy
        timer.schedule(deadline: .now() + Constants.activeTimerInterval, repeating: Constants.activeTimerInterval, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.activeTimerDidFire()
        }
        timer.activate()
        activeTimer = timer
    }
    
    private func activeTimerDidFire() {
        guard let backupId = register.cachedBackupId else {
            MEGALogDebug("[Camera Upload] heartbeat - active timer skipped as no local cached backup id")
            return
        }
        
        MEGALogDebug("[Camera Upload] heartbeat - active timer fired for backupId \(type(of: sdk).base64Handle(forHandle: backupId) ?? "")")
        
        guard let lastRecord = recorder.fetchLastBackupRecord(),
              let lastNode = sdk.node(forHandle: lastRecord.nodeHandle) else {
            MEGALogDebug("[Camera Upload] heartbeat - could not find last backup node")
            return
        }

        guard lastNode.handle != lastHeartbeatNodeHandle else {
            MEGALogDebug("[Camera Upload] heartbeat - last backup node \(lastNode.handle) is same as the previous heartbeat")
            return
        }
        
        sendHeartbeat(forBackupId: backupId, lastNode: lastNode, lastActionDate: lastRecord.date)
    }
    
    // MAKR: - Status Timer
    private func setupStatusTimerIfNeeded() {
        guard statusTimer == nil else {
            return
        }
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        // we use wall time here as statue update gap is quite big
        timer.schedule(wallDeadline: .now() + 2, repeating: Constants.statusTimerInterval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.statusTimerDidFire()
        }
        timer.activate()
        statusTimer = timer
    }
    
    private func statusTimerDidFire() {
        MEGALogDebug("[Camera Upload] heartbeat - status timer fired")
        
        sendHeartbeat()
    }
    
    // MARK: - Send heartbeat
    private func sendHeartbeat() {
        guard let backupId = register.cachedBackupId else {
            MEGALogDebug("[Camera Upload] heartbeat - skipped as no local cached backup id")
            return
        }
        
        guard let lastRecord = recorder.fetchLastBackupRecord(),
              let lastNode = sdk.node(forHandle: lastRecord.nodeHandle) else {
            MEGALogDebug("[Camera Upload] heartbeat - skipped as last backup node could not be found")
            return
        }
        
        sendHeartbeat(forBackupId: backupId, lastNode: lastNode, lastActionDate: lastRecord.date)
    }
    
    private func sendHeartbeat(forBackupId backupId: MEGAHandle, lastNode: MEGANode, lastActionDate: Date) {
        MEGALogDebug("[Camera Upload] heartbeat - start sending heartbeat for backupId \(type(of: sdk).base64Handle(forHandle: backupId) ?? "")")
        CameraUploadManager.shared().loadCurrentUploadStats { [sdk] stats, error in
            guard let stats = stats else {
                if let error = error {
                    Crashlytics.crashlytics().record(error: error)
                    MEGALogError("[Camera Upload] heartbeat - error when to load CU stats \(type(of: sdk).base64Handle(forHandle: backupId) ?? "") \(error)")
                }
                
                return
            }
            
            let status: BackupHeartbeatStatus = stats.finishedFilesCount == stats.totalFilesCount ? .upToDate : .syncing
            let progress: Int
            if status == .upToDate {
                progress = 100
            } else if stats.totalFilesCount == 0 {
                progress = 0
            } else {
                progress = Int(stats.progress * 100)
            }
            
            self.sdk.sendBackupHeartbeat(backupId,
                                         status: status,
                                         progress: progress,
                                         pendingUploadCount: stats.pendingFilesCount,
                                         lastActionDate: lastActionDate,
                                         lastBackupNode: lastNode,
                                         delegate: HeartbeatRequestDelegate { [weak self, sdk = self.sdk] result in
                                            switch result {
                                            case .failure(let error):
                                                Crashlytics.crashlytics().record(error: error)
                                                MEGALogError("[Camera Upload] heartbeat - error when to send heartbeat \(type(of: sdk).base64Handle(forHandle: backupId) ?? "") \(error)")
                                            case .success:
                                                self?.lastHeartbeatNodeHandle = lastNode.handle
                                                MEGALogDebug("[Camera Upload] heartbeat - send heartbeat to backup \(type(of: sdk).base64Handle(forHandle: backupId) ?? "") success")
                                            }
                                         })
        }
    }
}


#import "CameraUploadConcurrentCountCalculator.h"
#import "MEGAConstants.h"

@interface CameraUploadConcurrentCountCalculator ()

@property (nonatomic) CameraUploadConcurrentCounts currentConcurrentCounts;

@end

@implementation CameraUploadConcurrentCountCalculator

#pragma mark - notifications to monitor

- (void)startCalculatingConcurrentCount {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStatesChangedNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStatesChangedNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStatesChangedNotification:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStatesChangedNotification:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStatesChangedNotification:) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    
    if (@available(iOS 11.0, *)) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationStatesChangedNotification:) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
    }
}

- (void)stopCalculatingConcurrentCount {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)applicationStatesChangedNotification:(NSNotification *)notification {
    MEGALogDebug(@"[Camera Upload] concurrent calculator received %@", notification.name);
    CameraUploadConcurrentCounts concurrentCounts = [self calculateCameraUploadConcurrentCounts];
    if (concurrentCounts.photoConcurrentCount != self.currentConcurrentCounts.photoConcurrentCount) {
        [NSNotificationCenter.defaultCenter postNotificationName:MEGACameraUploadPhotoConcurrentCountChangedNotification object:self userInfo:@{MEGAPhotoConcurrentCountUserInfoKey : @(concurrentCounts.photoConcurrentCount)}];
    }
    
    if (concurrentCounts.videoConcurrentCount != self.currentConcurrentCounts.videoConcurrentCount) {
        [NSNotificationCenter.defaultCenter postNotificationName:MEGACameraUploadVideoConcurrentCountChangedNotification object:self userInfo:@{MEGAVideoConcurrentCountUserInfoKey : @(concurrentCounts.videoConcurrentCount)}];
    }
    
    self.currentConcurrentCounts = concurrentCounts;
}

#pragma mark - concurrent count calculation

- (PhotoUploadConcurrentCount)calculatePhotoUploadConcurrentCount {
    self.currentConcurrentCounts = [self calculateCameraUploadConcurrentCounts];
    return self.currentConcurrentCounts.photoConcurrentCount;
}

- (VideoUploadConcurrentCount)calculateVideoUploadConcurrentCount {
    self.currentConcurrentCounts = [self calculateCameraUploadConcurrentCounts];
    return self.currentConcurrentCounts.videoConcurrentCount;
}

- (CameraUploadConcurrentCounts)calculateCameraUploadConcurrentCounts {
    if (NSThread.isMainThread) {
        return [self calculateCameraUploadConcurrentCountsInMainThread];
    } else {
        __block CameraUploadConcurrentCounts counts;
        dispatch_sync(dispatch_get_main_queue(), ^{
            counts = [self calculateCameraUploadConcurrentCountsInMainThread];
        });
        return counts;
    }
}

- (CameraUploadConcurrentCounts)calculateCameraUploadConcurrentCountsInMainThread {
    if (@available(iOS 11.0, *)) {
        return [self calculateCameraUploadConcurrentCountsByThermalState:NSProcessInfo.processInfo.thermalState
                                                        applicationState:UIApplication.sharedApplication.applicationState
                                                            batteryState:UIDevice.currentDevice.batteryState
                                                            batteryLevel:UIDevice.currentDevice.batteryLevel
                                                   isLowPowerModeEnabled:NSProcessInfo.processInfo.isLowPowerModeEnabled];
    } else {
        return [self calculateCameraUploadConcurrentCountsByApplicationState:UIApplication.sharedApplication.applicationState
                                                                batteryState:UIDevice.currentDevice.batteryState
                                                                batteryLevel:UIDevice.currentDevice.batteryLevel
                                                       isLowPowerModeEnabled:NSProcessInfo.processInfo.isLowPowerModeEnabled];
    }
}

- (CameraUploadConcurrentCounts)calculateCameraUploadConcurrentCountsByThermalState:(NSProcessInfoThermalState)thermalState applicationState:(UIApplicationState)applicationState batteryState:(UIDeviceBatteryState)batteryState batteryLevel:(float)batteryLevel isLowPowerModeEnabled:(BOOL)isLowPowerModeEnabled API_AVAILABLE(ios(11.0)) {
    CameraUploadConcurrentCounts concurrentCounts = [self calculateCameraUploadConcurrentCountsByApplicationState:applicationState batteryState:batteryState batteryLevel:batteryLevel isLowPowerModeEnabled:isLowPowerModeEnabled];
    CameraUploadConcurrentCounts countsByThermal = [self concurrentCountsByThermalState:thermalState];
    return MakeCounts(MIN(concurrentCounts.photoConcurrentCount, countsByThermal.photoConcurrentCount), MIN(concurrentCounts.videoConcurrentCount, countsByThermal.videoConcurrentCount));
}

- (CameraUploadConcurrentCounts)calculateCameraUploadConcurrentCountsByApplicationState:(UIApplicationState)applicationState batteryState:(UIDeviceBatteryState)batteryState batteryLevel:(float)batteryLevel isLowPowerModeEnabled:(BOOL)isLowPowerModeEnabled {
    CameraUploadConcurrentCounts countsByAppState = [self concurrentCountsByApplicationState:applicationState];
    CameraUploadConcurrentCounts countsByPower = [self concurrentCountsByBatteryState:batteryState batteryLevel:batteryLevel isLowPowerModeEnabled:isLowPowerModeEnabled];
    return MakeCounts(MIN(countsByAppState.photoConcurrentCount, countsByPower.photoConcurrentCount), MIN(countsByAppState.videoConcurrentCount, countsByPower.videoConcurrentCount));
}

- (CameraUploadConcurrentCounts)concurrentCountsByApplicationState:(UIApplicationState)applicationState {
    if (applicationState == UIApplicationStateBackground) {
        return MakeCounts(PhotoUploadConcurrentCountInBackground, VideoUploadConcurrentCountInBackground);
    } else {
        return MakeCounts(PhotoUploadConcurrentCountDefaultMaximum, VideoUploadConcurrentCountDefaultMaximum);
    }
}

- (CameraUploadConcurrentCounts)concurrentCountsByBatteryState:(UIDeviceBatteryState)batteryState batteryLevel:(float)batteryLevel isLowPowerModeEnabled:(BOOL)isLowPowerModeEnabled {
    if (batteryState == UIDeviceBatteryStateUnplugged) {
        if (batteryLevel < 0.15) {
            return MakeCounts(PhotoUploadConcurrentCountInBatteryLevelBelow15, VideoUploadConcurrentCountInBatteryLevelBelow15);
        } else if (batteryLevel < 0.25) {
            return MakeCounts(PhotoUploadConcurrentCountInBatteryLevelBelow25, VideoUploadConcurrentCountInBatteryLevelBelow25);
        } else if (isLowPowerModeEnabled) {
            return MakeCounts(PhotoUploadConcurrentCountInLowPowerMode, VideoUploadConcurrentCountInLowPowerMode);
        } else if (batteryLevel < 0.4) {
            return MakeCounts(PhotoUploadConcurrentCountInBatteryLevelBelow40, VideoUploadConcurrentCountInBatteryLevelBelow40);
        } else if (batteryLevel < 0.55) {
            return MakeCounts(PhotoUploadConcurrentCountInBatteryLevelBelow55, VideoUploadConcurrentCountInBatteryLevelBelow55);
        } else if (batteryLevel < 0.75) {
            return MakeCounts(PhotoUploadConcurrentCountInBatteryLevelBelow75, VideoUploadConcurrentCountInBatteryLevelBelow75);
        } else {
            return MakeCounts(PhotoUploadConcurrentCountInForeground, VideoUploadConcurrentCountInForeground);
        }
    } else {
        return MakeCounts(PhotoUploadConcurrentCountInBatteryCharging, VideoUploadConcurrentCountInBatteryCharging);
    }
}

- (CameraUploadConcurrentCounts)concurrentCountsByThermalState:(NSProcessInfoThermalState)thermalState API_AVAILABLE(ios(11.0)) {
    switch (thermalState) {
        case NSProcessInfoThermalStateCritical:
            return MakeCounts(PhotoUploadConcurrentCountInThermalStateCritical, VideoUploadConcurrentCountInThermalStateCritical);
            break;
        case NSProcessInfoThermalStateSerious:
            return MakeCounts(PhotoUploadConcurrentCountInThermalStateSerious, VideoUploadConcurrentCountInThermalStateSerious);
            break;
        case NSProcessInfoThermalStateFair:
            return MakeCounts(PhotoUploadConcurrentCountInThermalStateFair, VideoUploadConcurrentCountInThermalStateFair);
            break;
        case NSProcessInfoThermalStateNominal:
            return MakeCounts(PhotoUploadConcurrentCountDefaultMaximum, VideoUploadConcurrentCountDefaultMaximum);
            break;
    }
}

@end

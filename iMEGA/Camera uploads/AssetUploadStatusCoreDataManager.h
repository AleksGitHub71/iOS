//
//  AssetUploadStatusCoreDataManager.h
//  MEGA
//
//  Created by Simon Wang on 8/10/18.
//  Copyright © 2018 MEGA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOAssetUploadStatus+CoreDataClass.h"
@import Photos;

extern NSString * const uploadStatusNotStarted;
extern NSString * const uploadStatusDownloading;
extern NSString * const uploadStatusProcessing;
extern NSString * const uploadStatusUploading;
extern NSString * const uploadStatusFailed;
extern NSString * const uploadStatusDone;

NS_ASSUME_NONNULL_BEGIN

@interface AssetUploadStatusCoreDataManager : NSObject

- (NSArray<MOAssetUploadStatus *> *)fetchAllAssetsUploadStatus:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)saveAssetFetchResult:(PHFetchResult<PHAsset *> *)result error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)saveAssets:(NSArray<PHAsset *> *)assets error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

//
//  WhiteUtils.h
//  WhiteSDKPrivate_Example
//
//  Created by yleaf on 2019/3/4.
//  Copyright © 2019 leavesster. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WhiteUtils : NSObject

+ (NSString *)sdkToken;
+ (void)createRoomWithResult:(void (^) (BOOL success, id _Nullable response, NSError * _Nullable error))result;
+ (void)getRoomTokenWithUuid:(NSString *)uuid Result:(void (^) (BOOL success, id _Nullable response, NSError * _Nullable error))result;
+ (void)deleteRoomTokenWithUuid:(NSString *)uuid;
+ (void)getWhiteBoardPagePreviewImage:(NSString *)uuid withRoomToken:(NSString *)token result:(void (^) (BOOL success, id response, NSError *error))result;

@end

NS_ASSUME_NONNULL_END
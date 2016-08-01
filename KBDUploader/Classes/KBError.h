//
//  KBError.h
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 错误码
typedef enum : NSUInteger {
    KBErrorCodeCrash		= -10000,
    KBErrorCodeDisConnect,
    KBErrorCodeUnknow,
} KBErrorCode;

@interface KBError : NSObject

+ (NSError *)errorCode:(KBErrorCode)code userInfo:(NSDictionary *)dic;
+ (NSString *)transformCodeToStringInfo:(KBErrorCode)code;

@end

//
//  KBError.m
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import "KBError.h"

static NSDictionary *errorDictionary = nil;

@implementation KBError


+ (void)initialize
{
    if (self == [KBError class])
    {
        errorDictionary = \
        @{
          /* code        :        errorWithDomain */
          /* ==================================== */
          
          @(KBErrorCodeCrash)       :        @"Crash",
          @(KBErrorCodeDisConnect)  :        @"网络连接失败",
          @(KBErrorCodeUnknow)      :        @"未知错误",
          
          /* ==================================== */
          };
    }
}

+ (NSError *)errorCode:(KBErrorCode)code userInfo:(NSDictionary *)dic
{
    return [NSError errorWithDomain:errorDictionary[@(code)]
                               code:code
                           userInfo:dic];
}

+ (NSString *)transformCodeToStringInfo:(KBErrorCode)code
{
    return errorDictionary[@(code)];
}


@end

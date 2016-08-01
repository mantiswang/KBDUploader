//
//  KBUploaderHelper.m
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import "KBUploaderHelper.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <CommonCrypto/CommonCrypto.h>


#define kBoundary      @"----WebKitFormBoundaryVnD2S3sOElp1cDdI"
#define kNewLine [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]
#define kContentTypeImage   @"image/jpeg"
#define kContentTypeVideo   @"video/*"
#define kContentTypeAudio   @"audio/*"


@implementation KBUploaderHelper

+ (NSData *)constructRequestBody:(NSData*)data contentType:(KBUploaderContentType)type {
    
    NSMutableData *formData = [NSMutableData data];
    [formData appendData:[[NSString stringWithFormat:@"--%@",kBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [formData appendData:kNewLine];
    
    NSString *fileExt = nil;
    NSString *contentType = nil;
    
    if (type == KBUploaderContentTypeVideo) {
        fileExt = @"mp4";
        contentType = [NSString stringWithFormat:@"Content-Type: %@", kContentTypeVideo];
    }
    else if (type == KBUploaderContentTypeAudio) {
        fileExt = @"amr";
        contentType = [NSString stringWithFormat:@"Content-Type: %@", kContentTypeAudio];
        
    }
    else {
        fileExt = @"jpg";
        contentType = [NSString stringWithFormat:@"Content-Type: %@", kContentTypeImage];
    }
    
    NSString *randomFileName = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
    
    NSString *name = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@.%@\"",randomFileName,randomFileName,fileExt];
    
    [formData appendData:[name dataUsingEncoding:NSUTF8StringEncoding]];
    [formData appendData:kNewLine];
    [formData appendData: [contentType dataUsingEncoding:NSUTF8StringEncoding]];
    [formData appendData:kNewLine];
    [formData appendData:kNewLine];
    
    [formData appendData:data];
    [formData appendData:kNewLine];
    
    [formData appendData:[[NSString stringWithFormat:@"--%@--",kBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return formData;
}

+ (NSString *)userAgent {
    return [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
}

+ (NSString *)contentType {
    
    return [NSString stringWithFormat:@"multipart/form-data; boundary=%@",kBoundary];
    
}

+ (NSString *)md5String:(NSString *)text{
    
    return [KBUploaderHelper data2md5String:[text dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSString *)data2md5String:(NSData*)imageData {
    if ([imageData length]==0) {
        return nil;
    }
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(imageData.bytes, (CC_LONG)imageData.length, result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}
@end

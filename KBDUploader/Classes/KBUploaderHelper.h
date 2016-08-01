//
//  KBUploaderHelper.h
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    KBUploaderContentTypeImage,
    KBUploaderContentTypeAudio,
    KBUploaderContentTypeVideo,
} KBUploaderContentType;

@interface KBUploaderHelper : NSObject

/**  构建请求体 */
+ (NSData *)constructRequestBody:(NSData*)data contentType:(KBUploaderContentType)type;
/** 请求UserAgent */
+ (NSString *)userAgent;
/** 请求ContentType */
+ (NSString *)contentType;
/** 上传data数据 md5 String */
+ (NSString *)data2md5String:(NSData*)data;

+ (NSString *)md5String:(NSString *)text;
@end
